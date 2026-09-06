import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Currency,
  OfferStatus,
  Prisma,
  PurchasePlan,
  PurchasePlanStatus,
  PurchaseStage,
  RoomCandidateStatus,
  RoomEventKind,
  RoomStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { PurchasableLine } from '../cart/cart.serializer';
import { CheckoutService } from '../orders/checkout.service';
import { CreateOrderDto } from '../orders/dto/create-order.dto';
import { ExchangeRateService } from '../pricing/exchange-rate.service';
import { Money } from '../../common/money';
import { RoomAccessService } from './room-access.service';
import { RoomEventService } from './room-event.service';
import {
  BudgetFit,
  CandidateFacts,
  DecisionFacts,
  RoomReadiness,
  budgetFit,
  roomReadiness,
} from './kernel/room-readiness';

/** How a plan is loaded when its lines have to be priced or bought. */
const PLAN_INCLUDE = {
  items: {
    orderBy: [{ stage: 'asc' as const }, { position: 'asc' as const }],
    include: {
      decision: { select: { id: true, title: true } },
      candidate: { select: { id: true, note: true } },
      offer: {
        include: {
          seller: true,
          product: {
            include: {
              media: { orderBy: { sortOrder: 'asc' as const } },
              category: true,
            },
          },
        },
      },
      offerVariant: { include: { variant: true } },
    },
  },
} satisfies Prisma.PurchasePlanInclude;

export type PlanRecord = Prisma.PurchasePlanGetPayload<{
  include: typeof PLAN_INCLUDE;
}>;

export interface PlanView {
  plan: PlanRecord;
  readiness: RoomReadiness;
  budget: BudgetFit;
  /** Lines whose offer has since gone or run out. */
  unavailable: string[];
}

/**
 * The plan: what the room decided, as something buyable.
 *
 * This is the object that replaces the cart, and the three things it does
 * differently are the whole argument:
 *
 *  1. **It is drawn, not filled.** `draw` reads the *resolved decisions* and
 *     nothing else. A candidate nobody chose is not in the plan however long it
 *     sat in the room, which is the opposite of a cart, where everything ever
 *     added is in the total until somebody remembers to take it out.
 *  2. **It stages.** "The dress now, the shoes next month" is an ordinary way to
 *     buy an outfit; a cart makes it two unrelated visits with nothing
 *     remembering they were one plan.
 *  3. **It never goes through a cart.** `checkout` hands its own lines to
 *     `CheckoutService.checkoutLines`, so a woman's cart is neither read nor
 *     emptied by buying out of a room.
 *
 * No money is stored on the plan. Prices and stock move; a plan that remembered
 * last week's total would show her a number that had quietly stopped being true.
 * Totals are computed on read and frozen exactly once, by checkout, onto the
 * order — the same place this codebase already freezes an FX rate.
 */
