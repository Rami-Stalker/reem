import { Injectable } from '@nestjs/common';
import { CommissionRule, Currency, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money } from '../../common/money';

export interface CommissionQuote {
  readonly rule: CommissionRule | null;
  readonly base: Money;
  readonly commission: Money;
  readonly net: Money;
}

/** Fallback when no rule matches: 10%. */
const DEFAULT_RATE_BPS = 1000;

/**
 * Commission pricing, isolated from the reporting service so checkout can quote
 * a sub-order without pulling in the whole settlement machinery.
 *
 * Two rules the old implementation got wrong and this one encodes:
 * commission is charged on the POST-discount item total (Q50 P2), and the rate
 * varies by seller tier as well as category (Q18 P1) — so it is resolved per
 * sub-order, never once per basket.
 */
@Injectable()
export class CommissionQuoteService {
  constructor(private readonly prisma: PrismaService) {}

  async quote(input: {
    sellerId: string;
    sellerTier: string;
    categorySlugs: string[];
    base: Money;
  }): Promise<CommissionQuote> {
    const rule = await this.ruleFor(input.categorySlugs, input.sellerTier);
    const commission = this.applyRule(input.base, rule);

    return {
      rule,
      base: input.base,
      commission,
      net: input.base.minus(commission),
    };
  }

  applyRule(base: Money, rule: CommissionRule | null): Money {
    const currency = base.currency;
    let commission = base.percentBps(rule?.rateBps ?? DEFAULT_RATE_BPS);

    if (rule) {
      // A rule's fixed fee and bounds are stored in the rule's own currency.
      // Applying them to a differently-priced offer would silently mix
      // currencies, so they only apply when the currencies agree.
      if (rule.currency === currency) {
        commission = commission.plus(Money.of(rule.fixedFee, currency));
        if (rule.minCommission !== null) {
          commission = commission.clampMin(
            Money.of(rule.minCommission, currency),
          );
        }
        if (rule.maxCommission !== null) {
          commission = commission.clampMax(
            Money.of(rule.maxCommission, currency),
          );
        }
      }
      if (rule.platformFeeBps > 0) {
        commission = commission.plus(base.percentBps(rule.platformFeeBps));
      }
    }

    // Never charge more than the sale itself — and to the precision it is
    // stored at. A basis-point rate on an odd base runs to seven or eight
    // places; stored as-is, commission and net would each be rounded by the
    // database on their own and could stop adding back up to the base.
    return commission
      .clampMax(base)
      .clampMin(Money.zero(currency))
      .quantize()
      .clampMax(base);
  }

  /**
   * The most specific active rule wins: a category+tier rule beats a
   * category-only rule, which beats a global one.
   */
  private async ruleFor(
    categorySlugs: string[],
    sellerTier: string,
  ): Promise<CommissionRule | null> {
    const now = new Date();
    const rules = await this.prisma.commissionRule.findMany({
      where: {
        active: true,
        startsAt: { lte: now },
        AND: [
          { OR: [{ endsAt: null }, { endsAt: { gt: now } }] },
          { OR: [{ category: null }, { category: { in: categorySlugs } }] },
          { OR: [{ sellerTier: null }, { sellerTier } ] },
        ],
      },
      orderBy: [
        { priority: 'asc' },
        { category: 'desc' },
        { sellerTier: 'desc' },
      ],
      take: 1,
    });
    return rules[0] ?? null;
  }

  /** Convenience for callers holding raw Decimal columns. */
  moneyOf(value: Prisma.Decimal, currency: Currency): Money {
    return Money.of(value, currency);
  }
}
