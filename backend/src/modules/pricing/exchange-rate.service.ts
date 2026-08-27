import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { Currency, ExchangeRate, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money } from '../../common/money';

const Decimal = Prisma.Decimal;

/**
 * A rate captured at a point in time, along with the row it came from, so the
 * caller can persist BOTH onto an order (Q46 P2: "يتجمّد سعر لحظة الطلب").
 */
export interface FrozenRate {
  readonly rateId: string | null;
  readonly rate: Prisma.Decimal;
  readonly base: Currency;
  readonly quote: Currency;
  readonly frozenAt: Date;
  readonly source: string;
}

/**
 * Currency conversion for the whole platform.
 *
 * The rule this service enforces: a price is quoted with a rate, and the order
 * stores the rate it was quoted at. Nothing recomputes an old order against
 * today's rate — in a market where the SYP moves daily that is the difference
 * between a correct refund and an angry customer.
 */
@Injectable()
export class ExchangeRateService {
  private readonly logger = new Logger(ExchangeRateService.name);

  constructor(private readonly prisma: PrismaService) {}

  /** The rate in force right now for base → quote. */
  async current(base: Currency, quote: Currency): Promise<FrozenRate> {
    if (base === quote) {
      return {
        rateId: null,
        rate: new Decimal(1),
        base,
        quote,
        frozenAt: new Date(),
        source: 'identity',
      };
    }

    const now = new Date();
    const direct = await this.findActive(base, quote, now);
    if (direct) return this.freeze(direct, base, quote, now);

    // A single stored direction is enough; the inverse is derived rather than
    // stored twice, so the two can never drift apart.
    const inverse = await this.findActive(quote, base, now);
    if (inverse) {
      if (inverse.rate.lessThanOrEqualTo(0)) {
        throw new BadRequestException('Stored exchange rate is not positive');
      }
      return {
        rateId: inverse.id,
        rate: new Decimal(1).dividedBy(inverse.rate),
        base,
        quote,
        frozenAt: now,
        source: `${inverse.source}:inverse`,
      };
    }

    throw new BadRequestException(
      `No exchange rate is configured for ${base} to ${quote}`,
    );
  }

  /**
   * Re-reads a rate that was previously frozen onto an order. Falls back to the
   * stored numeric rate when the row itself has been pruned, because the number
   * is the contract — the row is only provenance.
   */
  async replay(
    rateId: string | null,
    storedRate: Prisma.Decimal,
    base: Currency,
    quote: Currency,
    frozenAt: Date,
  ): Promise<FrozenRate> {
    if (!rateId) {
      return { rateId: null, rate: storedRate, base, quote, frozenAt, source: 'frozen' };
    }
    const row = await this.prisma.exchangeRate.findUnique({ where: { id: rateId } });
    if (!row) {
      this.logger.warn(`Exchange rate ${rateId} no longer exists; replaying stored value`);
      return { rateId, rate: storedRate, base, quote, frozenAt, source: 'frozen' };
    }
    return this.freeze(row, base, quote, frozenAt);
  }

  /** Converts using an explicitly supplied rate — never an ambient one. */
  convert(amount: Money, target: Currency, rate: FrozenRate): Money {
    if (amount.currency === target) return amount;
    if (rate.base === amount.currency && rate.quote === target) {
      return amount.convertTo(target, rate.rate);
    }
    if (rate.base === target && rate.quote === amount.currency) {
      return amount.convertTo(target, new Decimal(1).dividedBy(rate.rate));
    }
    throw new BadRequestException(
      `Rate ${rate.base}/${rate.quote} cannot convert ${amount.currency} to ${target}`,
    );
  }

  /**
   * Normalises any amount to SYP for catalog sorting and cross-seller
   * comparison. Display still uses the seller's own currency.
   */
  async toSyp(amount: Money): Promise<Money> {
    if (amount.currency === Currency.SYP) return amount;
    const rate = await this.current(amount.currency, Currency.SYP);
    return this.convert(amount, Currency.SYP, rate);
  }

  /**
   * Publishes a new rate and closes the previous one. Rates are append-only:
   * historical orders must always be able to resolve the row they used.
   */
  async publish(input: {
    base: Currency;
    quote: Currency;
    rate: Prisma.Decimal | string | number;
    source?: string;
    createdById?: string | null;
  }): Promise<ExchangeRate> {
    const rate = new Decimal(input.rate as Prisma.Decimal.Value);
    if (rate.lessThanOrEqualTo(0)) {
      throw new BadRequestException('Exchange rate must be positive');
    }
    if (input.base === input.quote) {
      throw new BadRequestException('Base and quote currency must differ');
    }

    const now = new Date();
    return this.prisma.$transaction(async (tx) => {
      await tx.exchangeRate.updateMany({
        where: { base: input.base, quote: input.quote, effectiveTo: null },
        data: { effectiveTo: now },
      });
      return tx.exchangeRate.create({
        data: {
          base: input.base,
          quote: input.quote,
          rate,
          source: input.source ?? 'manual',
          effectiveFrom: now,
          createdById: input.createdById ?? null,
        },
      });
    });
  }

  async history(base: Currency, quote: Currency, take = 50): Promise<ExchangeRate[]> {
    return this.prisma.exchangeRate.findMany({
      where: { base, quote },
      orderBy: { effectiveFrom: 'desc' },
      take,
    });
  }

  private findActive(base: Currency, quote: Currency, at: Date) {
    return this.prisma.exchangeRate.findFirst({
      where: {
        base,
        quote,
        effectiveFrom: { lte: at },
        OR: [{ effectiveTo: null }, { effectiveTo: { gt: at } }],
      },
      orderBy: { effectiveFrom: 'desc' },
    });
  }

  private freeze(
    row: ExchangeRate,
    base: Currency,
    quote: Currency,
    at: Date,
  ): FrozenRate {
    return {
      rateId: row.id,
      rate: row.rate,
      base,
      quote,
      frozenAt: at,
      source: row.source,
    };
  }
}
