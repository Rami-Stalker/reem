import { BadRequestException } from '@nestjs/common';
import { Currency, RoundingPolicy } from '@prisma/client';
import { Prisma } from '@prisma/client';

const Decimal = Prisma.Decimal;
type Decimal = Prisma.Decimal;

/**
 * A currency-tagged amount.
 *
 * Every monetary column in the schema is `Decimal` + `Currency`, and every
 * arithmetic path in the backend must go through this type. The reason is not
 * style: Prisma returns Decimal.js objects whose `valueOf()` yields a *string*,
 * so plain `decimalA + decimalB` silently produces `"100200"` instead of `300`
 * — no throw, no type error, just wrong money. Money makes that impossible by
 * refusing to expose a `number` for arithmetic and by rejecting operations
 * between different currencies.
 */
export class Money {
  private constructor(
    readonly amount: Decimal,
    readonly currency: Currency,
  ) {}

  // ── Construction ──────────────────────────────────────────────────────

  static of(
    value: Decimal | string | number | null | undefined,
    currency: Currency,
  ): Money {
    if (value === null || value === undefined) {
      return new Money(new Decimal(0), currency);
    }
    let amount: Decimal;
    try {
      amount = new Decimal(value as Prisma.Decimal.Value);
    } catch {
      throw new BadRequestException(`Not a valid amount: ${String(value)}`);
    }
    // NaN and Infinity are valid Decimals and invalid money. Either one would
    // pass every comparison it met (NaN is neither less nor greater than
    // anything) and then poison whatever total it was added to.
    if (!amount.isFinite()) {
      throw new BadRequestException(`Not a finite amount: ${String(value)}`);
    }
    return new Money(amount, currency);
  }

  static zero(currency: Currency): Money {
    return new Money(new Decimal(0), currency);
  }

  /**
   * Sums a list that may be empty. An empty list has no intrinsic currency,
   * so one must be supplied.
   */
  static sum(values: readonly Money[], currency: Currency): Money {
    return values.reduce((total, value) => total.plus(value), Money.zero(currency));
  }

  // ── Arithmetic (currency-checked) ─────────────────────────────────────

  plus(other: Money): Money {
    this.assertSameCurrency(other);
    return new Money(this.amount.plus(other.amount), this.currency);
  }

  minus(other: Money): Money {
    this.assertSameCurrency(other);
    return new Money(this.amount.minus(other.amount), this.currency);
  }

  /** Scaling by a dimensionless quantity (a count, a rate, a percentage). */
  times(factor: Decimal | string | number): Money {
    const f = new Decimal(factor as Prisma.Decimal.Value);
    if (!f.isFinite()) {
      throw new BadRequestException('A money factor must be a finite number');
    }
    return new Money(this.amount.times(f), this.currency);
  }

  dividedBy(divisor: Decimal | string | number): Money {
    const d = new Decimal(divisor as Prisma.Decimal.Value);
    if (d.isZero()) {
      throw new BadRequestException('Division by zero in a money calculation');
    }
    return new Money(this.amount.dividedBy(d), this.currency);
  }

  /** Basis points — the unit commission rules are stored in. */
  percentBps(bps: number): Money {
    return this.times(new Decimal(bps).dividedBy(10_000));
  }

  negated(): Money {
    return new Money(this.amount.negated(), this.currency);
  }

  clampMin(floor: Money): Money {
    this.assertSameCurrency(floor);
    return this.amount.lessThan(floor.amount) ? floor : this;
  }

  clampMax(ceiling: Money): Money {
    this.assertSameCurrency(ceiling);
    return this.amount.greaterThan(ceiling.amount) ? ceiling : this;
  }

  // ── Comparison ────────────────────────────────────────────────────────

  isZero(): boolean {
    return this.amount.isZero();
  }

  isNegative(): boolean {
    return this.amount.isNegative() && !this.amount.isZero();
  }

  greaterThan(other: Money): boolean {
    this.assertSameCurrency(other);
    return this.amount.greaterThan(other.amount);
  }

