import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  Prisma,
  ReturnCostBearer,
  ReturnReason,
  ReturnResolution,
  ReturnStatus,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';

import { AuthUser } from '../../common/decorators/current-user.decorator';
import { Money, StatusActor, actorForRole } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { ValueBenefitService } from '../value/value-benefit.service';
import { DisputesService } from '../finance/disputes.service';
import {
  SellerOrderWorkflowService,
  actorOf,
} from '../orders/workflow/seller-order-workflow.service';
import { RefundBreakdown, ReturnRefundsService } from './return-refunds.service';
import {
  CLAIMING_RETURN_STATUSES,
  ReturnBlocker,
  blockerFor,
  defaultCostBearer,
  isResaleable,
  requiresEvidence,
  returnWindowClosesAt,
} from './return-policy';

type Tx = Prisma.TransactionClient;

/**
 * The return lifecycle, and who may move it.
 *
 * Same shape as the shipment table next door, for the same reason: without it,
 * a request could be refunded twice, or refunded after being rejected. Every
 * edge here is a real thing a real person does, and the actor list is the
 * business rule — a seller receives the goods, a customer withdraws her
 * request, and neither can do the other's part.
 */
const TRANSITIONS: Readonly<
  Record<ReturnStatus, ReadonlyArray<{ to: ReturnStatus; by: readonly StatusActor[] }>>
> = Object.freeze({
  [ReturnStatus.REQUESTED]: [
    { to: ReturnStatus.APPROVED, by: ['SELLER', 'ADMIN'] },
    { to: ReturnStatus.REJECTED, by: ['SELLER', 'ADMIN'] },
    { to: ReturnStatus.CANCELLED, by: ['CUSTOMER', 'ADMIN'] },
  ],
  [ReturnStatus.APPROVED]: [
    { to: ReturnStatus.IN_TRANSIT, by: ['SELLER', 'COURIER', 'ADMIN'] },
    // She may still change her mind while the goods are with her.
    { to: ReturnStatus.CANCELLED, by: ['CUSTOMER', 'ADMIN'] },
  ],
  [ReturnStatus.IN_TRANSIT]: [
    { to: ReturnStatus.RECEIVED, by: ['SELLER', 'ADMIN'] },
  ],
  [ReturnStatus.RECEIVED]: [
    // Paying the refund is the platform's act, not the seller's: Q60 puts
    // money in the hands of the accountant and the orders supervisor, and a
    // seller who could press it would be deciding her own liability. The
    // sweep below presses it for her, as SYSTEM, once she confirms receipt.
    { to: ReturnStatus.REFUNDED, by: ['ADMIN', 'SYSTEM'] },
    // An exchange moves no money, so the seller resolves it herself.
    { to: ReturnStatus.EXCHANGED, by: ['ADMIN', 'SELLER'] },
  ],
  // A rejected request is the end of this road — the customer's recourse is a
  // dispute (Q107), a different process with a different decider, not a retry
  // of the one that just said no.
  [ReturnStatus.REJECTED]: [],
  [ReturnStatus.REFUNDED]: [],
  [ReturnStatus.EXCHANGED]: [],
  [ReturnStatus.CANCELLED]: [],
});

export interface RequestedLine {
  readonly orderItemId: string;
  readonly quantity: number;
}

export interface CreateReturnInput {
  readonly sellerOrderId: string;
  readonly reason: ReturnReason;
  readonly reasonNote?: string;
  /** Photo URLs; required for the reasons that assert a fault. */
  readonly evidence?: readonly string[];
  readonly items: readonly RequestedLine[];
}

/**
 * Returns and exchanges.
 *
 * Q56 P1 sets the frame: seven days from receipt, the goods unused and in
 * their original condition, the seller bearing the return leg when the fault
 * is hers and the customer when she simply changed her mind, with opened
 * cosmetics and made-to-order pieces outside the change-of-mind window
 * altogether.
 *
 * Three decisions shape everything below.
 *
 * **A partial return does not move the parcel's status.** The eighteen
 * sub-order states (Q37) describe one parcel, so they can only describe a
 * return that takes the whole of it. When two of five items come back the
 * sub-order stays `DELIVERED` — because it was — and the request carries the
 * return's own state. Marking the whole parcel `RETURNED` for two items would
 * tell the seller, the customer and every report that a sale did not happen.
 *
 * **Escrow is held by the request, not by a flag.** `releaseDueEscrow` already
 * refuses to pay out a sub-order with a live return, so simply having an open
 * request freezes the money for exactly as long as the question is open. That
 * is why the statuses above are split into live, settled and released sets
 * rather than being read ad hoc at each call site.
 *
 * **The money is somebody else's job.** This service decides *whether* goods
 * come back and *who is at fault*; `ReturnRefundsService` decides what that is
 * worth and posts it. The split is what keeps a status machine from quietly
 * growing accounting rules.
 */
