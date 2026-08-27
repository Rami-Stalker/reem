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
    return new Money(new Decimal(value as Prisma.Decimal.Value), currency);
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
    return new Money(
      this.amount.times(new Decimal(factor as Prisma.Decimal.Value)),
      this.currency,
    );
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

  /** Rounding appropriate to the currency when no order policy applies. */
  roundForCurrency(): Money {
    return this.round(
      this.currency === Currency.SYP
        ? RoundingPolicy.NEAREST_1000
        : RoundingPolicy.NONE,
    );
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

    const shares = decimalWeights.map((w) =>
      this.amount.times(w).dividedBy(totalWeight),
    );
    const floored = shares.map((s) => s.toDecimalPlaces(4, Decimal.ROUND_DOWN));
    let remainder = floored.reduce(
      (rest, part) => rest.minus(part),
      this.amount,
    );

    // Hand the leftover units to the largest fractional parts, one at a time.
    const order = shares
      .map((share, index) => ({ index, fraction: share.minus(floored[index]) }))
      .sort((a, b) => b.fraction.comparedTo(a.fraction));

    const unit = new Decimal('0.0001');
    for (const { index } of order) {
      if (remainder.lessThanOrEqualTo(0)) break;
      floored[index] = floored[index].plus(unit);
      remainder = remainder.minus(unit);
    }

    return floored.map((part) => new Money(part, this.currency));
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
    if (r.lessThanOrEqualTo(0)) {
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

const ROUNDING_STEP: Record<RoundingPolicy, number | null> = {
  [RoundingPolicy.NONE]: null,
  [RoundingPolicy.NEAREST_100]: 100,
  [RoundingPolicy.NEAREST_500]: 500,
  [RoundingPolicy.NEAREST_1000]: 1000,
};
