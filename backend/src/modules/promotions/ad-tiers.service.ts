import { BadRequestException, Injectable } from '@nestjs/common';
import {
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  Prisma,
  StoreAdTier,
} from '@prisma/client';
import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService } from '../ledger/ledger.service';
import { AD_PLANS, AdPlan, PLAN_PERIOD_DAYS, tierRank } from './ad-plans';

type Tx = Prisma.TransactionClient;

/** System setting overriding plan prices: `{ "SILVER": 25000, ... }` in SYP. */
export const PLAN_PRICES_SETTING = 'promotions.plan_prices_syp';

export interface ActivePlan {
  tier: StoreAdTier;
  plan: AdPlan;
  subscriptionId: string | null;
  endsAt: Date | null;
  creditGranted: number;
  creditUsed: number;
  creditRemaining: number;
}

const FREE_PLAN: ActivePlan = {
  tier: StoreAdTier.FREE,
  plan: AD_PLANS.FREE,
  subscriptionId: null,
  endsAt: null,
  creditGranted: 0,
  creditUsed: 0,
  creditRemaining: 0,
};

/**
 * A boutique's plan, and the money that buys it.
 *
 * A plan is a row with a window. The one whose window holds "now" is her tier;
 * no row means Free. Upgrading ends the current row now and carries its unused
 * credit into the new one, so nothing she paid for is lost; renewing or
 * buying a lower plan queues the new row after the current one, so nothing she
 * paid for is cut short either.
 */