@Injectable()
export class ReturnsService {
  private readonly logger = new Logger(ReturnsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly refunds: ReturnRefundsService,
    private readonly disputes: DisputesService,
    private readonly workflow: SellerOrderWorkflowService,
    private readonly valueBenefits: ValueBenefitService,
  ) {}

  /**
   * Extra return days her standing buys her.
   *
   * Reem Value's `ENHANCED_RETURNS`. Read here rather than inside
   * `return-policy.ts` so that file stays a pure function of facts, and read on
   * both paths — the eligibility screen and the request itself — so the two can
   * never tell her different things about the same parcel.
   */
  private async extraWindowDays(userId: string | null): Promise<number> {
    if (!userId) return 0;
    const config = await this.valueBenefits.configFor(userId, 'extended-returns');
    const extra = config?.['extraDays'];
    return typeof extra === 'number' ? extra : 0;
  }

  // ── Before she asks ───────────────────────────────────────────────────

  /**
   * What this parcel can still send back, and why not where it cannot.
   *
   * Answered before the customer commits to anything. A form that accepts a
   * request and then refuses it teaches people to distrust the form; a screen
   * that greys out the excluded line and says «مستحضرات التجميل المفتوحة غير
   * قابلة للإرجاع» is the same rule, delivered while it is still useful.
   */
  async eligibility(user: AuthUser, sellerOrderId: string) {
    const sellerOrder = await this.loadParcel(sellerOrderId);
    this.assertParticipant(sellerOrder, user);

    const claimed = await this.claimedQuantities(sellerOrderId, this.prisma);
    const extraWindowDays = await this.extraWindowDays(sellerOrder.order.userId);
    const parcel = { deliveredAt: sellerOrder.deliveredAt, extraWindowDays };

    return {
      seller_order_id: sellerOrder.id,
      order_number: sellerOrder.number,
      delivered_at: sellerOrder.deliveredAt,
      window_closes_at: sellerOrder.deliveredAt
        ? returnWindowClosesAt(sellerOrder.deliveredAt, extraWindowDays)
        : null,
      // Surfaced so the screen can say *why* her window is longer than the
      // seven days the policy page states, rather than silently disagreeing
      // with it.
      extra_window_days: extraWindowDays,
      is_window_open: this.isWindowOpen(sellerOrder.deliveredAt, extraWindowDays),
      lines: sellerOrder.items.map((item) => {
        const facts = this.factsFor(item, claimed.get(item.id) ?? 0);
        const onFault = blockerFor(facts, parcel, ReturnReason.DEFECTIVE);
        const changedMind = blockerFor(facts, parcel, ReturnReason.CHANGED_MIND);
        return {
          order_item_id: item.id,
          title: item.titleSnapshot,
          variant: item.variantSnapshot,
          image: item.imageSnapshot,
          quantity_ordered: item.quantity,
          quantity_claimed: claimed.get(item.id) ?? 0,
          quantity_returnable: Math.max(
            0,
            item.quantity - (claimed.get(item.id) ?? 0),
          ),
          // The exclusions are exclusions from the *change-of-mind* return.
          // A made-to-order dress that arrives torn still comes back.
          on_fault: { allowed: onFault === null, blocker: onFault },
          change_of_mind: {
            allowed: changedMind === null,
            blocker: changedMind,
          },
        };
      }),
    };
  }

  // ── Asking ────────────────────────────────────────────────────────────

  /** Q56 P1 — the customer asks for some or all of a parcel back. */
  async request(user: AuthUser, input: CreateReturnInput) {
    if (input.items.length === 0) {
      throw new BadRequestException('Choose at least one item to return');
    }
    if (requiresEvidence(input.reason) && !(input.evidence?.length)) {
      // A claim of fault moves money away from a seller, so it arrives with
      // something a human can look at.
      throw new BadRequestException(
        'A photo is required when reporting a defect, damage or a wrong item',
      );
    }

    const sellerOrder = await this.loadParcel(input.sellerOrderId);
    this.assertCustomer(sellerOrder, user);

    const claimed = await this.claimedQuantities(sellerOrder.id, this.prisma);
    const parcel = {
      deliveredAt: sellerOrder.deliveredAt,
      extraWindowDays: await this.extraWindowDays(sellerOrder.order.userId),
    };
    const byId = new Map(sellerOrder.items.map((item) => [item.id, item]));

    for (const line of input.items) {
      const item = byId.get(line.orderItemId);
      if (!item) {
        throw new BadRequestException('That item is not part of this parcel');
      }
      if (line.quantity < 1) {
        throw new BadRequestException('Return at least one unit of each item');
      }

      const alreadyClaimed = claimed.get(item.id) ?? 0;
      const facts = this.factsFor(item, alreadyClaimed);
      const blocker = blockerFor(facts, parcel, input.reason);
      if (blocker) {
        throw new BadRequestException(this.explain(blocker, item.titleSnapshot));
      }
      if (alreadyClaimed + line.quantity > item.quantity) {
        throw new BadRequestException(
          `Only ${item.quantity - alreadyClaimed} of ${item.titleSnapshot} can still be returned`,
        );
      }
    }

    const isFullParcel = this.wouldCoverParcel(sellerOrder, claimed, input.items);

    const created = await this.prisma.$transaction(async (tx) => {
      const request = await tx.returnRequest.create({
        data: {
          number: await this.nextNumber(tx),
          sellerOrderId: sellerOrder.id,
          requestedById: user.id,
          reason: input.reason,
          reasonNote: input.reasonNote ?? null,
          // Q67 P1 «حسب الحالة» — proposed from the reason, overridable by
          // whoever approves and by an admin after that.
          shippingBorneBy: defaultCostBearer(
            input.reason,
            sellerOrder.fulfilmentMode,
          ),
          currency: sellerOrder.currency,
          evidence: input.evidence?.length
            ? ({ photos: [...input.evidence] } as Prisma.InputJsonValue)
            : undefined,
          windowClosesAt: returnWindowClosesAt(sellerOrder.deliveredAt!),
          items: {
            create: input.items.map((line) => ({
              orderItemId: line.orderItemId,
              quantity: line.quantity,
            })),
          },
        },
        include: { items: true },
      });

      if (isFullParcel) {
        await this.moveParcel(
          tx,
          sellerOrder,
          SellerOrderStatus.RETURN_REQUESTED,
          user,
          'Return requested',
          request.number,
        );
      } else {
        // The parcel's own status is untouched — it *was* delivered — so the
        // timeline carries the event instead.
        await this.note(
          tx,
          sellerOrder,
          user,
          'Return requested',
          `${request.number} — ${input.items.length} item(s)`,
        );
      }

      return request;
    });

    return this.detail(user, created.id);
  }

