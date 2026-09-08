import { createHash } from 'node:crypto';

/** One arm of an experiment, and how much of the traffic it gets. */
export interface Variant {
  key: string;
  weight: number;
}

/**
 * The arm every experiment must have, and the answer when there is no
 * experiment at all.
 *
 * Naming it here rather than leaving each caller to decide means a stopped
 * experiment, a missing one and a misconfigured one all behave the same way:
 * the customer sees what she would have seen anyway.
 */
export const CONTROL = 'control';

/**
 * Which arm a subject falls in.
 *
 * Computed, never stored, and that is the whole design. A hash of the
 * experiment key and the subject gives the same answer on her phone, on her
 * sister's laptop and in a report written next month — without a lookup on the
 * read path, and without a row per visitor.
 *
 * The experiment key is part of the hash so that two experiments running at
 * once do not split the audience the same way. Without it, whoever landed in
 * the treatment arm of the first test would land in the treatment arm of every
 * test, and the two results would be indistinguishable from each other.
 *
 * Renaming an experiment therefore re-randomises everybody. That is not a
 * limitation to work around; it is what starting a new test means, and the
 * alternative — a stable id divorced from the key — quietly lets somebody
 * change what is being tested halfway through and keep the old numbers.
 */
export function assign(
  experimentKey: string,
  subjectKey: string,
  variants: readonly Variant[],
): string {
  const usable = variants.filter(
    (variant) => variant.key.length > 0 && variant.weight > 0,
  );
  if (usable.length === 0) return CONTROL;
  if (usable.length === 1) return usable[0].key;

  const total = usable.reduce((sum, variant) => sum + variant.weight, 0);
  if (total <= 0) return CONTROL;

  // A uniform position in [0, 1) from the first four bytes of the digest.
  // sha256 rather than a cheap hash: the assignment has to be uncorrelated
  // between experiments, and a weak hash correlates them by construction.
  const digest = createHash('sha256')
    .update(`${experimentKey}:${subjectKey}`)
    .digest();
  const position = digest.readUInt32BE(0) / 0x1_0000_0000;

  let cursor = 0;
  for (const variant of usable) {
    cursor += variant.weight / total;
    if (position < cursor) return variant.key;
  }
  // Only reachable through floating-point rounding at the very top of the
  // range. The last arm is the honest answer, not an error.
  return usable[usable.length - 1].key;
}

/** Rejects a variant list that cannot describe a valid split. */
export function parseVariants(value: unknown): Variant[] | null {
  if (!Array.isArray(value)) return null;

  const variants: Variant[] = [];
  const seen = new Set<string>();

  for (const entry of value) {
    if (typeof entry !== 'object' || entry === null) return null;
    const key = (entry as { key?: unknown }).key;
    const weight = (entry as { weight?: unknown }).weight;
    if (typeof key !== 'string' || key.trim().length === 0) return null;
    if (typeof weight !== 'number' || !Number.isFinite(weight) || weight < 0) {
      return null;
    }
    if (seen.has(key)) return null;
    seen.add(key);
    variants.push({ key, weight });
  }

  if (variants.length < 2) return null;
  if (!seen.has(CONTROL)) return null;
  if (variants.reduce((sum, variant) => sum + variant.weight, 0) <= 0) {
    return null;
  }

  return variants;
}