@Injectable()
export class AdTiersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
  ) {}

  async current(sellerId: string, db: Tx | PrismaService = this.prisma): Promise<ActivePlan> {
    const now = new Date();
    const rows = await db.storeAdSubscription.findMany({
      where: { sellerId, startsAt: { lte: now }, endsAt: { gt: now } },
    });
    if (rows.length === 0) return FREE_PLAN;
    // Overlap should not happen, but if it does the higher plan wins.
    const row = rows.sort((a, b) => tierRank(b.tier) - tierRank(a.tier))[0];
    const granted = Number(row.creditGranted);
    const used = Number(row.creditUsed);
    return {
      tier: row.tier,
      plan: AD_PLANS[row.tier],
      subscriptionId: row.id,
      endsAt: row.endsAt,
      creditGranted: granted,
      creditUsed: used,
      creditRemaining: Math.max(0, granted - used),
    };
  }

  /** The tier of each boutique, for the serving path. One query for all. */
  async tiersOf(sellerIds: readonly string[]): Promise<Map<string, StoreAdTier>> {
    const out = new Map<string, StoreAdTier>();
    if (sellerIds.length === 0) return out;
    const now = new Date();
    const rows = await this.prisma.storeAdSubscription.findMany({
      where: {
        sellerId: { in: [...new Set(sellerIds)] },
        startsAt: { lte: now },
        endsAt: { gt: now },
      },
      select: { sellerId: true, tier: true },
    });
    for (const row of rows) {
      const seen = out.get(row.sellerId);
      if (!seen || tierRank(row.tier) > tierRank(seen)) out.set(row.sellerId, row.tier);
    }
    return out;
  }

  async history(sellerId: string) {
    return this.prisma.storeAdSubscription.findMany({
      where: { sellerId },
      orderBy: { startsAt: 'desc' },
      take: 12,
    });
  }

  /** The price of a plan, from the console's setting when one is set. */
  async priceOf(tier: StoreAdTier): Promise<number> {
    const setting = await this.prisma.systemSetting.findUnique({
      where: { key: PLAN_PRICES_SETTING },
      select: { value: true },
    });
    const raw = setting?.value as Record<string, unknown> | null | undefined;
    const override = raw && typeof raw === 'object' ? Number(raw[tier]) : NaN;
    return Number.isFinite(override) && override >= 0 ? override : AD_PLANS[tier].priceSyp;
  }

  /**
   * Buys a plan: charges it from her earnings and grants its credit.
   *
   * - No plan, or an upgrade: starts now. An upgrade ends the old plan now
   *   and carries its unused credit over.
   * - The same plan or a lower one: queued to start when the current ends.
   */
  async subscribe(sellerId: string, tier: StoreAdTier) {
    if (tier === StoreAdTier.FREE) {
      throw new BadRequestException(
        'The free plan needs no purchase — a plan simply returns to free when it ends',
      );
    }
    const price = await this.priceOf(tier);
    const plan = AD_PLANS[tier];

    const fee = Money.of(String(price), Currency.SYP);

    return this.prisma.$transaction(async (tx) => {
      // Before anything is written: a refusal leaves no half-bought plan.
      if (price > 0) await this.assertCanPay(sellerId, fee, tx);
      const now = new Date();
      const queued = await tx.storeAdSubscription.findFirst({
        where: { sellerId, startsAt: { gt: now } },
        select: { id: true },
      });
      if (queued) {
        throw new BadRequestException('A plan is already queued to start after this one');
      }

      const current = await this.current(sellerId, tx);
      let startsAt = now;
      let carried = 0;

      if (current.subscriptionId && tierRank(tier) > tierRank(current.tier)) {
        carried = current.creditRemaining;
        await tx.storeAdSubscription.update({
          where: { id: current.subscriptionId },
          data: { endsAt: now },
        });
      } else if (current.subscriptionId && current.endsAt) {
        startsAt = current.endsAt;
      }

      const endsAt = new Date(startsAt.getTime() + PLAN_PERIOD_DAYS * 86_400_000);
      const created = await tx.storeAdSubscription.create({
        data: {
          sellerId,
          tier,
          priceAmount: String(price),
          priceCurrency: Currency.SYP,
          startsAt,
          endsAt,
          creditGranted: String(plan.creditSyp + carried),
        },
      });

      if (price > 0) {
        const reference = `ad-plan:${created.id}`;
        await this.ledger.post(
          {
            type: JournalEntryType.MANUAL_ADJUSTMENT,
            reference,
            description: `باقة إعلان — ${tier}`,
            lines: [
              {
                account: { code: LedgerAccountCode.SELLER_PAYABLE, ownerId: sellerId },
                direction: LedgerDirection.DEBIT,
                amount: fee,
              },
              {
                account: { code: LedgerAccountCode.PROMOTION_REVENUE },
                direction: LedgerDirection.CREDIT,
                amount: fee,
              },
            ],
          },
          tx,
        );
        return tx.storeAdSubscription.update({
          where: { id: created.id },
          data: { chargeReference: reference },
        });
      }
      return created;
    });
  }

  /**
   * Spends up to `amount` of her current plan's credit, inside the caller's
   * transaction. Returns what was actually spent.
   *
   * The increment is guarded in SQL so two campaigns going live at once can
   * never spend the same lira of credit twice.
   */
  async spendCredit(sellerId: string, amount: number, tx: Tx): Promise<number> {
    if (amount <= 0) return 0;
    const current = await this.current(sellerId, tx);
    if (!current.subscriptionId || current.creditRemaining <= 0) return 0;
    const spend = Math.min(amount, current.creditRemaining);
    const updated = await tx.$executeRaw`
      UPDATE store_ad_subscriptions
         SET credit_used = credit_used + ${spend}, updated_at = now()
       WHERE id = ${current.subscriptionId}::uuid
         AND credit_granted - credit_used >= ${spend}`;
    return updated === 1 ? spend : 0;
  }

  /**
   * Refuses a charge her earnings cannot cover.
   *
   * The ledger itself would happily take the payable below zero — that is a
   * receivable from the boutique that nobody is chasing. Better to say no, and
   * say why.
   */
  async assertCanPay(sellerId: string, amount: Money, tx?: Tx): Promise<void> {
    const balance = await this.ledger.balanceOf(
      { code: LedgerAccountCode.SELLER_PAYABLE, ownerId: sellerId },
      amount.currency,
      tx,
    );
    if (balance.lessThan(amount)) {
      throw new BadRequestException({
        message: `Your earnings balance (${balance.toString()}) does not cover ${amount.toString()}`,
        code: 'insufficient_balance',
        balance: balance.toJSON(),
        required: amount.toJSON(),
      });
    }
  }
}