  // ── Deciding ──────────────────────────────────────────────────────────

  /**
   * The seller (or an admin) accepts the return.
   *
   * Accepting is also where the cost bearer is settled, because that is the
   * moment somebody with the facts is looking at it: the proposal came from
   * the stated reason, and Q67's «حسب الحالة» means a person gets the last
   * word.
   */
  async approve(
    user: AuthUser,
    returnId: string,
    options: {
      shippingBorneBy?: ReturnCostBearer;
      resolution?: ReturnResolution;
      note?: string;
    } = {},
  ) {
    const request = await this.loadRequest(returnId);
    this.assertSellerSide(request, user);
    this.assertTransition(request.status, ReturnStatus.APPROVED, user);

    await this.prisma.$transaction(async (tx) => {
      await tx.returnRequest.update({
        where: { id: returnId },
        data: {
          status: ReturnStatus.APPROVED,
          resolution: options.resolution ?? ReturnResolution.REFUND_TO_WALLET,
          shippingBorneBy:
            options.shippingBorneBy ?? request.shippingBorneBy ?? null,
          decidedById: user.id,
          decidedAt: new Date(),
        },
      });
      await this.note(
        tx,
        request.sellerOrder,
        user,
        'Return approved',
        options.note ?? `${request.number} accepted`,
      );
    });

    return this.detail(user, returnId);
  }

  /**
   * The seller refuses the return.
   *
   * A reason is mandatory. The customer's only recourse is a dispute (Q107),
   * and a dispute opened against «مرفوض» with no explanation wastes the three
   * working days somebody then has to spend finding out why.
   */
  async reject(user: AuthUser, returnId: string, reason: string) {
    const request = await this.loadRequest(returnId);
    this.assertSellerSide(request, user);
    this.assertTransition(request.status, ReturnStatus.REJECTED, user);

    await this.prisma.$transaction(async (tx) => {
      await tx.returnRequest.update({
        where: { id: returnId },
        data: {
          status: ReturnStatus.REJECTED,
          resolution: ReturnResolution.NONE,
          reasonNote: reason,
          decidedById: user.id,
          decidedAt: new Date(),
        },
      });

      // The goods never left her, so the parcel goes back to being delivered.
      if (request.sellerOrder.status === SellerOrderStatus.RETURN_REQUESTED) {
        await this.moveParcel(
          tx,
          request.sellerOrder,
          SellerOrderStatus.DELIVERED,
          user,
          'Return refused',
          reason,
        );
      } else {
        await this.note(tx, request.sellerOrder, user, 'Return refused', reason);
      }
    });

    return this.detail(user, returnId);
  }

  /** The customer withdraws a request she has not sent back yet. */
  async cancel(user: AuthUser, returnId: string) {
    const request = await this.loadRequest(returnId);
    this.assertCustomer(request.sellerOrder, user);
    this.assertTransition(request.status, ReturnStatus.CANCELLED, user);

    await this.prisma.$transaction(async (tx) => {
      await tx.returnRequest.update({
        where: { id: returnId },
        data: { status: ReturnStatus.CANCELLED },
      });
      if (request.sellerOrder.status === SellerOrderStatus.RETURN_REQUESTED) {
        await this.moveParcel(
          tx,
          request.sellerOrder,
          SellerOrderStatus.DELIVERED,
          user,
          'Return withdrawn',
          request.number,
        );
      } else {
        await this.note(
          tx,
          request.sellerOrder,
          user,
          'Return withdrawn',
          request.number,
        );
      }
    });

    return this.detail(user, returnId);
  }

