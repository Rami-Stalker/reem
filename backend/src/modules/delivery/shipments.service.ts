import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  Courier,
  Currency,
  DeliveryFailureReason,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  PaymentMethodType,
  Prisma,
  SellerOrderStatus,
  Shipment,
  ShipmentStatus,
} from '@prisma/client';
import { randomBytes } from 'node:crypto';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { OrderEventCopy } from '../../common/orders/order-event-copy';
import { CommissionsService } from '../commissions/commissions.service';
import { CustomerRefundsService } from '../finance/customer-refunds.service';
import { CodTrustService } from '../cod-trust/cod-trust.service';
import {
  SYSTEM_ACTOR,
  SellerOrderWorkflowService,
  WorkflowActor,
} from '../orders/workflow/seller-order-workflow.service';

type Tx = Prisma.TransactionClient;

/**
 * Which statuses a shipment may move to from each one.
 *
 * A delivery is the one place where the physical world and the ledger meet, so
 * the order of events is not advisory. Without this, a shipment could be
 * marked delivered twice — and since delivery is what books cash-on-delivery
 * money into the courier's account, that would invent money.
 */
const TRANSITIONS: Readonly<Record<ShipmentStatus, readonly ShipmentStatus[]>> =
  Object.freeze({
    [ShipmentStatus.CREATED]: [ShipmentStatus.ASSIGNED, ShipmentStatus.CANCELLED],
    [ShipmentStatus.ASSIGNED]: [
      ShipmentStatus.PICKED_UP,
      ShipmentStatus.CANCELLED,
    ],
    [ShipmentStatus.PICKED_UP]: [
      ShipmentStatus.IN_TRANSIT,
      ShipmentStatus.OUT_FOR_DELIVERY,
      ShipmentStatus.RETURNING,
    ],
    [ShipmentStatus.IN_TRANSIT]: [
      ShipmentStatus.OUT_FOR_DELIVERY,
      ShipmentStatus.RETURNING,
    ],
    [ShipmentStatus.OUT_FOR_DELIVERY]: [
      ShipmentStatus.DELIVERED,
      ShipmentStatus.FAILED,
    ],
    // Q37 P2 — «فشل التسليم: المندوب حاول ولم يتمكن». A failed attempt is not
    // the end: the courier may try again or take the parcel back.
    [ShipmentStatus.FAILED]: [
      ShipmentStatus.OUT_FOR_DELIVERY,
      ShipmentStatus.RETURNING,
    ],
    [ShipmentStatus.DELIVERED]: [],
    [ShipmentStatus.RETURNING]: [ShipmentStatus.RETURNED],
    [ShipmentStatus.RETURNED]: [],
    [ShipmentStatus.CANCELLED]: [],
  });

/** The sub-order move a shipment move implies. */
interface ParcelSync {
  readonly to: SellerOrderStatus;
  readonly title: string;
  readonly description?: string | null;
  /** Statuses the parcel must already be in for this move to make sense. */
  readonly require?: readonly SellerOrderStatus[];
  readonly requireMessage?: string;
}

export interface DeliverInput {
  readonly shipmentId: string;
  readonly courierUserId: string;
  /** What the courier actually collected (Q55 — «يسجّل مبلغ التحصيل»). */
  readonly collected?: string;
  /** Q55 — «يرفع صورة إثبات تسليم». */
  readonly proofImageUrl?: string;
  readonly recipientNote?: string;
  readonly latitude?: number;
  readonly longitude?: number;
}

/**
 * The shipment lifecycle, and the courier-facing actions Q55 lists.
 *
 * Delivery is where cash-on-delivery money enters the books. The client's
 * couriers are their own staff (Q57 P1), collecting cash at the door and
 * settling daily (Q56) — so between the doorstep and that settlement the money
 * is a platform asset sitting in a named person's pocket. Marking a shipment
 * delivered with a collected amount is what records that, and it happens in
 * the same transaction as the status change so the two can never disagree.
 */
@Injectable()
export class ShipmentsService {
  private readonly logger = new Logger(ShipmentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly commissions: CommissionsService,
    private readonly workflow: SellerOrderWorkflowService,
    private readonly refunds: CustomerRefundsService,
    private readonly codTrust: CodTrustService,
  ) {}