  greaterThanOrEqual(other: Money): boolean {
    this.assertSameCurrency(other);
    return this.amount.greaterThanOrEqualTo(other.amount);
  }

  lessThan(other: Money): boolean {
    this.assertSameCurrency(other);
    return this.amount.lessThan(other.amount);
  }

  equals(other: Money): boolean {
    return (
      this.currency === other.currency && this.amount.equals(other.amount)
    );
  }

  // ── Rounding ──────────────────────────────────────────────────────────

  /**
   * Q48 — SYP is charged in whole thousands. Rounding is a *policy* carried by
   * the order, never an implicit `Math.round(x * 100) / 100` scattered around
   * (the old code had eleven independent copies of that helper).
   */
  round(policy: RoundingPolicy): Money {
    const step = ROUNDING_STEP[policy];
    if (step === null) {
      return new Money(this.amount.toDecimalPlaces(4), this.currency);
    }
    const s = new Decimal(step);
    return new Money(
      this.amount.dividedBy(s).toDecimalPlaces(0, Decimal.ROUND_HALF_UP).times(s),
      this.currency,
    );
  }

  /**
   * Like [round], but never downwards. Used where rounding down would need
   * somewhere to take the difference from and there is nowhere honest to.
   */
  roundUp(policy: RoundingPolicy): Money {
    const step = ROUNDING_STEP[policy];
    if (step === null) {
      return new Money(
        this.amount.toDecimalPlaces(MONEY_SCALE, Decimal.ROUND_CEIL),
        this.currency,
      );
    }
    const s = new Decimal(step);
    return new Money(
      this.amount.dividedBy(s).toDecimalPlaces(0, Decimal.ROUND_CEIL).times(s),
      this.currency,
    );
  }

  /** Rounding appropriate to the currency when no order policy applies. */
  roundForCurrency(): Money {
    return this.round(
      this.currency === Currency.SYP
        ? SYP_ROUNDING
        : RoundingPolicy.NONE,
    );
  }

  /**
   * Rounds to the precision every money column stores (four places).
   *
   * Postgres rounds a value with more places on the way in, and it rounds each
   * column on its own. So two figures computed to agree in memory — a
   * commission and the net beside it, a discount and its per-seller shares —
   * can each round up by half a unit and stop adding up once written. Any
   * figure that comes out of a percentage, a division or a conversion is
   * quantized here before it is stored or posted, so what is saved is exactly
   * what was checked.
   */
  quantize(): Money {
    return new Money(
      this.amount.toDecimalPlaces(MONEY_SCALE, Decimal.ROUND_HALF_UP),
      this.currency,
    );
  }

  /** True when the amount fits the stored precision without rounding. */
  isQuantized(): boolean {
    return this.amount.decimalPlaces() <= MONEY_SCALE;
  }

  // ── Allocation ────────────────────────────────────────────────────────