  // ── The goods coming back ─────────────────────────────────────────────

  /** The parcel has been handed to whoever is carrying it back. */
  async markInTransit(user: AuthUser, returnId: string) {
    const request = await this.loadRequest(returnId);
    this.assertSellerSide(request, user);
    this.assertTransition(request.status, ReturnStatus.IN_TRANSIT, user);

    await this.prisma.$transaction(async (tx) => {
      await tx.returnRequest.update({
        where: { id: returnId },
        data: { status: ReturnStatus.IN_TRANSIT },
      });
      if (request.sellerOrder.status === SellerOrderStatus.RETURN_REQUESTED) {
        await this.moveParcel(
          tx,
          request.sellerOrder,
          SellerOrderStatus.RETURN_IN_TRANSIT,
          user,
          'Return on its way back',
          request.number,
        );
      } else {
        await this.note(
          tx,
          request.sellerOrder,
          user,
          'Return on its way back',
          request.number,
        );
      }
    });

    return this.detail(user, returnId);
  }

  /**
   * The seller has the goods in her hands again.
   *
   * Restocking is decided here rather than assumed: Q56 P1 requires the item
   * back «غير مستخدم وبحالته الأصلية», which a change of mind satisfies and a
   * defect does not. Putting a broken item back on the shelf sells it to the
   * next customer, so the reason decides the default and the person holding it
   * can still say otherwise.
   */
  async receive(
    user: AuthUser,
    returnId: string,
    options: { restock?: boolean; note?: string } = {},
  ) {
    const request = await this.loadRequest(returnId);
    this.assertSellerSide(request, user);
    this.assertTransition(request.status, ReturnStatus.RECEIVED, user);

    const restock = options.restock ?? isResaleable(request.reason);

    await this.prisma.$transaction(async (tx) => {
      await tx.returnRequest.update({
        where: { id: returnId },
        data: { status: ReturnStatus.RECEIVED },
      });

      if (restock) await this.restock(tx, request);

      if (request.sellerOrder.status === SellerOrderStatus.RETURN_IN_TRANSIT) {
        await this.moveParcel(
          tx,
          request.sellerOrder,
          SellerOrderStatus.RETURNED,
          user,
          'Return received',
          options.note ?? request.number,
        );
      } else {
        await this.note(
          tx,
          request.sellerOrder,
          user,
          'Return received',
          options.note ?? request.number,
        );
      }
    });

    return this.detail(user, returnId);
  }

  // ── Settling ──────────────────────────────────────────────────────────

  /**
   * Resolves a received return by exchange — the seller's own call, since no
   * money moves. Q37's «استبدال جاري»: the goods came back and the
   * replacement is being prepared. An exchange is the same sale, fulfilled
   * twice, which is why the commission and the escrow are left alone.
   */
  async exchange(user: AuthUser, returnId: string) {
    const request = await this.loadRequest(returnId);
    this.assertSellerSide(request, user);
    this.assertTransition(request.status, ReturnStatus.EXCHANGED, user);

    await this.prisma.$transaction(async (tx) => {
      await tx.returnRequest.update({
        where: { id: returnId },
        data: {
          status: ReturnStatus.EXCHANGED,
          resolution: ReturnResolution.EXCHANGE,
        },
      });

      if (request.sellerOrder.status === SellerOrderStatus.RETURNED) {
        await this.moveParcel(
          tx,
          request.sellerOrder,
          SellerOrderStatus.EXCHANGE_IN_PROGRESS,
          user,
          'Exchange in progress',
          request.number,
        );
      } else {
        await this.note(
          tx,
          request.sellerOrder,
          user,
          'Exchange in progress',
          request.number,
        );
      }
    });

    return this.detail(user, returnId);
  }