  // ── Creation and assignment ───────────────────────────────────────────

  /**
   * Creates the shipment for a sub-order once the seller has it ready.
   *
   * The COD amount is the sub-order's own total, not the parent order's: the
   * customer pays shipping once (Q65 P1), but that fee is allocated across the
   * parcels, so each is collected against its own share of what she owes.
   */
  async createForSellerOrder(
    sellerOrderId: string,
    options: { zoneId?: string; isExpress?: boolean; scheduledFor?: Date } = {},
    tx?: Tx,
  ): Promise<Shipment> {
    const db = tx ?? this.prisma;

    const sellerOrder = await db.sellerOrder.findUnique({
      where: { id: sellerOrderId },
      select: {
        id: true,
        currency: true,
        itemsSubtotal: true,
        discountTotal: true,
        shippingCost: true,
        shipment: { select: { id: true } },
        order: {
          select: {
            privacyMaskEnabled: true,
            payment: { select: { method: true } },
          },
        },
      },
    });
    if (!sellerOrder) throw new NotFoundException('Sub-order not found');
    if (sellerOrder.shipment) {
      throw new BadRequestException('This sub-order already has a shipment');
    }

    const method = sellerOrder.order.payment?.method;
    const isCod =
      method === PaymentMethodType.COD ||
      method === PaymentMethodType.COURIER_COLLECT;

    // Only a cash-on-delivery parcel carries money to collect. A prepaid one
    // is a delivery, not a collection.
    //
    // The figure is exactly what this parcel is worth to the customer: her
    // goods after any discount, plus the delivery fee she was charged for it.
    // Settlement books that same figure into the courier's in-transit account,
    // so the daily settlement (Q56) still nets to zero for an honest courier —
    // it simply nets against the whole amount now rather than against the
    // goods alone, which is what left the delivery fee uncollected and unbooked.
    const codAmount = isCod
      ? Money.of(sellerOrder.itemsSubtotal, sellerOrder.currency)
          .minus(Money.of(sellerOrder.discountTotal, sellerOrder.currency))
          .plus(Money.of(sellerOrder.shippingCost, sellerOrder.currency))
      : null;

    return db.shipment.create({
      data: {
        trackingCode: this.trackingCode(),
        sellerOrderId,
        zoneId: options.zoneId ?? null,
        currency: sellerOrder.currency,
        codAmount: codAmount?.toPrisma() ?? null,
        isExpress: options.isExpress ?? false,
        scheduledFor: options.scheduledFor ?? null,
      },
    });
  }

