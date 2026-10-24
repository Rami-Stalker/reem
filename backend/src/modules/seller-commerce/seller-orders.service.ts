import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  CodAssuranceState,
  FulfilmentMode,
  PaymentStatus,
  Prisma,
  SellerOrder,
  SellerOrderStatus,
  ShipmentStatus,
} from '@prisma/client';

import { AuthUser } from '../../common/decorators/current-user.decorator';
import { buildMeta, PaginationDto } from '../../common/dto/pagination.dto';
import { Money, nextStatuses } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { OrderEventCopy } from '../../common/orders/order-event-copy';
import { CommissionsService } from '../commissions/commissions.service';
import { CustomerRefundsService } from '../finance/customer-refunds.service';
import { DeliveryDispatchService } from '../delivery/dispatch/delivery-dispatch.service';
import { sellerLabelFor } from '../cod-trust/cod-trust.service';
import {
  SellerOrderWorkflowService,
  WorkflowActor,
  actorOf,
} from '../orders/workflow/seller-order-workflow.service';

type Tx = Prisma.TransactionClient;

/**
 * The statuses a seller's queue is organised by, in the order she works
 * through them. Anything not listed lives under "منتهية".
 */
const QUEUE_TABS: Readonly<Record<string, readonly SellerOrderStatus[]>> =
  Object.freeze({
    new: [
      SellerOrderStatus.NEW,
      SellerOrderStatus.AWAITING_SELLER_CONFIRMATION,
    ],
    preparing: [SellerOrderStatus.PREPARING],
    ready: [SellerOrderStatus.READY_TO_SHIP],
    shipping: [
      SellerOrderStatus.HANDED_TO_COURIER,
      SellerOrderStatus.IN_TRANSIT,
      SellerOrderStatus.DELIVERY_FAILED,
    ],
    returns: [
      SellerOrderStatus.RETURN_REQUESTED,
      SellerOrderStatus.RETURN_IN_TRANSIT,
      SellerOrderStatus.RETURNED,
      SellerOrderStatus.EXCHANGE_IN_PROGRESS,
      SellerOrderStatus.DISPUTED,
    ],
    completed: [
      SellerOrderStatus.DELIVERED,
      SellerOrderStatus.EXCHANGED,
      SellerOrderStatus.REFUNDED,
      SellerOrderStatus.CANCELLED_BY_CUSTOMER,
      SellerOrderStatus.CANCELLED_BY_SELLER,
      SellerOrderStatus.REJECTED_ON_DELIVERY,
      SellerOrderStatus.REFUND_PENDING,
    ],
  });

export type QueueTab = keyof typeof QUEUE_TABS;

/**
 * The seller's side of a sale.
 *
 * The platform had a seller dashboard full of figures and no way for a seller
 * to actually work an order: a parcel arrived in `AWAITING_SELLER_CONFIRMATION`
 * and stayed there for ever, because nothing in the codebase could move it.
 * Every consequence of that was downstream — a sub-order that never reaches
 * `DELIVERED` never opens a return window, never releases escrow, never earns
 * loyalty points and never lets the customer leave a review.
 *
 * Two rules shape this service:
 *
 * **A seller only claims what she did.** She confirms, prepares and marks
 * ready; she hands over only when she is the one carrying it (Q57's
 * self-shipping), because for a platform parcel the courier's own pick-up is
 * the honest record of the handover. Nothing here lets her mark a parcel
 * delivered that somebody else is carrying.
 *
 * **What she sees of the customer depends on how it ships (Q57).** That answer
 * is what resolves the contradiction between Q44's «إخفاء اسم الزبونة عن
 * البائع» and the fact that a seller shipping her own parcel obviously needs an
 * address. So the masking is computed per parcel from its fulfilment mode
 * rather than being a global switch that has to be wrong for one of the two.
 */
@Injectable()
export class SellerOrdersService {
  private readonly logger = new Logger(SellerOrdersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly workflow: SellerOrderWorkflowService,
    private readonly commissions: CommissionsService,
    private readonly refunds: CustomerRefundsService,
    private readonly dispatches: DeliveryDispatchService,
  ) {}

  // ── Reading ───────────────────────────────────────────────────────────