  /**
   * Pays the return out.
   *
   * The refund and every status it depends on move in one transaction, so the
   * money and the record of why it moved cannot come apart. The commission
   * row's reversal happens after that transaction commits — it opens its own,
   * and nesting them deadlocks on rows this one already holds.
   *
   * `user` is null when the sweep below runs it, which is the ordinary case:
   * a seller confirming she has the goods back is what makes the refund due,
   * and nobody should have to remember to press a second button for it.
   */
  async settle(user: AuthUser | null, returnId: string) {
    const request = await this.loadRequest(returnId);
    if (user) this.assertAdmin(user);
    this.assertTransition(request.status, ReturnStatus.REFUNDED, user);

    const breakdown = await this.prisma.$transaction(async (tx) => {
      const settled = await this.refunds.settle(returnId, user?.id ?? null, tx);

      await tx.returnRequest.update({
        where: { id: returnId },
        data: {
          status: ReturnStatus.REFUNDED,
          resolution: ReturnResolution.REFUND_TO_WALLET,
        },
      });

      // A whole parcel walks the last two states of Q37's list; a partial one
      // never left `DELIVERED`, because it never stopped being delivered.
      if (settled.isFullParcel) {
        const live = await tx.sellerOrder.findUniqueOrThrow({
          where: { id: request.sellerOrder.id },
          select: { status: true },
        });
        if (live.status !== SellerOrderStatus.REFUND_PENDING) {
          await this.moveParcel(
            tx,
            request.sellerOrder,
            SellerOrderStatus.REFUND_PENDING,
            user,
            'Refund pending',
            request.number,
          );
        }
        await this.moveParcel(
          tx,
          request.sellerOrder,
          SellerOrderStatus.REFUNDED,
          user,
          'Refunded',
          settled.customerRefund.toString(),
        );
      } else {
        await this.note(
          tx,
          request.sellerOrder,
          user,
          'Partial refund issued',
          `${request.number} — ${settled.customerRefund.toString()}`,
        );
      }

      return settled;
    });

    await this.refunds.reverseCommissionIfWhole(
      breakdown,
      request.sellerOrder.id,
      request.number,
    );

    return user ? this.detail(user, returnId) : null;
  }

  /**
   * Pays out every return whose goods are back and whose resolution is a
   * refund. Runs on a schedule, next to `releaseDueEscrow`.
   *
   * The seller confirms receipt; the platform pays. Splitting it this way is
   * what keeps Q60's separation intact — the person who owes the money is not
   * the person who authorises paying it — without leaving a customer waiting
   * for somebody to notice her return.
   */
  async settleDue(): Promise<{ settled: number; failed: number }> {
    const due = await this.prisma.returnRequest.findMany({
      where: {
        status: ReturnStatus.RECEIVED,
        resolution: {
          in: [
            ReturnResolution.NONE,
            ReturnResolution.REFUND_TO_WALLET,
            ReturnResolution.REFUND_TO_SOURCE,
          ],
        },
      },
      select: { id: true, number: true },
    });

    let settled = 0;
    let failed = 0;
    for (const request of due) {
      try {
        await this.settle(null, request.id);
        settled += 1;
      } catch (error) {
        // One return that cannot be paid must not stop the rest. It stays
        // RECEIVED and is picked up again on the next run, which is the right
        // behaviour for a transient failure and a loud one for a real bug.
        failed += 1;
        this.logger.error(
          `Could not settle return ${request.number}: ${(error as Error).message}`,
        );
      }
    }
    return { settled, failed };
  }

  /**
   * The replacement reached her — Q37's «تم الاستبدال».
   *
   * Lives here rather than in the seller's order screens because the exchange
   * only exists as the tail of a return, and a sub-order left in
   * `EXCHANGE_IN_PROGRESS` for ever would hold its escrow open with it.
   */
  async completeExchange(user: AuthUser, returnId: string) {
    const request = await this.loadRequest(returnId);
    this.assertSellerSide(request, user);

    if (request.status !== ReturnStatus.EXCHANGED) {
      throw new BadRequestException('This return was not resolved by exchange');
    }

    await this.prisma.$transaction(async (tx) => {
      await this.moveParcel(
        tx,
        request.sellerOrder,
        SellerOrderStatus.EXCHANGED,
        user,
        'Exchanged',
        request.number,
      );
    });

    return this.detail(user, returnId);
  }

  /**
   * Q107 — the customer disagrees with a refusal and escalates.
   *
   * Opening the dispute is deliberately hers to do rather than automatic on
   * rejection: a dispute freezes the seller's money and starts a three-day
   * clock for a human, and most refusals are accepted without one.
   */
  async escalate(user: AuthUser, returnId: string, subject: string) {
    const request = await this.loadRequest(returnId);
    this.assertCustomer(request.sellerOrder, user);

    if (
      request.status !== ReturnStatus.REJECTED &&
      request.status !== ReturnStatus.REFUNDED
    ) {
      throw new BadRequestException(
        'Escalate a return once it has been refused, or once the refund is in dispute',
      );
    }

    // One transaction for both halves. `DisputesService.open` takes a caller's
    // transaction for exactly this case, and the freeze it posts must not
    // survive a parcel that failed to move to DISPUTED — money held against a
    // dispute nobody can see is the worst of both outcomes.
    const dispute = await this.prisma.$transaction(async (tx) => {
      const opened = await this.disputes.open(
        {
          sellerOrderId: request.sellerOrder.id,
          openedById: user.id,
          subject: `${request.number}: ${subject}`,
        },
        tx,
      );

      if (request.sellerOrder.status === SellerOrderStatus.DELIVERED) {
        await this.moveParcel(
          tx,
          request.sellerOrder,
          SellerOrderStatus.DISPUTED,
          user,
          'Dispute opened',
          opened.number,
        );
      } else {
        await this.note(
          tx,
          request.sellerOrder,
          user,
          'Dispute opened',
          opened.number,
        );
      }

      return opened;
    });

    return { dispute_number: dispute.number, dispute_id: dispute.id };
  }

  // ── Refused at the door ───────────────────────────────────────────────