  /** Assigns a courier. Q55's «طلباته لليوم» is built from this. */
  async assign(shipmentId: string, courierId: string, actorId: string) {
    const courier = await this.prisma.courier.findUnique({
      where: { id: courierId },
    });
    if (!courier || !courier.isActive) {
      throw new NotFoundException('Courier not found or inactive');
    }

    return this.transition(shipmentId, ShipmentStatus.ASSIGNED, {
      actorId,
      data: { courier: { connect: { id: courierId } } },
      note: OrderEventCopy.assignedToCourier(courier.displayName),
    });
  }
  /**
   * Applies what a delivery company said about a parcel.
   *
   * The one door an external carrier's status comes through. It is deliberately
   * the *same* implementation the courier screens use — `deliverCore` and
   * `failCore` — so a delivery reported by webhook settles commission, pays the
   * order down and closes the trust loop exactly as a rider's tap does, and a
   * refusal reported by webhook restocks the goods and gives the money back.
   *
   * The caller (the dispatch orchestrator) has already verified the callback
   * and decided the event is newer than what we hold; this method's job is the
   * consequences, not the authorisation.
   */
  async applyCarrierStatus(input: {
    shipmentId: string;
    status: ShipmentStatus;
    note?: string | null;
    at?: Date | null;
    failureReason?: DeliveryFailureReason | null;
    collectedAmount?: string | null;
  }): Promise<Shipment | null> {
    const { shipmentId, status } = input;
    const note = input.note ?? undefined;

    switch (status) {
      case ShipmentStatus.DELIVERED:
        return this.deliverCore({
          shipmentId,
          collected: input.collectedAmount ?? undefined,
          recipientNote: note,
          at: input.at ?? undefined,
        });

      case ShipmentStatus.FAILED:
        return this.failCore({
          shipmentId,
          reason: input.failureReason ?? DeliveryFailureReason.OTHER,
          note,
        });

      case ShipmentStatus.ASSIGNED:
        return this.transition(shipmentId, ShipmentStatus.ASSIGNED, { note });

      case ShipmentStatus.PICKED_UP:
        return this.transition(shipmentId, ShipmentStatus.PICKED_UP, {
          note,
          actor: this.carrierActor(),
          data: { pickedUpAt: input.at ?? new Date() },
          parcel: {
            to: SellerOrderStatus.HANDED_TO_COURIER,
            title: OrderEventCopy.collectedByCarrier,
            description: note ?? OrderEventCopy.carrierHasParcel,
            require: [SellerOrderStatus.READY_TO_SHIP],
            requireMessage:
              'The carrier reported a pick-up for a parcel the seller has not marked ready',
          },
        });

      case ShipmentStatus.IN_TRANSIT:
        return this.transition(shipmentId, ShipmentStatus.IN_TRANSIT, {
          note,
          actor: this.carrierActor(),
          parcel: {
            to: SellerOrderStatus.IN_TRANSIT,
            title: OrderEventCopy.onItsWay,
            description: note ?? OrderEventCopy.carrierHasParcel,
          },
        });

      case ShipmentStatus.OUT_FOR_DELIVERY:
        return this.transition(shipmentId, ShipmentStatus.OUT_FOR_DELIVERY, {
          note,
          actor: this.carrierActor(),
          parcel: {
            to: SellerOrderStatus.IN_TRANSIT,
            title: OrderEventCopy.outForDelivery,
            description: note ?? OrderEventCopy.outForDeliveryToday,
          },
        });

      case ShipmentStatus.RETURNING:
        return this.transition(shipmentId, ShipmentStatus.RETURNING, {
          note,
          actor: this.carrierActor(),
          parcel: {
            to: SellerOrderStatus.RETURN_IN_TRANSIT,
            title: OrderEventCopy.comingBack,
            description: note ?? OrderEventCopy.carrierReturning,
          },
        });

      case ShipmentStatus.RETURNED:
        return this.transition(shipmentId, ShipmentStatus.RETURNED, {
          note,
          actor: this.carrierActor(),
          parcel: {
            to: SellerOrderStatus.RETURNED,
            title: OrderEventCopy.backWithSeller,
            description: note ?? OrderEventCopy.carrierReturned,
          },
        });

      case ShipmentStatus.CANCELLED:
        return this.transition(shipmentId, ShipmentStatus.CANCELLED, { note });

      default:
        // CREATED, and anything a future enum adds: nothing to do rather than
        // an invented move. The status is still recorded on the dispatch row.
        return null;
    }
  }

  // ── Courier actions (Q55) ─────────────────────────────────────────────

  /** Q55 — «يشوف طلباته لليوم». */
  async assignmentsFor(courierUserId: string, date = new Date()) {
    const courier = await this.requireCourier(courierUserId);
    const start = new Date(date);
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(end.getDate() + 1);

    const assignments = await this.prisma.shipment.findMany({
      where: {
        courierId: courier.id,
        OR: [
          // Anything still in flight, whenever it was assigned…
          {
            status: {
              in: [
                ShipmentStatus.ASSIGNED,
                ShipmentStatus.PICKED_UP,
                ShipmentStatus.IN_TRANSIT,
                ShipmentStatus.OUT_FOR_DELIVERY,
                ShipmentStatus.FAILED,
              ],
            },
          },
          // …plus what they closed today, so the day's work is visible.
          { deliveredAt: { gte: start, lt: end } },
        ],
      },
      include: {
        sellerOrder: {
          select: {
            number: true,
            order: {
              select: {
                recipientName: true,
                recipientPhone: true,
                governorate: true,
                city: true,
                addressLine: true,
                landmark: true,
                deliveryInstructions: true,
                privacyMaskEnabled: true,
              },
            },
          },
        },
      },
      orderBy: [{ isExpress: 'desc' }, { createdAt: 'asc' }],
    });

    return assignments.map((parcel) => this.serializeAssignment(parcel));
  }

