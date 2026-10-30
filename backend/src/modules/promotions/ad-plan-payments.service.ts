import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EventEmitter2 } from '@nestjs/event-emitter';
import {
  AdPlanPurchase,
  AdPlanPurchaseStatus,
  Currency,
  PaymentMethodType,
  Prisma,
  StoreAdTier,
} from '@prisma/client';
import { Money } from '../../common/money';
import {
  AdPlanPurchaseDecidedPayload,
  AdPlanPurchaseSubmittedPayload,
  AppEvent,
} from '../../common/events/app-events';
import { PrismaService } from '../../prisma/prisma.service';
import { utcTimestamp } from '../../common/sql/utc-timestamp';
import { AdTiersService } from './ad-tiers.service';

/**
 * System setting: where a boutique sends the money for a plan, per method —
 * `{ "SHAM_CASH": "حوّلي إلى الرقم …", "BANK_TRANSFER": "…" }`. Edited from the
 * admin console, so changing the receiving number never needs a release.
 */
export const PAYMENT_INSTRUCTIONS_SETTING = 'promotions.payment_instructions';

/**
 * The ways a plan can be paid from outside the platform, in the order a
 * Syrian boutique reaches for them. Each is offered only once finance has
 * said where the money goes.
 */
export const TRANSFER_METHODS: readonly PaymentMethodType[] = [
  PaymentMethodType.SHAM_CASH,
  PaymentMethodType.SYRIATEL_CASH,
  PaymentMethodType.MTN_CASH,
  PaymentMethodType.BANK_TRANSFER,
  PaymentMethodType.HAWALA,
];

const OPEN: AdPlanPurchaseStatus[] = [
  AdPlanPurchaseStatus.AWAITING_PAYMENT,
  AdPlanPurchaseStatus.AWAITING_REVIEW,
];

/**
 * Paying for a plan by transfer, and finance's half of it.
 *
 * The seller's half: pick a plan and a method, see exactly where to send the
 * money and how much, send it, type the transaction number. Finance's half: a
 * queue of those numbers with confirm and reject. Confirming grants the plan
 * and books the money in one transaction, and claims the purchase first, so
 * two finance officers pressing confirm at once grant one plan.
 */
