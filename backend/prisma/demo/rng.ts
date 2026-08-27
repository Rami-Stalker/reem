/**
 * Deterministic pseudo-random source for the demo dataset.
 *
 * The showcase data has to be reproducible: the same `npm run db:seed` must
 * produce the same catalog, the same prices and the same order history on
 * every machine, otherwise screenshots, QA scripts and contract fixtures drift
 * between runs. `Math.random()` cannot give that, so every random choice in
 * `prisma/demo/**` goes through this seeded generator (mulberry32).
 */
export class Rng {
  private state: number;

  constructor(seed: string | number) {
    this.state =
      typeof seed === 'number' ? seed >>> 0 : Rng.hash(seed);
  }

  /** FNV-1a — turns a label into a stable 32-bit seed. */
  private static hash(value: string): number {
    let hash = 0x811c9dc5;
    for (let i = 0; i < value.length; i += 1) {
      hash ^= value.charCodeAt(i);
      hash = Math.imul(hash, 0x01000193);
    }
    return hash >>> 0;
  }

  /** Uniform float in [0, 1). */
  next(): number {
    this.state = (this.state + 0x6d2b79f5) >>> 0;
    let t = this.state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  /** Uniform integer in [min, max], both inclusive. */
  int(min: number, max: number): number {
    return min + Math.floor(this.next() * (max - min + 1));
  }

  /** Float in [min, max), rounded to `decimals`. */
  float(min: number, max: number, decimals = 2): number {
    const value = min + this.next() * (max - min);
    const factor = 10 ** decimals;
    return Math.round(value * factor) / factor;
  }

  bool(probability = 0.5): boolean {
    return this.next() < probability;
  }

  pick<T>(items: readonly T[]): T {
    if (items.length === 0) throw new Error('Rng.pick: empty collection');
    return items[this.int(0, items.length - 1)];
  }

  /** Fisher–Yates on a copy — the input is never mutated. */
  shuffle<T>(items: readonly T[]): T[] {
    const copy = [...items];
    for (let i = copy.length - 1; i > 0; i -= 1) {
      const j = this.int(0, i);
      [copy[i], copy[j]] = [copy[j], copy[i]];
    }
    return copy;
  }

  /** `count` distinct items (or all of them, when the pool is smaller). */
  sample<T>(items: readonly T[], count: number): T[] {
    return this.shuffle(items).slice(0, Math.min(count, items.length));
  }

  /** Picks by relative weight: `[['a', 3], ['b', 1]]` yields 'a' 75% of the time. */
  weighted<T>(entries: readonly (readonly [T, number])[]): T {
    const total = entries.reduce((sum, [, weight]) => sum + weight, 0);
    let threshold = this.next() * total;
    for (const [value, weight] of entries) {
      threshold -= weight;
      if (threshold <= 0) return value;
    }
    return entries[entries.length - 1][0];
  }

  /** A moment between `maxDaysAgo` and `minDaysAgo` before now. */
  pastDate(maxDaysAgo: number, minDaysAgo = 0): Date {
    const span = (maxDaysAgo - minDaysAgo) * 86_400_000;
    const offset = minDaysAgo * 86_400_000 + this.next() * span;
    return new Date(Date.now() - offset);
  }

  /** A moment between now and `maxDaysAhead`. */
  futureDate(maxDaysAhead: number, minDaysAhead = 0): Date {
    const span = (maxDaysAhead - minDaysAhead) * 86_400_000;
    return new Date(
      Date.now() + minDaysAhead * 86_400_000 + this.next() * span,
    );
  }
}

/** Adds `days` to a date without mutating it. */
export function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * 86_400_000);
}

/** Q48 P1 — SYP is charged and displayed rounded to the nearest 1000. */
export function roundSyp(amount: number): number {
  return Math.round(amount / 1000) * 1000;
}