  /**
   * The courier's view of a parcel (Q55).
   *
   * Shaped deliberately rather than returned raw: the platform's JSON contract
   * is snake_case, and a raw Prisma row also carries `privacyMaskEnabled`,
   * which is an internal decision about what the *seller* may see and no
   * business of the delivery app.
   *
   * The recipient's name and phone *are* included. Q44's masking hides her
   * from the seller, not from the person who has to knock on her door and ring
   * ahead (Q55 «يتصل بالزبونة بضغطة»).
   */
  private serializeAssignment(
    parcel: Prisma.ShipmentGetPayload<{
      include: {
        sellerOrder: {
          select: {
            number: true;
            order: {
              select: {
                recipientName: true;
                recipientPhone: true;
                governorate: true;
                city: true;
                addressLine: true;
                landmark: true;
                deliveryInstructions: true;
                privacyMaskEnabled: true;
              };
            };
          };
        };
      };
    }>,
  ) {
    const order = parcel.sellerOrder.order;
    return {
      id: parcel.id,
      tracking_code: parcel.trackingCode,
      order_number: parcel.sellerOrder.number,
      status: parcel.status.toLowerCase(),

      // What to collect at the door. Null on a prepaid parcel — a courier who
      // is shown an amount will try to collect it.
      cod_amount: parcel.codAmount
        ? Money.of(parcel.codAmount, parcel.currency).toJSON()
        : null,
      collected_amount: parcel.collectedAmount
        ? Money.of(parcel.collectedAmount, parcel.currency).toJSON()
        : null,

      recipient: {
        name: order.recipientName,
        phone: parcel.maskedPhone ?? order.recipientPhone,
      },
      address: {
        governorate: order.governorate,
        city: order.city,
        address_line: order.addressLine,
        landmark: order.landmark,
      },
      /// Q55 «يرى ملاحظات التوصيل مثل اتصل قبل الوصول».
      delivery_instructions: order.deliveryInstructions,

      is_express: parcel.isExpress,
      scheduled_for: parcel.scheduledFor,
      attempt_count: parcel.attemptCount,
      failure_reason: parcel.failureReason,
      delivered_at: parcel.deliveredAt,
    };
  }

  /**
   * Q55 «أخرى» — «يؤكد استلام الطلب من البائع».
   *
   * Refuses a parcel the seller has not marked ready. The two lifecycles —
   * the shipment's and the sub-order's — describe the same physical box, and
   * a courier able to collect a parcel nobody has packed would put an order
   * "on its way" while it was still being made.
   */
  pickUp(shipmentId: string, courierUserId: string) {
    return this.courierTransition(
      shipmentId,
      courierUserId,
      ShipmentStatus.PICKED_UP,
      {
        data: { pickedUpAt: new Date() },
        parcel: {
          to: SellerOrderStatus.HANDED_TO_COURIER,
          title: OrderEventCopy.collectedByCourier,
          description: OrderEventCopy.courierHasParcel,
          require: [SellerOrderStatus.READY_TO_SHIP],
          requireMessage:
            'This parcel is not ready yet — the seller has to mark it ready before it can be collected',
        },
      },
    );
  }

  outForDelivery(
    shipmentId: string,
    courierUserId: string,
    position?: { latitude?: number; longitude?: number },
  ) {
    return this.courierTransition(
      shipmentId,
      courierUserId,
      ShipmentStatus.OUT_FOR_DELIVERY,
      {
        position,
        parcel: {
          to: SellerOrderStatus.IN_TRANSIT,
          title: OrderEventCopy.outForDelivery,
          description: OrderEventCopy.onTheWayToCustomer,
        },
      },
    );
  }

  /**
   * Marks the parcel delivered and records what the courier collected.
   *
   * Delivery is what makes the sale revenue-bearing (Q37), so settlement runs
   * from here rather than waiting for an admin — and settlement is the single
   * place the order's gross is booked, routing cash-on-delivery money into
   * this courier's in-transit account. Nothing is posted to the ledger inside
   * the transaction below: two postings for one collection would invent money.
   */
  async deliver(input: DeliverInput): Promise<Shipment> {
    const courier = await this.requireCourier(input.courierUserId);
    return this.deliverCore({ ...input, courier });
  }