  /**
   * Q37 «رفض الاستلام» — the customer turned the parcel away.
   *
   * Nobody filled in a form for this one, but it is a return in every sense
   * that matters: goods come back, stock may return, and whatever was paid
   * has to be given back. Raising a request for it means the refused parcel
   * settles through exactly the same money path as every other return instead
   * of a second, lonelier one.
   */
  async openForRefusedDelivery(
    sellerOrderId: string,
    actorId: string,
  ): Promise<string> {
    const sellerOrder = await this.loadParcel(sellerOrderId);

    const existing = await this.prisma.returnRequest.findFirst({
      where: {
        sellerOrderId,
        status: { in: [...CLAIMING_RETURN_STATUSES] },
      },
      select: { id: true },
    });
    if (existing) return existing.id;

    const created = await this.prisma.$transaction(async (tx) =>
      tx.returnRequest.create({
        data: {
          number: await this.nextNumber(tx),
          sellerOrderId,
          requestedById: actorId,
          reason: ReturnReason.OTHER,
          reasonNote: 'رفض الاستلام عند الباب',
          // Already on its way back in the courier's hands.
          status: ReturnStatus.IN_TRANSIT,
          resolution: ReturnResolution.REFUND_TO_WALLET,
          // Q67 P1 answered «حسب الحالة» for exactly this case, so nobody is
          // charged by default and an admin decides.
          shippingBorneBy: null,
          currency: sellerOrder.currency,
          windowClosesAt: returnWindowClosesAt(
            sellerOrder.deliveredAt ?? new Date(),
          ),
          items: {
            create: sellerOrder.items.map((item) => ({
              orderItemId: item.id,
              quantity: item.quantity,
            })),
          },
        },
      }),
    );

    this.logger.log(
      `Opened ${created.number} for parcel ${sellerOrder.number} refused on delivery`,
    );
    return created.id;
  }

  // ── Reading ───────────────────────────────────────────────────────────

  async detail(user: AuthUser, returnId: string) {
    const request = await this.loadRequest(returnId);
    this.assertParticipant(request.sellerOrder, user);

    const quote = await this.safeQuote(returnId);
    return this.serialize(request, quote);
  }

  /** Her returns, newest first. */
  async listForCustomer(userId: string) {
    const requests = await this.prisma.returnRequest.findMany({
      where: { sellerOrder: { order: { userId } } },
      orderBy: { createdAt: 'desc' },
      include: this.detailInclude(),
    });
    return requests.map((request) => this.serialize(request, null));
  }

  /** The seller's queue: what is waiting on her first. */
  async listForSeller(sellerId: string, status?: ReturnStatus) {
    const requests = await this.prisma.returnRequest.findMany({
      where: {
        sellerOrder: { sellerId },
        ...(status ? { status } : {}),
      },
      orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
      include: this.detailInclude(),
    });
    return requests.map((request) => this.serialize(request, null));
  }

  // ── Internals ─────────────────────────────────────────────────────────

  private detailInclude() {
    return {
      items: { include: { orderItem: true } },
      sellerOrder: {
        select: {
          id: true,
          number: true,
          status: true,
          currency: true,
          sellerId: true,
          fulfilmentMode: true,
          order: { select: { id: true, number: true, userId: true } },
        },
      },
    } satisfies Prisma.ReturnRequestInclude;
  }

  private async loadRequest(returnId: string) {
    const request = await this.prisma.returnRequest.findUnique({
      where: { id: returnId },
      include: this.detailInclude(),
    });
    if (!request) throw new NotFoundException('Return request not found');
    return request;
  }

  private async loadParcel(sellerOrderId: string) {
    const sellerOrder = await this.prisma.sellerOrder.findUnique({
      where: { id: sellerOrderId },
      include: {
        items: {
          include: {
            // Both switches Q56 P1 cares about live on the *offer* — the
            // seller's listing — while the category they belong to hangs off
            // the product behind it.
            offer: {
              select: {
                acceptsReturns: true,
                isMadeToOrder: true,
                product: {
                  select: { category: { select: { returnsAllowed: true } } },
                },
              },
            },
            product: {
              select: { category: { select: { returnsAllowed: true } } },
            },
          },
        },
        order: { select: { id: true, number: true, userId: true } },
      },
    });
    if (!sellerOrder) throw new NotFoundException('Sub-order not found');
    return sellerOrder;
  }

  /**
   * The policy facts for one line.
   *
   * The offer is the seller's live listing and may since have been deleted
   * (`onDelete: SetNull`), so the product is read as a fallback. An offer that
   * has vanished cannot object to a return: the recorded sale is what matters,
   * and defaulting to "returnable" errs towards the customer, which is the
   * right direction to err when the evidence is missing.
   */
  private factsFor(
    item: {
      quantity: number;
      offer: {
        acceptsReturns: boolean;
        isMadeToOrder: boolean;
        product: { category: { returnsAllowed: boolean } };
      } | null;
      product: { category: { returnsAllowed: boolean } } | null;
    },
    quantityClaimed: number,
  ) {
    const product = item.offer?.product ?? item.product;
    return {
      quantityOrdered: item.quantity,
      quantityClaimed,
      categoryAllowsReturns: product?.category.returnsAllowed ?? true,
      offerAcceptsReturns: item.offer?.acceptsReturns ?? true,
      isMadeToOrder: item.offer?.isMadeToOrder ?? false,
    };
  }