  /** Her queue, plus the counts every tab needs to render its badge. */
  async queue(user: AuthUser, tab: QueueTab | undefined, page: PaginationDto) {
    const where: Prisma.SellerOrderWhereInput = {
      sellerId: user.id,
      ...(tab ? { status: { in: [...QUEUE_TABS[tab]] } } : {}),
    };

    const [rows, total, counts] = await Promise.all([
      this.prisma.sellerOrder.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: page.skip,
        take: page.limit,
        include: this.listInclude(),
      }),
      this.prisma.sellerOrder.count({ where }),
      this.prisma.sellerOrder.groupBy({
        by: ['status'],
        where: { sellerId: user.id },
        _count: { _all: true },
      }),
    ]);

    return {
      data: rows.map((row) => this.serializeSummary(row)),
      counts: this.tabCounts(counts),
      pagination: buildMeta(page.page, page.limit, total, rows.length),
    };
  }

  async detail(user: AuthUser, sellerOrderId: string) {
    const parcel = await this.load(sellerOrderId, user.id);
    return this.serializeDetail(parcel);
  }

  // ── Working the order ─────────────────────────────────────────────────

  /**
   * Q37 «قيد التجهيز» — she has seen it and started work.
   *
   * This is also the moment the customer's right to edit the order closes
   * (Q39 allows changes «قبل التجهيز»), which is why accepting is a deliberate
   * act rather than something the system does for her after a timeout.
   */
  async confirm(user: AuthUser, sellerOrderId: string) {
    await this.load(sellerOrderId, user.id);

    await this.prisma.$transaction((tx) =>
      this.workflow.move(
        tx,
        sellerOrderId,
        SellerOrderStatus.PREPARING,
        actorOf(user),
        {
          title: OrderEventCopy.orderAccepted,
          description: OrderEventCopy.sellerPreparing,
        },
      ),
    );

    return this.detail(user, sellerOrderId);
  }

  /** Q37 «جاهز للشحن» — packed and waiting for whoever carries it. */
  async ready(user: AuthUser, sellerOrderId: string) {
    const parcel = await this.load(sellerOrderId, user.id);

    await this.prisma.$transaction(async (tx) => {
      await this.workflow.move(
        tx,
        sellerOrderId,
        SellerOrderStatus.READY_TO_SHIP,
        actorOf(user),
        {
          title: OrderEventCopy.readyToShip,
          description:
            parcel.fulfilmentMode === FulfilmentMode.SELLER_SHIPS
              ? 'The seller will deliver this parcel herself'
              : 'Waiting for the courier to collect',
        },
      );
    });

    // A packed parcel is handed to whichever delivery company serves that
    // address — or to the in-house fleet, which is modelled as one more
    // carrier. Outside the transaction and swallowed on failure on purpose: a
    // carrier being slow, down or unconfigured must never undo a seller's
    // honest "this is packed". The dispatch row records why, and ops can retry.
    if (parcel.fulfilmentMode !== FulfilmentMode.SELLER_SHIPS) {
      try {
        await this.dispatches.dispatch(sellerOrderId);
      } catch (error) {
        this.logger.error(
          `Could not dispatch parcel ${sellerOrderId}: ${(error as Error).message}`,
        );
      }
    }

    return this.detail(user, sellerOrderId);
  }

  /**
   * Q57 — the seller carrying her own parcel records the handover herself.
   *
   * Refused for a platform parcel on purpose: the courier's own pick-up is
   * what moves that one, and a seller able to declare a handover nobody made
   * would put a parcel "in transit" while it sat on her shelf — with the
   * customer watching the tracking page.
   */
  async handOver(
    user: AuthUser,
    sellerOrderId: string,
    carrier?: string,
  ) {
    const parcel = await this.load(sellerOrderId, user.id);
    this.assertSelfCarried(
      parcel.fulfilmentMode,
      'Only a parcel you are carrying yourself can be handed over here — the courier records the pick-up for the rest',
    );

    await this.prisma.$transaction((tx) =>
      this.workflow.move(
        tx,
        sellerOrderId,
        SellerOrderStatus.HANDED_TO_COURIER,
        this.asCarrier(user),
        {
          title: OrderEventCopy.onItsWay,
          description: carrier ?? 'Handed over for delivery',
        },
      ),
    );

    return this.detail(user, sellerOrderId);
  }

  /**
   * Q57 — she delivered it herself.
   *
   * Delivery is what makes the sale revenue-bearing, so settlement runs from
   * here exactly as it does from the courier's screen, and outside the
   * transaction for the same reason: a ledger hiccup must not roll back a
   * delivery that physically happened.
   */
  async deliver(
    user: AuthUser,
    sellerOrderId: string,
    options: { collected?: string; note?: string } = {},
  ) {
    const parcel = await this.load(sellerOrderId, user.id);
    this.assertSelfCarried(
      parcel.fulfilmentMode,
      'A parcel carried by the platform is marked delivered by its courier',
    );

    const collected =
      options.collected === undefined
        ? null
        : Money.of(options.collected, parcel.currency);
    if (collected?.isNegative()) {
      throw new BadRequestException('Collected cash cannot be negative');
    }

    await this.prisma.$transaction(async (tx) => {
      // A parcel she has not yet declared under way has to pass through the
      // road to get off it. Walking the step rather than skipping it keeps the
      // timeline honest — she did carry it — and keeps the lifecycle table the
      // only description of what may follow what.
      const current = await tx.sellerOrder.findUniqueOrThrow({
        where: { id: sellerOrderId },
        select: { status: true },
      });
      if (current.status === SellerOrderStatus.HANDED_TO_COURIER) {
        await this.workflow.move(
          tx,
          sellerOrderId,
          SellerOrderStatus.IN_TRANSIT,
          this.asCarrier(user),
          {
            title: OrderEventCopy.outForDelivery,
            description: OrderEventCopy.onTheWayToCustomer,
          },
        );
      }

      await this.workflow.move(
        tx,
        sellerOrderId,
        SellerOrderStatus.DELIVERED,
        this.asCarrier(user),
        {
          title: OrderEventCopy.delivered,
          description: options.note ?? 'Delivered by the seller',
        },
      );

      if (collected && !collected.isZero()) {
        await this.workflow.recordCollection(
          tx,
          parcel.orderId,
          collected.toPrisma(),
        );
      }
    });

    await this.settleQuietly(sellerOrderId);
    return this.detail(user, sellerOrderId);
  }

  /**
   * Q37 «ملغي من البائع» — she cannot fulfil it.
   *
   * The stock goes back on the shelf in the same transaction, because an item
   * held by a cancelled order is an item nobody can buy. A reason is required:
   * cancellations are the seller's own quality record (Q18 P1 ties packages and
   * commission to performance), and one with no reason cannot be reviewed.
   */
  async cancel(user: AuthUser, sellerOrderId: string, reason: string) {
    const parcel = await this.load(sellerOrderId, user.id);

    const wasPaid = parcel.order.payment?.status === PaymentStatus.PAID;

    await this.prisma.$transaction(async (tx) => {
      await this.workflow.move(
        tx,
        sellerOrderId,
        SellerOrderStatus.CANCELLED_BY_SELLER,
        actorOf(user),
        {
          title: OrderEventCopy.cancelledBySeller,
          description: reason,
          data: { cancellationReason: reason },
        },
      );

      // The workflow's own version, not a private copy: it also puts back the
      // demand counters the checkout inflated, which this one never did.
      await this.workflow.restock(tx, sellerOrderId);

      // A parcel nobody is carrying any more must not stay on a courier's
      // round; the shipment is cancelled with it where one exists.
      if (
        parcel.shipment &&
        parcel.shipment.status !== ShipmentStatus.CANCELLED &&
        (parcel.shipment.status === ShipmentStatus.CREATED ||
          parcel.shipment.status === ShipmentStatus.ASSIGNED)
      ) {
        await tx.shipment.update({
          where: { id: parcel.shipment.id },
          data: { status: ShipmentStatus.CANCELLED },
        });
        await tx.shipmentEvent.create({
          data: {
            shipmentId: parcel.shipment.id,
            status: ShipmentStatus.CANCELLED,
            note: reason,
            actorId: user.id,
          },
        });
      }
    });

    this.logger.log(
      `Seller ${user.id} cancelled ${parcel.number}: ${reason}`,
    );

    // A customer who has already paid gets her money back whoever cancelled.
    // The seller's screen must not depend on the ledger being reachable, so a
    // failure here leaves the parcel `REFUND_PENDING` for the sweep.
    if (wasPaid) {
      try {
        await this.refunds.refundUndeliveredParcel(sellerOrderId, user.id);
      } catch (error) {
        this.logger.error(
          `Cancelled ${parcel.number} but the refund failed — the sweep will ` +
            `retry: ${(error as Error).message}`,
        );
      }
    }

    return this.detail(user, sellerOrderId);
  }

  // ── Internals ─────────────────────────────────────────────────────────

  private listInclude() {
    return {
      items: true,
      shipment: {
        select: {
          id: true,
          trackingCode: true,
          status: true,
          courierId: true,
          // Which company is carrying it, so the seller's screen can say so
          // rather than leaving her to guess who to chase.
          dispatch: {
            select: {
              status: true,
              trackingNumber: true,
              providerCode: true,
              lastError: true,
              provider: { select: { displayName: true } },
            },
          },
        },
      },
      order: {
        select: {
          id: true,
          number: true,
          privacyMaskEnabled: true,
          recipientName: true,
          recipientPhone: true,
          governorate: true,
          district: true,
          city: true,
          addressLine: true,
          landmark: true,
          latitude: true,
          longitude: true,
          deliveryInstructions: true,
          payment: { select: { method: true, status: true } },
          codRiskAssessment: {
            select: { tier: true, assurance: true, state: true },
          },
        },
      },
    } satisfies Prisma.SellerOrderInclude;
  }

  private async load(sellerOrderId: string, sellerId: string) {
    const parcel = await this.prisma.sellerOrder.findUnique({
      where: { id: sellerOrderId },
      include: this.listInclude(),
    });
    if (!parcel) throw new NotFoundException('Order not found');
    if (parcel.sellerId !== sellerId) {
      // Not a 403: a seller has no business learning that another seller's
      // order number exists.
      throw new NotFoundException('Order not found');
    }
    return parcel;
  }

  /**
   * A seller delivering her own parcel *is* the courier for it (Q57), so the
   * lifecycle table sees her as one. That is not a loophole: the two routes
   * that use this both refuse any fulfilment mode but `SELLER_SHIPS` first, so
   * the only person who can act as the carrier is the person carrying it. The
   * timeline records COURIER because that is what she is doing, which is also
   * what makes her steps read the same as a real courier's to the customer.
   */
  private asCarrier(user: AuthUser): WorkflowActor {
    return { id: user.id, role: 'COURIER' };
  }

  private assertSelfCarried(mode: FulfilmentMode, message: string): void {
    if (mode !== FulfilmentMode.SELLER_SHIPS) {
      throw new ForbiddenException(message);
    }
  }

  /** Settlement must never be the reason a delivery fails to record. */
  private async settleQuietly(sellerOrderId: string): Promise<void> {
    try {
      await this.commissions.settleSellerOrder(sellerOrderId);
    } catch (error) {
      this.logger.error(
        `Delivered ${sellerOrderId} but settlement failed — the escrow sweep ` +
          `will retry: ${(error as Error).message}`,
      );
    }
  }

  private tabCounts(
    rows: Array<{ status: SellerOrderStatus; _count: { _all: number } }>,
  ): Record<string, number> {
    const byStatus = new Map(rows.map((row) => [row.status, row._count._all]));
    const counts: Record<string, number> = {};
    for (const [tab, statuses] of Object.entries(QUEUE_TABS)) {
      counts[tab] = statuses.reduce(
        (total, status) => total + (byStatus.get(status) ?? 0),
        0,
      );
    }
    return counts;
  }

  // ── Serialisation ─────────────────────────────────────────────────────

  /**
   * What the seller is told about the refusal risk on a cash parcel.
   *
   * She gets the tier and a phrase, never the score and never a factor. The
   * number is a platform decision she cannot change and would only argue with;
   * the factors are a map of exactly what to avoid, and sellers talk to
   * customers. What is actionable to her — pack it, ring first, wait for the
   * code — is entirely contained in the tier.
   *
   * Absent on a prepaid parcel, because nothing was assessed: there was no
   * cash on the road to lose.
   */
  private codRisk(
    parcel: Prisma.SellerOrderGetPayload<{
      include: ReturnType<SellerOrdersService['listInclude']>;
    }>,
  ) {
    const assessment = parcel.order.codRiskAssessment;
    if (!assessment) return null;
    return {
      tier: assessment.tier.toLowerCase(),
      label: sellerLabelFor(assessment.tier),
      // True while the customer still owes a code — the parcel is hers to see
      // but not yet hers to pack.
      awaiting_confirmation: assessment.state === CodAssuranceState.PENDING,
    };
  }

  private serializeSummary(
    parcel: Prisma.SellerOrderGetPayload<{
      include: ReturnType<SellerOrdersService['listInclude']>;
    }>,
  ) {
    const currency = parcel.currency;
    return {
      id: parcel.id,
      number: parcel.number,
      // Lower-cased like every other status on the wire. The seller's queue
      // and the customer's order are the same parcel seen from two sides; a
      // client that had to know which side it asked to know how to compare a
      // status is a client that will get it wrong on one of them.
      status: parcel.status.toLowerCase(),
      fulfilment_mode: parcel.fulfilmentMode.toLowerCase(),
      placed_at: parcel.createdAt,
      items_count: parcel.items.reduce((sum, item) => sum + item.quantity, 0),
      // The seller is shown her own net, never the customer's total: the
      // commission is already taken out and quoting the gross to her invites
      // an argument about a number she was never going to receive.
      net: Money.of(parcel.sellerNet, currency).toJSON(),
      commission: Money.of(parcel.commissionAmount, currency).toJSON(),
      payment_method: parcel.order.payment?.method.toLowerCase() ?? null,
      payment_status: parcel.order.payment?.status.toLowerCase() ?? null,
      tracking_code: parcel.shipment?.trackingCode ?? null,
      customer: this.maskedCustomer(parcel),
      cod_risk: this.codRisk(parcel),
      // What she can do next, straight from the lifecycle table — a button the
      // backend would refuse is worse than no button.
      available_actions: this.actionsFor(parcel),
    };
  }

  private discountSplit(
    parcel: Pick<SellerOrder, 'currency' | 'itemsSubtotal' | 'discountTotal' | 'commissionBase'>,
  ) {
    const currency = parcel.currency;
    const zero = Money.zero(currency);
    const subtotal = Money.of(parcel.itemsSubtotal, currency);
    const base = Money.of(parcel.commissionBase, currency);
    const customerPaid = subtotal.minus(Money.of(parcel.discountTotal, currency));
    return {
      seller_funded_discount: subtotal.minus(base).clampMin(zero).toJSON(),
      platform_funded_discount: base.minus(customerPaid).clampMin(zero).toJSON(),
    };
  }

  private serializeDetail(
    parcel: Prisma.SellerOrderGetPayload<{
      include: ReturnType<SellerOrdersService['listInclude']>;
    }>,
  ) {
    const currency = parcel.currency;
    return {
      ...this.serializeSummary(parcel),
      order_number: parcel.order.number,
      currency,
      items_subtotal: Money.of(parcel.itemsSubtotal, currency).toJSON(),
      discount_total: Money.of(parcel.discountTotal, currency).toJSON(),
      shipping_cost: Money.of(parcel.shippingCost, currency).toJSON(),
      commission_base: Money.of(parcel.commissionBase, currency).toJSON(),
      // The discount split by who paid for it (Q49 — «يتحملها من أنشأ
      // الكوبون»). Her share is what came off the price she is paid on; the
      // platform's is what it made up on top. Without the split her screen
      // listed a platform coupon as a deduction from her money, and the
      // breakdown no longer added up to her net.
      ...this.discountSplit(parcel),
      confirmed_at: parcel.confirmedAt,
      shipped_at: parcel.shippedAt,
      delivered_at: parcel.deliveredAt,
      escrow_release_at: parcel.escrowReleaseAt,
      escrow_released: parcel.escrowReleased,
      cancellation_reason: parcel.cancellationReason,
      shipment: parcel.shipment
        ? {
            tracking_code: parcel.shipment.trackingCode,
            status: parcel.shipment.status.toLowerCase(),
            // "Assigned" now means somebody is carrying it — one of our
            // couriers, or a delivery company that accepted it.
            assigned:
              parcel.shipment.courierId != null ||
              parcel.shipment.dispatch?.trackingNumber != null ||
              parcel.shipment.dispatch?.status === ShipmentStatus.ASSIGNED,
            carrier: parcel.shipment.dispatch
              ? {
                  name:
                    parcel.shipment.dispatch.provider?.displayName ??
                    parcel.shipment.dispatch.providerCode,
                  status: parcel.shipment.dispatch.status.toLowerCase(),
                  tracking_number: parcel.shipment.dispatch.trackingNumber,
                  // Only the seller and the admin see why a dispatch failed;
                  // it is an operations fact, not something the customer needs.
                  last_error: parcel.shipment.dispatch.lastError,
                }
              : null,
          }
        : null,
      items: parcel.items.map((item) => ({
        id: item.id,
        title: item.titleSnapshot,
        variant: item.variantSnapshot,
        image: item.imageSnapshot,
        quantity: item.quantity,
        unit_price: Money.of(item.unitPrice, item.currency).toJSON(),
        line_total: Money.of(item.lineTotal, item.currency).toJSON(),
        customisation: item.customisation,
      })),
    };
  }

  /**
   * What the seller may see of the customer, decided by how the parcel ships.
   *
   * Q57 answers the question directly — «يعتمد على طريقة الشحن المختارة» — and
   * that is the only reading under which Q44's masking and self-shipping can
   * both be true. A seller who is about to knock on the door needs the door;
   * one whose parcel a courier collects needs to know the city and nothing
   * more. `privacyMaskEnabled` is the customer's own extra request on top, and
   * it can only ever hide more.
   */
  private maskedCustomer(parcel: {
    fulfilmentMode: FulfilmentMode;
    order: {
      privacyMaskEnabled: boolean;
      recipientName: string;
      recipientPhone: string;
      governorate: string;
      district: string | null;
      city: string;
      addressLine: string;
      landmark: string | null;
      latitude: number | null;
      longitude: number | null;
      deliveryInstructions: string | null;
    };
  }) {
    const { order } = parcel;
    const full = parcel.fulfilmentMode === FulfilmentMode.SELLER_SHIPS;

    if (!full) {
      return {
        name: this.firstName(order.recipientName),
        phone: null,
        governorate: order.governorate,
        city: order.privacyMaskEnabled ? null : order.city,
        district: null,
        address_line: null,
        landmark: null,
        latitude: null,
        longitude: null,
        delivery_instructions: order.deliveryInstructions,
        is_masked: true,
        masked_because:
          'الشحن عبر مندوب المنصة — العنوان مع المندوب وليس مع البائعة',
      };
    }

    return {
      name: order.privacyMaskEnabled
        ? this.firstName(order.recipientName)
        : order.recipientName,
      phone: order.recipientPhone,
      governorate: order.governorate,
      city: order.city,
      district: order.district,
      address_line: order.addressLine,
      landmark: order.landmark,
      // She ships it herself, so she needs the door — the pin is the door.
      latitude: order.latitude,
      longitude: order.longitude,
      delivery_instructions: order.deliveryInstructions,
      is_masked: order.privacyMaskEnabled,
      masked_because: null,
    };
  }

  /** «ريم الدالي» → «ريم» — enough to greet her by, not enough to find her. */
  private firstName(name: string): string {
    return name.trim().split(/\s+/)[0] ?? name;
  }

  /**
   * The actions this parcel actually offers, filtered by what the seller may
   * do to it herself. Derived from the same table the transition check uses,
   * so a button can never appear for a move the service would refuse.
   */
  private actionsFor(parcel: {
    status: SellerOrderStatus;
    fulfilmentMode: FulfilmentMode;
  }): string[] {
    const allowed = nextStatuses(parcel.status, 'SELLER');
    const selfCarried = parcel.fulfilmentMode === FulfilmentMode.SELLER_SHIPS;
    const actions: string[] = [];

    if (allowed.includes(SellerOrderStatus.PREPARING)) actions.push('confirm');
    if (allowed.includes(SellerOrderStatus.READY_TO_SHIP)) actions.push('ready');
    if (selfCarried && allowed.includes(SellerOrderStatus.HANDED_TO_COURIER)) {
      actions.push('hand_over');
    }
    if (selfCarried && allowed.includes(SellerOrderStatus.DELIVERED)) {
      actions.push('deliver');
    }
    if (allowed.includes(SellerOrderStatus.CANCELLED_BY_SELLER)) {
      actions.push('cancel');
    }
    return actions;
  }
}

export const SELLER_QUEUE_TABS = Object.keys(QUEUE_TABS) as QueueTab[];