  /**
   * A delivery, whoever recorded it.
   *
   * The courier screens and a carrier's callback are two ways of learning the
   * same fact, and everything that follows from it — the sub-order landing,
   * cash paying the order down, commission settling, the trust engine closing
   * its loop — must not depend on which one arrived. `courier` is present when
   * one of our own riders tapped the button (and the parcel must be his);
   * absent when a delivery company told us.
   */
  private async deliverCore(
    input: Omit<DeliverInput, 'courierUserId'> & {
      courierUserId?: string;
      courier?: Courier;
      at?: Date;
    },
  ): Promise<Shipment> {
    const courier = input.courier;

    const delivered = await this.prisma.$transaction(async (tx) => {
      const parcel = courier
        ? await this.loadForCourier(tx, input.shipmentId, courier)
        : await this.loadShipment(tx, input.shipmentId);
      this.assertTransition(parcel.status, ShipmentStatus.DELIVERED);

      const currency = parcel.currency;
      const expected = parcel.codAmount
        ? Money.of(parcel.codAmount, currency)
        : Money.zero(currency);

      // No explicit figure means the courier collected exactly what was due;
      // a prepaid parcel is due nothing.
      const collected =
        input.collected === undefined
          ? expected
          : Money.of(input.collected, currency);

      if (collected.isNegative()) {
        throw new BadRequestException('Collected cash cannot be negative');
      }
      if (collected.greaterThan(expected)) {
        throw new BadRequestException(
          `Collected ${collected.toString()} exceeds the ${expected.toString()} due on this parcel`,
        );
      }

      const now = input.at ?? new Date();
      const updated = await tx.shipment.update({
        where: { id: parcel.id },
        data: {
          status: ShipmentStatus.DELIVERED,
          deliveredAt: now,
          collectedAmount: collected.toPrisma(),
          proofImageUrl: input.proofImageUrl ?? parcel.proofImageUrl,
          recipientNote: input.recipientNote ?? parcel.recipientNote,
          failureReason: null,
          failureNote: null,
        },
      });

      await tx.shipmentEvent.create({
        data: {
          shipmentId: parcel.id,
          status: ShipmentStatus.DELIVERED,
          note: input.recipientNote ?? null,
          latitude: input.latitude ?? null,
          longitude: input.longitude ?? null,
          actorId: input.courierUserId ?? null,
        },
      });

      // The sub-order lands with it. This is the moment the whole platform has
      // been waiting for: `deliveredAt` opens the seven-day return window
      // (Q56), starts the escrow clock (Q24), unlocks the customer's review
      // (Q31) and lets loyalty points accrue when that window closes (Q43).
      const sellerOrder = await tx.sellerOrder.findUniqueOrThrow({
        where: { id: parcel.sellerOrderId },
        select: { orderId: true },
      });
      await this.syncParcel(tx, parcel.sellerOrderId, this.carrierActor(input.courierUserId), {
        to: SellerOrderStatus.DELIVERED,
        title: OrderEventCopy.delivered,
        description: input.recipientNote ?? 'Handed to the customer',
      });

      // Cash at the door pays the order down. A basket split across sellers
      // is only paid once every parcel has been collected, which is why this
      // adds to `capturedAmount` rather than declaring the payment settled.
      if (!collected.isZero()) {
        await this.workflow.recordCollection(
          tx,
          sellerOrder.orderId,
          collected.toPrisma(),
        );
      }

      return updated;
    });

    // Settled outside the transaction on purpose: a ledger hiccup must not
    // roll back a delivery that physically happened. `settleSellerOrder` is
    // idempotent, so the nightly escrow sweep retries anything that fails.
    try {
      await this.commissions.settleSellerOrder(delivered.sellerOrderId);
    } catch (error) {
      this.logger.error(
        `Delivered ${delivered.trackingCode} but settlement failed — the escrow ` +
          `sweep will retry: ${(error as Error).message}`,
      );
    }

    // Closes the loop the trust engine opened at checkout: the parcel it
    // scored is now a fact. Best-effort, like everything else past the
    // transaction — a model that learns a day late is fine, a delivery that
    // fails to record is not.
    await this.codTrust.observeBySellerOrder(delivered.sellerOrderId, 'delivered');

    return delivered;
  }