  /**
   * How many units of each line are already spoken for.
   *
   * Live and settled requests both count; rejected and withdrawn ones release
   * their claim. Without this, a customer could open five requests for the
   * same single item and be refunded five times.
   */
  private async claimedQuantities(
    sellerOrderId: string,
    db: Tx | PrismaService,
  ): Promise<Map<string, number>> {
    const rows = await db.returnItem.groupBy({
      by: ['orderItemId'],
      where: {
        request: {
          sellerOrderId,
          status: { in: [...CLAIMING_RETURN_STATUSES] },
        },
      },
      _sum: { quantity: true },
    });
    return new Map(rows.map((row) => [row.orderItemId, row._sum.quantity ?? 0]));
  }

  /** Whether this request, on top of what is already claimed, takes it all. */
  private wouldCoverParcel(
    sellerOrder: { items: Array<{ id: string; quantity: number }> },
    claimed: Map<string, number>,
    requested: readonly RequestedLine[],
  ): boolean {
    const total = new Map(claimed);
    for (const line of requested) {
      total.set(
        line.orderItemId,
        (total.get(line.orderItemId) ?? 0) + line.quantity,
      );
    }
    return sellerOrder.items.every(
      (item) => (total.get(item.id) ?? 0) >= item.quantity,
    );
  }

  /**
   * Puts the units back on the offer they came off, variant included.
   *
   * Deliberately *not* `SellerOrderWorkflowService.restock`, and the
   * difference is the whole point: that one undoes a checkout for a parcel
   * that was never sold, so it also reverses `Product.ordersCount` and the
   * flash-sale units. This parcel **was** sold — delivered, then sent back —
   * and erasing it from the demand history would hide a return rather than
   * record it. Two different events, two different reversals.
   *
   * It also runs per returned *line*, not per parcel: a partial return puts
   * back only what came back.
   */
  private async restock(
    tx: Tx,
    request: {
      items: Array<{ quantity: number; orderItem: { offerId: string | null; variantId: string | null } }>;
    },
  ): Promise<void> {
    for (const line of request.items) {
      const { offerId, variantId } = line.orderItem;
      if (!offerId) continue;
      await tx.sellerOffer.update({
        where: { id: offerId },
        data: { stock: { increment: line.quantity } },
      });
      if (variantId) {
        await tx.sellerOfferVariant.updateMany({
          where: { offerId, variantId },
          data: { stock: { increment: line.quantity } },
        });
      }
    }
  }

  /**
   * Moves the parcel and records why, then re-derives the parent order.
   *
   * Every status change goes through `assertTransition`, including the ones
   * this service is certain about — the table is the authority on the
   * lifecycle, and a service that skips it when it "knows better" is how the
   * table stops being true.
   */
  private async moveParcel(
    tx: Tx,
    sellerOrder: { id: string },
    to: SellerOrderStatus,
    user: AuthUser | null,
    title: string,
    description?: string,
  ): Promise<void> {
    await this.workflow.move(tx, sellerOrder.id, to, actorOf(user), {
      title,
      description,
    });
  }

  /** A timeline entry that changes no status — the partial-return case. */
  private async note(
    tx: Tx,
    sellerOrder: { id: string },
    user: AuthUser | null,
    title: string,
    description?: string,
  ): Promise<void> {
    await this.workflow.note(
      tx,
      sellerOrder.id,
      actorOf(user),
      title,
      description,
    );
  }

  /** Who is acting. No principal means the scheduled sweep — that is SYSTEM. */
  private actorOf(user: AuthUser | null): StatusActor {
    return user ? actorForRole(user.role) : 'SYSTEM';
  }

  private assertTransition(
    from: ReturnStatus,
    to: ReturnStatus,
    user: AuthUser | null,
  ): void {
    const actor = this.actorOf(user);
    const allowed = TRANSITIONS[from].some(
      (edge) => edge.to === to && (edge.by.includes(actor) || actor === 'ADMIN'),
    );
    if (!allowed) {
      throw new BadRequestException(
        `A return cannot go from ${from} to ${to} as ${actor}`,
      );
    }
  }

  private isWindowOpen(
    deliveredAt: Date | null,
    extraWindowDays = 0,
    now = new Date(),
  ): boolean {
    return (
      deliveredAt !== null &&
      now <= returnWindowClosesAt(deliveredAt, extraWindowDays)
    );
  }

  private assertCustomer(
    sellerOrder: { order: { userId: string | null } },
    user: AuthUser,
  ): void {
    if (sellerOrder.order.userId !== user.id && !this.isAdmin(user)) {
      throw new ForbiddenException('This order is not yours');
    }
  }