@Injectable()
export class PurchasePlanService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: RoomAccessService,
    private readonly events: RoomEventService,
    private readonly checkout: CheckoutService,
    private readonly rates: ExchangeRateService,
  ) {}

  /**
   * Turn the room's resolved decisions into a plan.
   *
   * Refuses a room that is not ready, and says which decisions are holding it —
   * because "you cannot buy yet" without naming what is missing is the least
   * useful sentence a shopping app can produce.
   */
  async draw(roomId: string, userId: string): Promise<PlanView> {
    await this.access.require(roomId, userId, 'buy');
    const readiness = await this.readiness(roomId);

    if (!readiness.ready) {
      throw new BadRequestException({
        message: 'This room still has decisions open',
        blockers: readiness.blockers,
      });
    }

    const chosen = await this.prisma.roomCandidate.findMany({
      where: {
        decision: { roomId },
        status: RoomCandidateStatus.CHOSEN,
      },
      include: { decision: { select: { id: true, position: true } } },
      orderBy: [{ decision: { position: 'asc' } }, { position: 'asc' }],
    });

    if (!chosen.length) {
      throw new BadRequestException('Nothing has been chosen in this room');
    }

    const last = await this.prisma.purchasePlan.findFirst({
      where: { roomId },
      orderBy: { version: 'desc' },
      select: { version: true },
    });

    const plan = await this.prisma.$transaction(async (tx) => {
      // A room may be re-planned as it changes; only the newest draft is live,
      // and superseding rather than editing keeps the older one readable.
      await tx.purchasePlan.updateMany({
        where: { roomId, status: PurchasePlanStatus.DRAFT },
        data: { status: PurchasePlanStatus.CANCELLED, cancelledAt: new Date() },
      });

      return tx.purchasePlan.create({
        data: {
          roomId,
          buyerId: userId,
          version: (last?.version ?? 0) + 1,
          items: {
            create: chosen.map((candidate, index) => ({
              decisionId: candidate.decisionId,
              candidateId: candidate.id,
              offerId: candidate.offerId,
              offerVariantId: candidate.offerVariantId,
              quantity: candidate.quantity,
              stage: PurchaseStage.NOW,
              position: index,
            })),
          },
        },
      });
    });

    await this.prisma.room.update({
      where: { id: roomId },
      data: { status: RoomStatus.READY },
    });
    await this.events.record(roomId, RoomEventKind.PLAN_DRAWN, userId, {
      planId: plan.id,
      lines: chosen.length,
    });

    return this.view(plan.id, userId);
  }

  /** The live plan for a room, priced now. */
  async current(roomId: string, userId: string): Promise<PlanView | null> {
    await this.access.require(roomId, userId);
    const plan = await this.prisma.purchasePlan.findFirst({
      where: {
        roomId,
        status: { in: [PurchasePlanStatus.DRAFT, PurchasePlanStatus.CONFIRMED] },
      },
      orderBy: { version: 'desc' },
      select: { id: true },
    });
    return plan ? this.view(plan.id, userId) : null;
  }

  async view(planId: string, userId: string): Promise<PlanView> {
    const plan = await this.prisma.purchasePlan.findUnique({
      where: { id: planId },
      include: PLAN_INCLUDE,
    });
    if (!plan) throw new NotFoundException('Plan not found');
    await this.access.require(plan.roomId, userId);

    const room = await this.prisma.room.findUniqueOrThrow({
      where: { id: plan.roomId },
      select: { budgetMinSyp: true, budgetMaxSyp: true },
    });

    const unavailable: string[] = [];
    const priced = await Promise.all(
      plan.items.map(async (item) => {
        const stock = item.offerVariant?.stock ?? item.offer.stock;
        const live =
          item.offer.status === OfferStatus.ACTIVE &&
          item.offer.isActive &&
          stock >= item.quantity;
        if (!live) unavailable.push(item.id);

        return {
          unitPriceSyp: live ? await this.unitPriceSyp(item) : null,
          quantity: item.quantity,
        };
      }),
    );

    return {
      plan,
      readiness: await this.readiness(plan.roomId),
      budget: budgetFit(priced, {
        minSyp: room.budgetMinSyp ? Number(room.budgetMinSyp) : null,
        maxSyp: room.budgetMaxSyp ? Number(room.budgetMaxSyp) : null,
      }),
      unavailable,
    };
  }

  /**
   * Move a line between now and later.
   *
   * The plan's own verb. A cart has no equivalent, which is why "I'll get the
   * shoes next month" ends with the shoes deleted and forgotten.
   */
  async setStage(
    planId: string,
    userId: string,
    itemId: string,
    stage: PurchaseStage,
  ): Promise<PlanView> {
    const plan = await this.requireEditable(planId, userId);
    await this.prisma.purchasePlanItem.updateMany({
      where: { id: itemId, planId: plan.id },
      data: { stage },
    });
    return this.view(plan.id, userId);
  }

  async setQuantity(
    planId: string,
    userId: string,
    itemId: string,
    quantity: number,
  ): Promise<PlanView> {
    const plan = await this.requireEditable(planId, userId);
    if (quantity < 1) throw new BadRequestException('Quantity must be at least 1');
    await this.prisma.purchasePlanItem.updateMany({
      where: { id: itemId, planId: plan.id },
      data: { quantity },
    });
    return this.view(plan.id, userId);
  }

  async removeItem(
    planId: string,
    userId: string,
    itemId: string,
  ): Promise<PlanView> {
    const plan = await this.requireEditable(planId, userId);
    await this.prisma.purchasePlanItem.deleteMany({
      where: { id: itemId, planId: plan.id },
    });
    return this.view(plan.id, userId);
  }

  /**
   * Buy the `NOW` stage.
   *
   * The one place a room becomes an order, and it goes straight to
   * `checkoutLines` — no cart is read, filled or emptied on the way. `LATER`
   * lines stay on the plan, which is what makes staging mean anything.
   */
  async checkoutPlan(planId: string, userId: string, dto: CreateOrderDto) {
    const plan = await this.prisma.purchasePlan.findUnique({
      where: { id: planId },
      include: PLAN_INCLUDE,
    });
    if (!plan) throw new NotFoundException('Plan not found');

    const access = await this.access.require(plan.roomId, userId, 'buy');
    if (plan.status === PurchasePlanStatus.ORDERED) {
      throw new BadRequestException('This plan has already been bought');
    }
    if (plan.status === PurchasePlanStatus.CANCELLED) {
      throw new BadRequestException('This plan was superseded — draw a new one');
    }

    const now = plan.items.filter((item) => item.stage === PurchaseStage.NOW);
    if (!now.length) {
      throw new BadRequestException('Nothing is staged to buy now');
    }

    // The plan's lines, shaped as checkout needs them. Structurally a
    // `PurchasableLine` — see the type's own comment for why checkout stopped
    // insisting on cart rows.
    const lines: PurchasableLine[] = now.map((item) => ({
      offerId: item.offerId,
      offerVariantId: item.offerVariantId,
      quantity: item.quantity,
      offer: item.offer,
      offerVariant: item.offerVariant,
    }));

    const order = await this.checkout.checkoutLines(userId, dto, lines, {
      clearCart: false,
    });

    const remaining = plan.items.length - now.length;
    await this.prisma.$transaction([
      this.prisma.purchasePlan.update({
        where: { id: plan.id },
        data: {
          // A plan with `LATER` lines left is not finished; it goes back to
          // draft so she can buy the rest when she is ready.
          status:
            remaining > 0 ? PurchasePlanStatus.DRAFT : PurchasePlanStatus.ORDERED,
          orderedAt: new Date(),
          orderId: order.order?.id ?? null,
        },
      }),
      this.prisma.purchasePlanItem.deleteMany({
        where: { id: { in: now.map((item) => item.id) } },
      }),
      this.prisma.room.update({
        where: { id: plan.roomId },
        data: {
          status: remaining > 0 ? RoomStatus.READY : RoomStatus.PURCHASED,
        },
      }),
    ]);

    await this.events.record(plan.roomId, RoomEventKind.PLAN_ORDERED, userId, {
      planId: plan.id,
      lines: now.length,
      staged: remaining,
    });

    void access;
    return order;
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /** The room's decisions, reduced to what the kernel reasons about. */
  private async readiness(roomId: string): Promise<RoomReadiness> {
    const decisions = await this.prisma.roomDecision.findMany({
      where: { roomId },
      orderBy: { position: 'asc' },
      include: {
        candidates: {
          include: {
            offer: {
              select: {
                status: true,
                isActive: true,
                stock: true,
                price: true,
                currency: true,
                priceSyp: true,
              },
            },
            offerVariant: { select: { stock: true, price: true } },
          },
        },
      },
    });

    const facts: DecisionFacts[] = await Promise.all(
      decisions.map(async (decision) => ({
        id: decision.id,
        title: decision.title,
        status: decision.status,
        pickCount: decision.pickCount,
        isRequired: decision.isRequired,
        isSuggested: decision.isSuggested,
        candidates: await Promise.all(
          decision.candidates.map(async (candidate): Promise<CandidateFacts> => {
            const stock = candidate.offerVariant?.stock ?? candidate.offer.stock;
            const purchasable =
              candidate.offer.status === OfferStatus.ACTIVE &&
              candidate.offer.isActive &&
              stock >= candidate.quantity;
            return {
              id: candidate.id,
              status: candidate.status,
              quantity: candidate.quantity,
              votesUp: candidate.votesUp,
              votesDown: candidate.votesDown,
              voteScore: candidate.voteScore,
              unitPriceSyp: purchasable
                ? await this.unitPriceSyp(candidate)
                : null,
              purchasable,
            };
          }),
        ),
      })),
    );

    return roomReadiness(facts);
  }

  /**
   * A line's unit price in SYP.
   *
   * Normalised so a room's budget — stated in SYP, like every other band in
   * this codebase — can be compared against a basket whose sellers may quote in
   * dollars, without an FX lookup at every comparison.
   */
  private async unitPriceSyp(line: {
    offer: {
      price: Prisma.Decimal;
      currency: Currency;
      priceSyp?: Prisma.Decimal | null;
    };
    offerVariant: { price: Prisma.Decimal | null } | null;
  }): Promise<number | null> {
    const variantPrice = line.offerVariant?.price;

    // The offer already carries its SYP-normalised price, refreshed whenever it
    // changes — so the common case costs no rate lookup at all. Only a variant
    // that overrides the offer's price has to be converted.
    if (!variantPrice && line.offer.priceSyp) return Number(line.offer.priceSyp);

    try {
      const syp = await this.rates.toSyp(
        Money.of(variantPrice ?? line.offer.price, line.offer.currency),
      );
      return Number(syp.toJSON().amount);
    } catch {
      // A missing rate is an unknown price, not a free one — `budgetFit` counts
      // it as unpriced and says so.
      return null;
    }
  }

  private async requireEditable(
    planId: string,
    userId: string,
  ): Promise<PurchasePlan> {
    const plan = await this.prisma.purchasePlan.findUnique({
      where: { id: planId },
    });
    if (!plan) throw new NotFoundException('Plan not found');
    await this.access.require(plan.roomId, userId, 'buy');

    if (plan.status !== PurchasePlanStatus.DRAFT) {
      throw new BadRequestException('This plan can no longer be edited');
    }
    return plan;
  }
}