  /** Q55 — «يسجّل سبب فشل التسليم». */
  async failAttempt(
    shipmentId: string,
    courierUserId: string,
    reason: DeliveryFailureReason,
    note?: string,
  ): Promise<Shipment> {
    const courier = await this.requireCourier(courierUserId);
    return this.failCore({ shipmentId, courierUserId, courier, reason, note });
  }

  /**
   * A failed attempt, whoever recorded it — a rider on the doorstep or a
   * carrier's callback. Everything that follows a refusal (restock, the
   * customer's money back, the trust engine's observation) is here so it
   * cannot depend on which one arrived.
   */
  private async failCore(input: {
    shipmentId: string;
    reason: DeliveryFailureReason;
    note?: string;
    courier?: Courier;
    courierUserId?: string;
  }): Promise<Shipment> {
    const { shipmentId, reason, note, courier, courierUserId } = input;

    const result = await this.prisma.$transaction(async (tx) => {
      const shipment = courier
        ? await this.loadForCourier(tx, shipmentId, courier)
        : await this.loadShipment(tx, shipmentId);
      this.assertTransition(shipment.status, ShipmentStatus.FAILED);

      const updated = await tx.shipment.update({
        where: { id: shipment.id },
        data: {
          status: ShipmentStatus.FAILED,
          failureReason: reason,
          failureNote: note ?? null,
          attemptCount: { increment: 1 },
        },
      });

      await tx.shipmentEvent.create({
        data: {
          shipmentId: shipment.id,
          status: ShipmentStatus.FAILED,
          note: note ?? reason,
          actorId: courierUserId ?? null,
        },
      });

      // Q37 separates «فشل التسليم» from «رفض الاستلام», and the difference
      // matters to everyone downstream: a missed attempt will be retried, a
      // refusal is a parcel coming back and money to give back. The courier
      // already tells us which by choosing the reason.
      const refused = reason === DeliveryFailureReason.CUSTOMER_REFUSED;
      await this.syncParcel(
        tx,
        shipment.sellerOrderId,
        this.carrierActor(courierUserId),
        {
          to: refused
            ? SellerOrderStatus.REJECTED_ON_DELIVERY
            : SellerOrderStatus.DELIVERY_FAILED,
          title: refused
            ? OrderEventCopy.refusedAtDoor
            : OrderEventCopy.deliveryFailed,
          description: note ?? reason,
        },
      );

      // Goods turned away at the door are goods the seller can sell again.
      // A missed attempt is not: the parcel is still out there and will be
      // tried again tomorrow.
      if (refused) await this.workflow.restock(tx, shipment.sellerOrderId);

      return updated;
    });

    if (reason === DeliveryFailureReason.CUSTOMER_REFUSED) {
      // Whatever she prepaid comes back. Outside the transaction and
      // best-effort for the same reason delivery settles that way: a courier
      // standing at a doorstep with one bar of signal must be able to record
      // what happened, and a busy ledger must not be what stops him. The
      // hourly sweep in `CustomerRefundsService` retries anything that fails.
      try {
        await this.refunds.refundUndeliveredParcel(
          result.sellerOrderId,
          courierUserId ?? null,
        );
      } catch (error) {
        this.logger.error(
          `Recorded a refusal on ${result.trackingCode} but the refund failed ` +
            `— the sweep will retry: ${(error as Error).message}`,
        );
      }
    }

    await this.codTrust.observeBySellerOrder(
      result.sellerOrderId,
      reason === DeliveryFailureReason.CUSTOMER_REFUSED ? 'refused' : 'failed',
    );

    return result;
  }

  // ── Customer-facing tracking (Q64) ────────────────────────────────────