  private assertSellerSide(
    request: { sellerOrder: { sellerId: string } },
    user: AuthUser,
  ): void {
    if (request.sellerOrder.sellerId !== user.id && !this.isAdmin(user)) {
      throw new ForbiddenException('This return is not on your parcel');
    }
  }

  /**
   * Either side of the sale may read it. A seller seeing her own parcel's
   * return is not the Q44 privacy problem — that one is about the *other*
   * sellers in the same basket, which a return never spans.
   */
  private assertParticipant(
    sellerOrder: { sellerId: string; order: { userId: string | null } },
    user: AuthUser,
  ): void {
    if (
      sellerOrder.order.userId === user.id ||
      sellerOrder.sellerId === user.id ||
      this.isAdmin(user)
    ) {
      return;
    }
    throw new ForbiddenException('This return is not yours');
  }

  /** Q60/Q62 — paying money out is the platform's side of the house. */
  private assertAdmin(user: AuthUser): void {
    if (!this.isAdmin(user)) {
      throw new ForbiddenException('Only the platform can settle a refund');
    }
  }

  private isAdmin(user: AuthUser): boolean {
    return (
      user.role === UserRole.SUPER_ADMIN ||
      user.role === UserRole.OPERATIONS_ADMIN ||
      user.role === UserRole.SUPPORT_ADMIN ||
      user.role === UserRole.FINANCE_ADMIN ||
      user.role === UserRole.SUPPORT ||
      user.role === UserRole.ADMIN
    );
  }

  /**
   * The refund quote, or nothing.
   *
   * A settled return keeps its own figure and a quote for it would be a second
   * opinion about a fact; a request on a parcel whose money never moved has no
   * quote to give. Neither is a reason to fail the read.
   */
  private async safeQuote(returnId: string): Promise<RefundBreakdown | null> {
    try {
      return await this.refunds.quote(returnId);
    } catch (error) {
      this.logger.debug(
        `No refund quote for return ${returnId}: ${(error as Error).message}`,
      );
      return null;
    }
  }

  private explain(blocker: ReturnBlocker, title: string): string {
    switch (blocker) {
      case ReturnBlocker.NotDelivered:
        return 'This parcel has not been delivered yet';
      case ReturnBlocker.WindowClosed:
        return 'The seven-day return window has closed';
      case ReturnBlocker.MadeToOrder:
        return `${title} was made to order and cannot be returned by choice`;
      case ReturnBlocker.CategoryExcluded:
        return `${title} is in a category excluded from change-of-mind returns`;
      case ReturnBlocker.OfferExcluded:
        return `${title} is not accepted back by its seller`;
      case ReturnBlocker.FullyReturned:
        return `${title} has already been returned in full`;
    }
  }

  private serialize(
    request: Prisma.ReturnRequestGetPayload<{
      include: {
        items: { include: { orderItem: true } };
        sellerOrder: {
          select: {
            id: true;
            number: true;
            status: true;
            currency: true;
            sellerId: true;
            fulfilmentMode: true;
            order: { select: { id: true; number: true; userId: true } };
          };
        };
      };
    }>,
    quote: RefundBreakdown | null,
  ) {
    const currency = request.currency;
    return {
      id: request.id,
      number: request.number,
      status: request.status,
      resolution: request.resolution,
      reason: request.reason,
      reason_note: request.reasonNote,
      shipping_borne_by: request.shippingBorneBy,
      evidence: (request.evidence as { photos?: string[] } | null)?.photos ?? [],
      window_closes_at: request.windowClosesAt,
      decided_at: request.decidedAt,
      created_at: request.createdAt,
      order: {
        id: request.sellerOrder.order.id,
        number: request.sellerOrder.order.number,
        seller_order_id: request.sellerOrder.id,
        seller_order_number: request.sellerOrder.number,
        status: request.sellerOrder.status,
      },
      items: request.items.map((item) => ({
        order_item_id: item.orderItemId,
        title: item.orderItem.titleSnapshot,
        variant: item.orderItem.variantSnapshot,
        image: item.orderItem.imageSnapshot,
        quantity: item.quantity,
      })),
      // The settled figure once there is one, the live quote before that. Both
      // are labelled, so nothing reads a proposal as a promise.
      refund: request.refundAmount
        ? {
            settled: true,
            amount: Money.of(request.refundAmount, currency).toJSON(),
          }
        : quote
          ? {
              settled: false,
              amount: quote.customerRefund.toJSON(),
              goods: quote.goods.toJSON(),
              return_shipping_fee: quote.returnShippingFee.toJSON(),
              borne_by: quote.borneBy,
              is_full_parcel: quote.isFullParcel,
            }
          : null,
    };
  }

  /** `RET-000123` — short enough to read out in a support call. */
  private async nextNumber(tx: Tx): Promise<string> {
    const count = await tx.returnRequest.count();
    return `RET-${String(count + 1).padStart(6, '0')}`;
  }
}