  /**
   * Splits this amount across N weights without losing or inventing a single
   * unit (largest-remainder method). This is what makes a cart-wide coupon or
   * one shipping charge divisible across per-seller sub-orders: the children
   * always add back up to the parent exactly.
   */
  allocate(weights: readonly (Decimal | number | string)[]): Money[] {
    if (weights.length === 0) return [];

    const decimalWeights = weights.map((w) => new Decimal(w as Prisma.Decimal.Value));
    if (decimalWeights.some((w) => !w.isFinite() || w.isNegative())) {
      // A negative weight would hand one slot more than the whole and another
      // a negative share. No caller means that, so it is refused.
      throw new BadRequestException('Allocation weights must be zero or positive');
    }
    const totalWeight = decimalWeights.reduce(
      (sum, w) => sum.plus(w),
      new Decimal(0),
    );

    if (totalWeight.isZero()) {
      // Degenerate input: hand everything to the first slot rather than
      // dividing by zero, so the invariant "parts sum to whole" still holds.
      return decimalWeights.map((_, index) =>
        index === 0 ? this : Money.zero(this.currency),
      );
    }

    // Worked on the magnitude and signed at the end. Flooring a negative
    // amount towards zero leaves a negative remainder, which the loop below
    // never handed out — a negative amount used to come back short.
    const negative = this.amount.isNegative();
    const magnitude = this.amount.abs();

    const shares = decimalWeights.map((w) =>
      magnitude.times(w).dividedBy(totalWeight),
    );
    const floored = shares.map((s) =>
      s.toDecimalPlaces(MONEY_SCALE, Decimal.ROUND_DOWN),
    );
    let remainder = floored.reduce(
      (rest, part) => rest.minus(part),
      magnitude,
    );

    // Hand the leftover units to the largest fractional parts, one at a time.
    // Ties go to the earlier slot, so the result never depends on how the
    // engine's sort happens to break them.
    const order = shares
      .map((share, index) => ({ index, fraction: share.minus(floored[index]) }))
      .sort((a, b) => b.fraction.comparedTo(a.fraction) || a.index - b.index);

    const unit = new Decimal(1).dividedBy(new Decimal(10).pow(MONEY_SCALE));
    for (const { index } of order) {
      if (remainder.lessThan(unit)) break;
      floored[index] = floored[index].plus(unit);
      remainder = remainder.minus(unit);
    }
    // An amount finer than the stored precision leaves less than one unit
    // over. It still belongs to someone, or the parts would not add up.
    if (!remainder.isZero()) {
      floored[order[0].index] = floored[order[0].index].plus(remainder);
    }

    return floored.map(
      (part) => new Money(negative ? part.negated() : part, this.currency),
    );
  }

  // ── Conversion ────────────────────────────────────────────────────────

  /**
   * Converts using an explicit rate. There is deliberately no ambient
   * "current rate" lookup here: an order freezes its rate and every later
   * recomputation must be handed that same frozen value (Q46).
   */
  convertTo(target: Currency, rate: Decimal | string | number): Money {
    if (target === this.currency) return this;
    const r = new Decimal(rate as Prisma.Decimal.Value);
    if (!r.isFinite() || r.lessThanOrEqualTo(0)) {
      throw new BadRequestException('Exchange rate must be positive');
    }
    return new Money(this.amount.times(r), target);
  }

  // ── Output ────────────────────────────────────────────────────────────

  /** The value to persist in a `Decimal` column. */
  toPrisma(): Decimal {
    return this.amount;
  }

  /**
   * The wire shape. Amounts cross the wire as strings so no JSON parser can
   * round them, and the currency always travels with the number.
   */
  toJSON(): { amount: string; currency: Currency } {
    return { amount: this.amount.toFixed(4), currency: this.currency };
  }

  /**
   * Escape hatch for arithmetic-free consumers (charts, thresholds, logs).
   * Never feed the result back into a money calculation.
   */
  toUnsafeNumber(): number {
    return this.amount.toNumber();
  }

  toString(): string {
    return `${this.amount.toFixed(4)} ${this.currency}`;
  }

  private assertSameCurrency(other: Money): void {
    if (other.currency !== this.currency) {
      throw new BadRequestException(
        `Currency mismatch: cannot combine ${this.currency} with ${other.currency}`,
      );
    }
  }
}

/** Decimal places every money column in the schema stores. */
export const MONEY_SCALE = 4;

const ROUNDING_STEP: Record<RoundingPolicy, number | null> = {
  [RoundingPolicy.NONE]: null,
  [RoundingPolicy.NEAREST_10]: 10,
  [RoundingPolicy.NEAREST_100]: 100,
  [RoundingPolicy.NEAREST_500]: 500,
  [RoundingPolicy.NEAREST_1000]: 1000,
};

/**
 * How a Syrian pound figure is rounded today.
 *
 * Q48 asked for the nearest thousand, in the old lira. Syria has since dropped
 * two zeros, so the nearest **ten** is that same rule at the new scale — and
 * writing it once means the changeover was one edit rather than a hunt through
 * checkout, revaluation and the fee tables.
 */
export const SYP_ROUNDING = RoundingPolicy.NEAREST_10;