@Injectable()
export class AdPlanPaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tiers: AdTiersService,
    @Optional() private readonly config?: ConfigService,
    @Optional() private readonly events?: EventEmitter2,
  ) {}

  // ── Where the money goes ─────────────────────────────────────────────────

  async instructions(): Promise<Partial<Record<PaymentMethodType, string>>> {
    const setting = await this.prisma.systemSetting.findUnique({
      where: { key: PAYMENT_INSTRUCTIONS_SETTING },
      select: { value: true },
    });
    const stored = (setting?.value ?? {}) as Record<string, unknown>;
    // Bank transfer and hawala may already be configured for checkout; a
    // boutique paying for a plan sends money to the same accounts.
    const checkout =
      this.config?.get<Partial<Record<PaymentMethodType, string | null>>>(
        'payments.manualInstructions',
      ) ?? {};
    const out: Partial<Record<PaymentMethodType, string>> = {};
    for (const method of TRANSFER_METHODS) {
      const value = stored[method];
      const text =
        typeof value === 'string' && value.trim()
          ? value.trim()
          : checkout[method]?.trim();
      if (text) out[method] = text;
    }
    return out;
  }

  async setInstructions(
    actorId: string,
    values: Partial<Record<PaymentMethodType, string | null>>,
  ) {
    const clean: Record<string, string> = {};
    for (const method of TRANSFER_METHODS) {
      const text = values[method]?.trim();
      if (text) clean[method] = text.slice(0, 600);
    }
    await this.prisma.systemSetting.upsert({
      where: { key: PAYMENT_INSTRUCTIONS_SETTING },
      create: { key: PAYMENT_INSTRUCTIONS_SETTING, value: clean, updatedBy: actorId },
      update: { value: clean, updatedBy: actorId },
    });
    return this.adminInstructions();
  }

  async adminInstructions() {
    const configured = await this.instructions();
    return TRANSFER_METHODS.map((method) => ({
      method: method.toLowerCase(),
      instructions: configured[method] ?? null,
    }));
  }

  /** Everything she may pay a plan with, right now. */
  async options(sellerId: string) {
    const [balance, configured] = await Promise.all([
      this.tiers.earningsBalance(sellerId),
      this.instructions(),
    ]);
    return {
      earnings_balance: balance,
      currency: Currency.SYP,
      transfer_methods: TRANSFER_METHODS.filter((m) => configured[m]).map((method) => ({
        method: method.toLowerCase(),
        instructions: configured[method]!,
      })),
    };
  }

  // ── Her side ─────────────────────────────────────────────────────────────

  /**
   * She asks to pay for `tier` by `method`. Returns the purchase with where
   * to send the money. One open purchase at a time: a second request for the
   * same plan and method hands back the first rather than a duplicate.
   */
  async request(sellerId: string, tier: StoreAdTier, method: PaymentMethodType) {
    this.tiers.assertBuyable(tier);
    await this.tiers.assertCanAdvertise(sellerId);
    const configured = await this.instructions();
    if (!TRANSFER_METHODS.includes(method) || !configured[method]) {
      throw new BadRequestException({
        message: 'This payment method is not available for plans right now',
        code: 'payment_method_unavailable',
      });
    }

    const open = await this.prisma.adPlanPurchase.findFirst({
      where: { sellerId, status: { in: OPEN } },
      orderBy: { createdAt: 'desc' },
    });
    if (open) {
      if (open.tier === tier && open.method === method) {
        return this.serialize(open, configured);
      }
      throw new ConflictException({
        message: 'You already have a plan payment in progress',
        code: 'purchase_in_progress',
        purchase_id: open.id,
      });
    }

    const price = await this.tiers.priceOf(tier);
    const created = await this.prisma.adPlanPurchase.create({
      data: { sellerId, tier, method, amount: String(price), currency: Currency.SYP },
    });
    return this.serialize(created, configured);
  }

  /** The transaction number her wallet, bank or exchange office gave her. */
  async submitReference(sellerId: string, purchaseId: string, reference: string) {
    const ref = reference.trim();
    if (ref.length < 3) {
      throw new BadRequestException({
        message: 'Enter the transaction number you received',
        code: 'reference_required',
      });
    }
    const purchase = await this.requireOwn(sellerId, purchaseId);
    if (
      purchase.status !== AdPlanPurchaseStatus.AWAITING_PAYMENT &&
      purchase.status !== AdPlanPurchaseStatus.REJECTED &&
      purchase.status !== AdPlanPurchaseStatus.AWAITING_REVIEW
    ) {
      throw new BadRequestException({
        message: 'This payment can no longer be changed',
        code: 'purchase_closed',
      });
    }
    // A rejected payment may be retried only if nothing newer is open.
    if (purchase.status === AdPlanPurchaseStatus.REJECTED) {
      const other = await this.prisma.adPlanPurchase.findFirst({
        where: { sellerId, status: { in: OPEN }, id: { not: purchase.id } },
        select: { id: true },
      });
      if (other) {
        throw new ConflictException({
          message: 'You already have a plan payment in progress',
          code: 'purchase_in_progress',
        });
      }
    }
    const updated = await this.prisma.adPlanPurchase.update({
      where: { id: purchase.id },
      data: {
        reference: ref.slice(0, 120),
        referenceSubmittedAt: new Date(),
        status: AdPlanPurchaseStatus.AWAITING_REVIEW,
        rejectionReason: null,
      },
    });
    const payload: AdPlanPurchaseSubmittedPayload = {
      purchaseId: updated.id,
      sellerId,
      tier: updated.tier,
      amount: Money.of(updated.amount, updated.currency).toString(),
    };
    this.events?.emit(AppEvent.AdPlanPurchaseSubmitted, payload);
    return this.serialize(updated, await this.instructions());
  }

  async cancel(sellerId: string, purchaseId: string) {
    const purchase = await this.requireOwn(sellerId, purchaseId);
    const claimed = await this.prisma.adPlanPurchase.updateMany({
      where: {
        id: purchase.id,
        status: { in: [...OPEN, AdPlanPurchaseStatus.REJECTED] },
      },
      data: { status: AdPlanPurchaseStatus.CANCELLED },
    });
    if (claimed.count === 0) {
      throw new BadRequestException({
        message: 'This payment can no longer be cancelled',
        code: 'purchase_closed',
      });
    }
    return this.serialize(
      await this.prisma.adPlanPurchase.findUniqueOrThrow({ where: { id: purchase.id } }),
      await this.instructions(),
    );
  }

  async mine(sellerId: string) {
    const [rows, configured] = await Promise.all([
      this.prisma.adPlanPurchase.findMany({
        where: { sellerId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
      this.instructions(),
    ]);
    return rows.map((row) => this.serialize(row, configured));
  }

  /** The purchase still waiting on her or on finance, if any. */
  async openFor(sellerId: string) {
    const row = await this.prisma.adPlanPurchase.findFirst({
      where: {
        sellerId,
        OR: [
          { status: { in: OPEN } },
          // A rejection stays in front of her until she retries or cancels.
          {
            status: AdPlanPurchaseStatus.REJECTED,
            decidedAt: { gt: new Date(Date.now() - 14 * 86_400_000) },
          },
        ],
      },
      orderBy: { createdAt: 'desc' },
    });
    return row ? this.serialize(row, await this.instructions()) : null;
  }

  // ── Finance's side ───────────────────────────────────────────────────────

  async pending() {
    const rows = await this.prisma.adPlanPurchase.findMany({
      where: { status: { in: OPEN } },
      orderBy: [{ status: 'desc' }, { referenceSubmittedAt: 'asc' }, { createdAt: 'asc' }],
      take: 200,
      include: { seller: { select: { id: true, name: true, phone: true } } },
    });
    const configured = await this.instructions();
    return rows.map((row) => ({
      ...this.serialize(row, configured),
      seller: { id: row.seller.id, name: row.seller.name, phone: row.seller.phone },
    }));
  }

  /**
   * The money arrived: the plan is hers. Claimed first, granted and booked in
   * the same transaction, so a double confirm grants once.
   */
  async confirm(actorId: string, purchaseId: string) {
    const result = await this.prisma.$transaction(async (tx) => {
      const claimed = await tx.adPlanPurchase.updateMany({
        where: { id: purchaseId, status: { in: OPEN } },
        data: {
          status: AdPlanPurchaseStatus.CONFIRMED,
          decidedById: actorId,
          decidedAt: new Date(),
          rejectionReason: null,
        },
      });
      const purchase = await tx.adPlanPurchase.findUnique({ where: { id: purchaseId } });
      if (!purchase) throw new NotFoundException('Plan payment not found');
      if (claimed.count === 0) return { purchase, granted: false };

      const subscription = await this.tiers.grant(
        tx,
        purchase.sellerId,
        purchase.tier,
        Number(purchase.amount),
        {
          kind: 'transfer',
          reference: `${purchase.method}:${purchase.reference ?? purchase.id}`,
        },
      );
      const linked = await tx.adPlanPurchase.update({
        where: { id: purchase.id },
        data: { subscriptionId: subscription.id },
      });
      return { purchase: linked, granted: true, startsAt: subscription.startsAt };
    });

    if (result.purchase.status !== AdPlanPurchaseStatus.CONFIRMED) {
      throw new BadRequestException({
        message: 'This payment was already decided',
        code: 'purchase_closed',
      });
    }
    if (result.granted) {
      const payload: AdPlanPurchaseDecidedPayload = {
        purchaseId: result.purchase.id,
        sellerId: result.purchase.sellerId,
        tier: result.purchase.tier,
        confirmed: true,
        startsAt: result.startsAt?.toISOString(),
      };
      this.events?.emit(AppEvent.AdPlanPurchaseDecided, payload);
    }
    return this.serialize(result.purchase, await this.instructions());
  }

  async reject(actorId: string, purchaseId: string, reason: string) {
    const why = reason.trim();
    if (!why) throw new BadRequestException('A reason is required');
    const claimed = await this.prisma.adPlanPurchase.updateMany({
      where: { id: purchaseId, status: { in: OPEN } },
      data: {
        status: AdPlanPurchaseStatus.REJECTED,
        rejectionReason: why.slice(0, 400),
        decidedById: actorId,
        decidedAt: new Date(),
      },
    });
    const purchase = await this.prisma.adPlanPurchase.findUnique({ where: { id: purchaseId } });
    if (!purchase) throw new NotFoundException('Plan payment not found');
    if (claimed.count === 0) {
      throw new BadRequestException({
        message: 'This payment was already decided',
        code: 'purchase_closed',
      });
    }
    const payload: AdPlanPurchaseDecidedPayload = {
      purchaseId: purchase.id,
      sellerId: purchase.sellerId,
      tier: purchase.tier,
      confirmed: false,
      reason: why,
    };
    this.events?.emit(AppEvent.AdPlanPurchaseDecided, payload);
    return this.serialize(purchase, await this.instructions());
  }

  /** The figures finance and the owner want at a glance. */
  async summary() {
    const now = new Date();
    const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
    const [active, pending, plans, campaigns] = await Promise.all([
      this.prisma.storeAdSubscription.groupBy({
        by: ['tier'],
        where: { startsAt: { lte: now }, endsAt: { gt: now } },
        _count: { _all: true },
      }),
      this.prisma.adPlanPurchase.count({
        where: { status: AdPlanPurchaseStatus.AWAITING_REVIEW },
      }),
      this.prisma.storeAdSubscription.aggregate({
        where: { createdAt: { gte: monthStart }, chargeReference: { not: null } },
        _sum: { priceAmount: true },
      }),
      this.prisma.$queryRaw<{ total: Prisma.Decimal | null }[]>`
        SELECT SUM(fee_amount - credit_applied) AS total FROM product_promotions
         WHERE charged_at IS NOT NULL AND charged_at >= ${utcTimestamp(monthStart)}`,
    ]);
    return {
      active_plans: Object.fromEntries(
        active.map((row) => [row.tier.toLowerCase(), row._count._all]),
      ),
      awaiting_review: pending,
      revenue_this_month:
        Number(plans._sum.priceAmount ?? 0) + Number(campaigns[0]?.total ?? 0),
      currency: Currency.SYP,
    };
  }

  // ── internals ────────────────────────────────────────────────────────────

  private async requireOwn(sellerId: string, purchaseId: string) {
    const purchase = await this.prisma.adPlanPurchase.findUnique({
      where: { id: purchaseId },
    });
    if (!purchase || purchase.sellerId !== sellerId) {
      throw new NotFoundException('Plan payment not found');
    }
    return purchase;
  }

  serialize(
    row: AdPlanPurchase,
    configured: Partial<Record<PaymentMethodType, string>>,
  ) {
    return {
      id: row.id,
      tier: row.tier.toLowerCase(),
      method: row.method.toLowerCase(),
      amount: Number(row.amount),
      currency: row.currency,
      status: row.status.toLowerCase(),
      instructions: configured[row.method] ?? null,
      reference: row.reference,
      reference_submitted_at: row.referenceSubmittedAt?.toISOString() ?? null,
      rejection_reason: row.rejectionReason,
      decided_at: row.decidedAt?.toISOString() ?? null,
      created_at: row.createdAt.toISOString(),
    };
  }
}