  /** The public trail behind a tracking code. */
  async track(trackingCode: string) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { trackingCode },
      include: {
        events: { orderBy: { createdAt: 'asc' } },
        sellerOrder: { select: { number: true } },
        dispatch: {
          select: {
            status: true,
            trackingNumber: true,
            trackingUrl: true,
            providerCode: true,
            provider: { select: { displayName: true } },
          },
        },
      },
    });
    if (!shipment) throw new NotFoundException('Tracking code not found');

    return {
      tracking_code: shipment.trackingCode,
      order_number: shipment.sellerOrder.number,
      // Who is carrying it, and their own number for it — the two things a
      // woman needs to chase a parcel that has left the platform's hands.
      carrier: shipment.dispatch
        ? {
            name:
              shipment.dispatch.provider?.displayName ??
              shipment.dispatch.providerCode,
            status: shipment.dispatch.status.toLowerCase(),
            tracking_number: shipment.dispatch.trackingNumber,
            tracking_url: shipment.dispatch.trackingUrl,
          }
        : null,
      status: shipment.status.toLowerCase(),
      scheduled_for: shipment.scheduledFor,
      is_express: shipment.isExpress,
      delivered_at: shipment.deliveredAt,
      attempt_count: shipment.attemptCount,
      events: shipment.events.map((event) => ({
        status: event.status.toLowerCase(),
        note: event.note,
        at: event.createdAt,
      })),
    };
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /**
   * What a shipment move implies for the sub-order it carries.
   *
   * The two lifecycles are separate tables describing one box, and keeping
   * them in step is not optional: everything the platform does after a sale —
   * returns, escrow, reviews, loyalty — reads the *sub-order*, not the
   * shipment. Before this the courier's screens moved one and left the other
   * behind, so a parcel could be delivered and the order still say it was
   * waiting for the seller to confirm it.
   */
  private async syncParcel(
    tx: Tx,
    sellerOrderId: string,
    actor: WorkflowActor,
    parcel: ParcelSync,
  ): Promise<void> {
    const current = await tx.sellerOrder.findUniqueOrThrow({
      where: { id: sellerOrderId },
      select: { status: true },
    });

    // A retried action is not an error — the courier tapping twice on a bad
    // connection must not be told the parcel is in the wrong state.
    if (current.status === parcel.to) return;

    if (parcel.require && !parcel.require.includes(current.status)) {
      throw new BadRequestException(
        parcel.requireMessage ??
          `This parcel is ${current.status} and cannot be ${parcel.to} yet`,
      );
    }

    await this.workflow.move(tx, sellerOrderId, parcel.to, actor, {
      title: parcel.title,
      description: parcel.description,
    });
  }

  /**
   * A courier acts under the COURIER role in the lifecycle table even though
   * `UserRole` has no such value — the real gate is `requireCourier`, and the
   * timeline should name what they are rather than the SELLER role their
   * account happens to carry.
   */
  private courierActor(courierUserId: string): WorkflowActor {
    return { id: courierUserId, role: 'COURIER' };
  }

  /**
   * Whoever is carrying it: one of our riders, or a delivery company.
   *
   * A carrier's callback has no user behind it, but it is not the *system*
   * acting either — it is the carrier, reporting what its driver did. So it
   * acts as `COURIER` with no id, which is the same reading the lifecycle
   * table already takes of a self-shipping seller: the role names what the
   * actor was doing, not which account they hold. That is what lets one
   * implementation serve the courier screens and a webhook without widening
   * the transition table for the system.
   */
  private carrierActor(courierUserId?: string): WorkflowActor {
    return courierUserId
      ? this.courierActor(courierUserId)
      : { id: null, role: 'COURIER' };
  }

  /** A shipment, with no ownership claim attached. */
  private async loadShipment(tx: Tx, shipmentId: string): Promise<Shipment> {
    const shipment = await tx.shipment.findUnique({ where: { id: shipmentId } });
    if (!shipment) throw new NotFoundException('Shipment not found');
    return shipment;
  }

  /** A generic status move by an admin or the system. */
  private async transition(
    shipmentId: string,
    to: ShipmentStatus,
    options: {
      actorId?: string;
      /**
       * Who the sub-order move is attributed to. Defaults to the admin who
       * called, or to the system; a carrier's callback passes `COURIER`,
       * because that is what a delivery company is.
       */
      actor?: WorkflowActor;
      data?: Prisma.ShipmentUpdateInput;
      note?: string;
      position?: { latitude?: number; longitude?: number };
      parcel?: ParcelSync;
    } = {},
  ): Promise<Shipment> {
    return this.prisma.$transaction(async (tx) => {
      const shipment = await tx.shipment.findUnique({
        where: { id: shipmentId },
      });
      if (!shipment) throw new NotFoundException('Shipment not found');
      this.assertTransition(shipment.status, to);

      // The parcel moves first. Both writes are in one transaction either way,
      // but doing the check that can *refuse* before the write that cannot
      // keeps the failure clean: a courier told "this is not ready yet" should
      // never find the shipment half-moved behind the message.
      if (options.parcel) {
        await this.syncParcel(
          tx,
          shipment.sellerOrderId,
          options.actor ??
            (options.actorId
              ? { id: options.actorId, role: 'ADMIN' }
              : SYSTEM_ACTOR),
          options.parcel,
        );
      }

      const updated = await tx.shipment.update({
        where: { id: shipmentId },
        data: { status: to, ...options.data },
      });

      await tx.shipmentEvent.create({
        data: {
          shipmentId,
          status: to,
          note: options.note ?? null,
          latitude: options.position?.latitude ?? null,
          longitude: options.position?.longitude ?? null,
          actorId: options.actorId ?? null,
        },
      });

      return updated;
    });
  }

  /** The same, but only if this courier owns the parcel. */
  private async courierTransition(
    shipmentId: string,
    courierUserId: string,
    to: ShipmentStatus,
    options: {
      data?: Prisma.ShipmentUpdateInput;
      note?: string;
      position?: { latitude?: number; longitude?: number };
      parcel?: ParcelSync;
    } = {},
  ): Promise<Shipment> {
    const courier = await this.requireCourier(courierUserId);

    return this.prisma.$transaction(async (tx) => {
      const shipment = await this.loadForCourier(tx, shipmentId, courier);
      this.assertTransition(shipment.status, to);

      // Refusals before writes — see `transition` above.
      if (options.parcel) {
        await this.syncParcel(
          tx,
          shipment.sellerOrderId,
          this.courierActor(courierUserId),
          options.parcel,
        );
      }

      const updated = await tx.shipment.update({
        where: { id: shipmentId },
        data: { status: to, ...options.data },
      });

      await tx.shipmentEvent.create({
        data: {
          shipmentId,
          status: to,
          note: options.note ?? null,
          latitude: options.position?.latitude ?? null,
          longitude: options.position?.longitude ?? null,
          actorId: courierUserId,
        },
      });

      return updated;
    });
  }

  private assertTransition(from: ShipmentStatus, to: ShipmentStatus): void {
    if (!TRANSITIONS[from].includes(to)) {
      throw new BadRequestException(
        `A shipment cannot go from ${from} to ${to}`,
      );
    }
  }

  private async requireCourier(courierUserId: string): Promise<Courier> {
    const courier = await this.prisma.courier.findUnique({
      where: { userId: courierUserId },
    });
    if (!courier) {
      throw new ForbiddenException('This account is not a courier');
    }
    if (!courier.isActive) {
      throw new ForbiddenException('This courier account is inactive');
    }
    return courier;
  }

  /** Loads a parcel, refusing one that belongs to a different courier. */
  private async loadForCourier(
    tx: Tx,
    shipmentId: string,
    courier: Courier,
  ): Promise<Shipment> {
    const shipment = await tx.shipment.findUnique({
      where: { id: shipmentId },
    });
    if (!shipment) throw new NotFoundException('Shipment not found');
    if (shipment.courierId !== courier.id) {
      throw new ForbiddenException('This parcel is assigned to another courier');
    }
    return shipment;
  }

  /**
   * `REM-7F3K9QX2` — short enough to read down a phone line, random enough
   * that a customer cannot guess someone else's parcel from her own.
   */
  private trackingCode(): string {
    const alphabet = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // no I/O to misread
    const bytes = randomBytes(8);
    let code = '';
    for (const byte of bytes) code += alphabet[byte % alphabet.length];
    return `REM-${code}`;
  }
}
