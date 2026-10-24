import {
  CashbackStatus,
  CommissionStatus,
  CourierKind,
  Currency,
  DeliveryFailureReason,
  DisputeStatus,
  FinancialLedgerType,
  FulfilmentMode,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  OrderStatus,
  PaymentMethodType,
  PaymentStatus,
  PayoutStatus,
  PointsTransactionType,
  Prisma,
  ReturnCostBearer,
  ReturnReason,
  ReturnResolution,
  ReturnStatus,
  ReviewStatus,
  RoundingPolicy,
  SellerOrderStatus,
  ShipmentStatus,
  UserRole,
} from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import {
  REVIEW_BODIES_MIXED,
  REVIEW_BODIES_POSITIVE,
  REVIEW_TITLES,
} from './data';
import { Money } from '../../src/common/money';
import {
  POINTS_PER_REDEMPTION,
  SYP_PER_POINT,
  SYP_PER_REDEMPTION,
} from '../../src/modules/finance/loyalty.service';
import { LedgerService } from '../../src/modules/ledger/ledger.service';
import { PrismaService } from '../../src/prisma/prisma.service';
import { roundSyp } from './rng';
import { DemoContext, DemoProduct } from './context';

/** Shared by every seeded courier, printed with the rest of the logins. */
export const COURIER_PASSWORD = 'Courier123!';

const D = Prisma.Decimal;

/** Commission basis points by seller level — mirrors the seeded rules. */
const COMMISSION_BPS: Record<string, number> = {
  BASIC: 1000,
  VERIFIED: 800,
  PREMIUM: 600,
};

/** Q54 P1 — free shipping is a membership benefit, not a flat platform rule. */
/// New Syrian pounds — the old 300,000 threshold, redenominated.
const FREE_SHIPPING_ABOVE = 3_000;
const FREE_SHIPPING_TIERS = ['Gold', 'Platinum'];

/**
 * One row of the order lifecycle the dataset has to cover. The client's Q37
 * list has 18 seller states and 10 customer-facing roll-ups; every screen that
 * renders a status chip needs at least one order sitting in that state, so the
 * distribution below is explicit rather than random.
 */
interface LifecyclePlan {
  status: OrderStatus;
  subStatuses: SellerOrderStatus[];
  count: number;
  paid: boolean;
  ageDays: [number, number];
  /** Forces a basket spanning two boutiques — the partial-* states need it. */
  multiSeller?: boolean;
}

const LIFECYCLE: LifecyclePlan[] = [
  {
    status: OrderStatus.DELIVERED,
    subStatuses: [SellerOrderStatus.DELIVERED],
    count: 22,
    paid: true,
    ageDays: [8, 150],
  },
  {
    status: OrderStatus.SHIPPED,
    subStatuses: [
      SellerOrderStatus.IN_TRANSIT,
      SellerOrderStatus.HANDED_TO_COURIER,
    ],
    count: 6,
    paid: true,
    ageDays: [1, 5],
  },
  {
    status: OrderStatus.CONFIRMED,
    subStatuses: [
      SellerOrderStatus.PREPARING,
      SellerOrderStatus.READY_TO_SHIP,
      SellerOrderStatus.AWAITING_SELLER_CONFIRMATION,
    ],
    count: 8,
    paid: false,
    ageDays: [0, 3],
  },
  {
    status: OrderStatus.PENDING_PAYMENT,
    subStatuses: [SellerOrderStatus.NEW],
    count: 4,
    paid: false,
    ageDays: [0, 2],
  },
  {
    status: OrderStatus.PARTIALLY_SHIPPED,
    subStatuses: [SellerOrderStatus.IN_TRANSIT, SellerOrderStatus.PREPARING],
    count: 3,
    paid: true,
    ageDays: [1, 6],
    multiSeller: true,
  },
  {
    status: OrderStatus.PARTIALLY_DELIVERED,
    subStatuses: [SellerOrderStatus.DELIVERED, SellerOrderStatus.IN_TRANSIT],
    count: 2,
    paid: true,
    ageDays: [2, 10],
    multiSeller: true,
  },
  {
    status: OrderStatus.CANCELLED,
    subStatuses: [
      SellerOrderStatus.CANCELLED_BY_CUSTOMER,
      SellerOrderStatus.CANCELLED_BY_SELLER,
    ],
    count: 4,
    paid: false,
    ageDays: [3, 60],
  },
  {
    status: OrderStatus.CLOSED,
    subStatuses: [SellerOrderStatus.RETURNED, SellerOrderStatus.REFUNDED],
    count: 4,
    paid: true,
    ageDays: [20, 120],
  },
  {
    status: OrderStatus.SHIPPED,
    subStatuses: [
      SellerOrderStatus.DELIVERY_FAILED,
      SellerOrderStatus.REJECTED_ON_DELIVERY,
    ],
    count: 3,
    paid: false,
    ageDays: [2, 20],
  },
  // After-sales: the states a sub-order lands in once the parcel is already
  // with the customer. Without these the returns, exchange and dispute
  // screens have nothing to list.
  {
    status: OrderStatus.DELIVERED,
    subStatuses: [
      SellerOrderStatus.RETURN_REQUESTED,
      SellerOrderStatus.RETURN_IN_TRANSIT,
      SellerOrderStatus.EXCHANGE_IN_PROGRESS,
      SellerOrderStatus.EXCHANGED,
      SellerOrderStatus.REFUND_PENDING,
      SellerOrderStatus.DISPUTED,
    ],
    count: 8,
    paid: true,
    ageDays: [10, 70],
  },
];

/** Q51 P1 — COD is the launch rail; the wallets exist but carry less volume. */
const PAYMENT_METHODS: (readonly [PaymentMethodType, number])[] = [
  [PaymentMethodType.COD, 10],
  [PaymentMethodType.SYRIATEL_CASH, 4],
  [PaymentMethodType.MTN_CASH, 3],
  [PaymentMethodType.SHAM_CASH, 3],
  [PaymentMethodType.BANK_TRANSFER, 2],
  [PaymentMethodType.HAWALA, 1],
];

export interface SeededOrder {
  id: string;
  number: string;
  customerId: string;
  status: OrderStatus;
  placedAt: Date;
  grandTotal: number;
  couponCode: string | null;
  discountTotal: number;
  sellerOrders: {
    id: string;
    sellerId: string;
    status: SellerOrderStatus;
    net: number;
    gross: number;
    commission: number;
    deliveredAt: Date | null;
    items: {
      id: string;
      productId: string;
      quantity: number;
      lineTotal: number;
    }[];
  }[];
}

/**
 * Couriers first — shipments point at them.
 *
 * Each one gets a login of her own. A `Courier` row with no `userId` is a name
 * on a parcel and nothing else: the courier screens (today's round, pick-up,
 * delivered, failed) all resolve the rider from her account, so a fleet seeded
 * without accounts is a fleet that cannot move a single box — and with it no
 * order in the whole demo ever reaches DELIVERED.
 */
async function seedCouriers(ctx: DemoContext) {
  const { prisma } = ctx;
  const passwordHash = await bcrypt.hash(COURIER_PASSWORD, 12);
  const definitions = [
    {
      kind: CourierKind.PLATFORM_STAFF,
      displayName: 'فريق أوهارا للتوصيل',
      phone: '+963940000001',
      governorates: ['دمشق', 'ريف دمشق'],
    },
    {
      kind: CourierKind.THIRD_PARTY,
      displayName: 'الفؤاد للشحن',
      phone: '+963940000002',
      companyName: 'الفؤاد',
      governorates: ['حلب', 'إدلب', 'الرقة'],
    },
    {
      kind: CourierKind.THIRD_PARTY,
      displayName: 'قاسيون إكسبرس',
      phone: '+963940000003',
      companyName: 'قاسيون',
      governorates: ['حمص', 'حماة', 'طرطوس', 'اللاذقية'],
    },
    {
      kind: CourierKind.THIRD_PARTY,
      displayName: 'الشرق للتوصيل',
      phone: '+963940000004',
      companyName: 'الشرق',
      governorates: ['دير الزور', 'الحسكة', 'السويداء', 'درعا'],
    },
  ];

  const couriers = [];
  for (const [index, definition] of definitions.entries()) {
    // A plain account, not a privileged one: what makes her a courier is the
    // row below, and the courier routes check exactly that.
    const user = await prisma.user.create({
      data: {
        name: definition.displayName,
        username: `courier_${index + 1}`,
        phone: definition.phone,
        passwordHash,
        passwordSetAt: new Date(),
        role: UserRole.CUSTOMER,
        isVerified: true,
        phoneVerifiedAt: new Date(),
      },
    });
    couriers.push(
      await prisma.courier.create({ data: { ...definition, userId: user.id } }),
    );
  }
  return couriers;
}

/**
 * Builds the whole order history: parent orders, per-seller sub-orders,
 * payments, shipments, returns, disputes, the commission ledger and the
 * financial ledger behind them.
 *
 * The parent/sub split (Q36 P1) is the reason this is written by hand rather
 * than by calling the checkout service — checkout only ever produces "just
 * placed" orders, and a demo needs the other seventeen states too.
 */
export async function seedOrders(ctx: DemoContext): Promise<SeededOrder[]> {
  const { prisma, rng } = ctx;

  const couriers = await seedCouriers(ctx);
  const zones = await prisma.shippingZone.findMany();
  const coupons = await prisma.coupon.findMany({ where: { isActive: true } });
  const rules = await prisma.commissionRule.findMany();

  const sellable = ctx.products.filter((product) => product.offers.length > 0);
  const orders: SeededOrder[] = [];
  let sequence = 200_000;

  for (const plan of LIFECYCLE) {
    for (let n = 0; n < plan.count; n += 1) {
      sequence += 1;
      const customer = rng.pick(ctx.customers);
      const placedAt = rng.pastDate(plan.ageDays[1], plan.ageDays[0]);

      // Pick lines, forcing two boutiques when the plan needs a partial state.
      const lines = pickLines(ctx, sellable, plan.multiSeller ?? false);
      if (lines.length === 0) continue;

      const itemsSubtotal = lines.reduce(
        (total, line) => total + line.lineTotal,
        0,
      );

      const coupon =
        coupons.length && rng.bool(0.28) ? rng.pick(coupons) : null;
      const discountTotal = coupon
        ? roundSyp(
            coupon.amountOff
              ? Math.min(Number(coupon.amountOff), itemsSubtotal * 0.5)
              : (itemsSubtotal * Number(coupon.discountPercent)) / 100,
          )
        : 0;

      const zone =
        zones.find((row) => row.governorate === customer.governorate) ??
        zones[0];
      const qualifiesFree =
        FREE_SHIPPING_TIERS.includes(customer.tier) &&
        itemsSubtotal - discountTotal >= FREE_SHIPPING_ABOVE;
      const shippingTotal = qualifiesFree ? 0 : Number(zone.baseFee);

      const grandTotal = itemsSubtotal - discountTotal + shippingTotal;
      const method = rng.weighted(PAYMENT_METHODS);
      const number = `REEM-${sequence}`;

      const order = await prisma.order.create({
        data: {
          number,
          userId: customer.id,
          status: plan.status,
          currency: Currency.SYP,
          fxRate: ctx.fxRate,
          fxRateId: ctx.fxRateId,
          fxFrozenAt: placedAt,
          roundingPolicy: RoundingPolicy.NEAREST_10,
          itemsSubtotal: new D(itemsSubtotal),
          discountTotal: new D(discountTotal),
          shippingTotal: new D(shippingTotal),
          grandTotal: new D(grandTotal),
          couponCode: coupon?.code ?? null,
          recipientName: customer.name,
          recipientPhone: customer.phone,
          governorate: customer.governorate,
          district: customer.district,
          city: customer.city,
          addressLine: customer.address,
          landmark: rng.bool(0.4) ? 'قرب الصيدلية' : null,
          privacyMaskEnabled: rng.bool(0.25),
          deliveryInstructions: rng.bool(0.35)
            ? 'يرجى الاتصال قبل الوصول'
            : null,
          placedAt,
          createdAt: placedAt,
          payment: {
            create: {
              method,
              status: plan.paid ? PaymentStatus.PAID : PaymentStatus.PENDING,
              currency: Currency.SYP,
              amount: new D(grandTotal),
              capturedAmount: new D(plan.paid ? grandTotal : 0),
              transactionRef: `TXN-${number}`,
              providerRef: method === PaymentMethodType.COD ? null : `PR-${sequence}`,
              paidAt: plan.paid ? new Date(placedAt.getTime() + 3.6e6) : null,
              createdAt: placedAt,
              transactions: {
                create: plan.paid
                  ? [
                      {
                        event: 'initiated',
                        status: PaymentStatus.PENDING,
                        currency: Currency.SYP,
                        amount: new D(grandTotal),
                        createdAt: placedAt,
                      },
                      {
                        event: 'succeeded',
                        status: PaymentStatus.PAID,
                        currency: Currency.SYP,
                        amount: new D(grandTotal),
                        createdAt: new Date(placedAt.getTime() + 3.6e6),
                      },
                    ]
                  : [
                      {
                        event: 'initiated',
                        status: PaymentStatus.PENDING,
                        currency: Currency.SYP,
                        amount: new D(grandTotal),
                        createdAt: placedAt,
                      },
                    ],
              },
            },
          },
        },
      });

      if (coupon) {
        await prisma.couponRedemption.create({
          data: {
            couponId: coupon.id,
            userId: customer.id,
            orderId: order.id,
            currency: Currency.SYP,
            amount: new D(discountTotal),
            createdAt: placedAt,
          },
        });
      }

      await prisma.orderEvent.create({
        data: {
          orderId: order.id,
          toStatus: OrderStatus.PENDING_PAYMENT,
          actorId: customer.id,
          actorRole: 'CUSTOMER',
          title: 'تم إنشاء الطلب',
          description: `طلب ${number} بانتظار الدفع`,
          createdAt: placedAt,
        },
      });
      if (plan.status !== OrderStatus.PENDING_PAYMENT) {
        await prisma.orderEvent.create({
          data: {
            orderId: order.id,
            fromStatus: OrderStatus.PENDING_PAYMENT,
            toStatus: plan.status,
            actorRole: 'SYSTEM',
            title: 'تم تحديث حالة الطلب',
            createdAt: new Date(placedAt.getTime() + 7.2e6),
          },
        });
      }

      // ── Sub-orders, one per boutique in the basket ───────────────────
      const bySeller = new Map<string, typeof lines>();
      for (const line of lines) {
        const group = bySeller.get(line.sellerId) ?? [];
        group.push(line);
        bySeller.set(line.sellerId, group);
      }

      const seededSubOrders: SeededOrder['sellerOrders'] = [];
      let subIndex = 0;

      for (const [sellerId, sellerLines] of bySeller.entries()) {
        subIndex += 1;
        const seller = ctx.sellers.find((row) => row.id === sellerId)!;
        // Multi-seller baskets walk the list in order, so a "partially
        // shipped" parent really does have one shipped and one preparing
        // sub-order; single-seller ones draw at random for spread.
        const subStatus = plan.multiSeller
          ? plan.subStatuses[(subIndex - 1) % plan.subStatuses.length]
          : rng.pick(plan.subStatuses);

        const subtotal = sellerLines.reduce(
          (total, line) => total + line.lineTotal,
          0,
        );
        const share = subtotal / itemsSubtotal;
        const subDiscount = roundSyp(discountTotal * share);
        // Q17 P1 — commission is charged on the post-discount price.
        const commissionBase = subtotal - subDiscount;
        const bps = COMMISSION_BPS[seller.level] ?? 1000;
        const commissionAmount = roundSyp((commissionBase * bps) / 10_000);
        const sellerNet = commissionBase - commissionAmount;

        // Everything after-sales implies the parcel reached the customer, so
        // those sub-orders carry a delivery date, a shipment and a commission
        // ledger entry just like a plain DELIVERED one.
        const delivered = (
          [
            SellerOrderStatus.DELIVERED,
            SellerOrderStatus.RETURNED,
            SellerOrderStatus.REFUNDED,
            SellerOrderStatus.RETURN_REQUESTED,
            SellerOrderStatus.RETURN_IN_TRANSIT,
            SellerOrderStatus.EXCHANGE_IN_PROGRESS,
            SellerOrderStatus.EXCHANGED,
            SellerOrderStatus.REFUND_PENDING,
            SellerOrderStatus.DISPUTED,
          ] as SellerOrderStatus[]
        ).includes(subStatus);
        const deliveredAt = delivered
          ? new Date(placedAt.getTime() + rng.int(24, 96) * 3.6e6)
          : null;
        const shipped =
          delivered ||
          (
            [
              SellerOrderStatus.IN_TRANSIT,
              SellerOrderStatus.HANDED_TO_COURIER,
              SellerOrderStatus.DELIVERY_FAILED,
              SellerOrderStatus.REJECTED_ON_DELIVERY,
            ] as SellerOrderStatus[]
          ).includes(subStatus);

        const sellerOrder = await prisma.sellerOrder.create({
          data: {
            number: `${number}-${subIndex}`,
            orderId: order.id,
            sellerId,
            status: subStatus,
            fulfilmentMode: rng.weighted([
              [FulfilmentMode.PLATFORM_COURIER, 6],
              [FulfilmentMode.SELLER_SHIPS, 2],
              [FulfilmentMode.PICKUP_POINT, 1],
            ]),
            currency: Currency.SYP,
            itemsSubtotal: new D(subtotal),
            discountTotal: new D(subDiscount),
            shippingCost: new D(roundSyp(shippingTotal * share)),
            commissionBase: new D(commissionBase),
            commissionAmount: new D(commissionAmount),
            sellerNet: new D(sellerNet),
            escrowReleaseAt: deliveredAt
              ? new Date(deliveredAt.getTime() + 7 * 864e5)
              : null,
            escrowReleased: deliveredAt
              ? Date.now() - deliveredAt.getTime() > 7 * 864e5
              : false,
            confirmedAt:
              subStatus === SellerOrderStatus.NEW
                ? null
                : new Date(placedAt.getTime() + 5.4e6),
            shippedAt: shipped
              ? new Date(placedAt.getTime() + rng.int(6, 30) * 3.6e6)
              : null,
            deliveredAt,
            closedAt:
              plan.status === OrderStatus.CLOSED ? deliveredAt : null,
            cancellationReason:
              subStatus === SellerOrderStatus.CANCELLED_BY_CUSTOMER
                ? 'طلبت الزبونة الإلغاء قبل الشحن'
                : subStatus === SellerOrderStatus.CANCELLED_BY_SELLER
                  ? 'الكمية غير متوفرة'
                  : null,
            createdAt: placedAt,
            items: {
              create: sellerLines.map((line) => ({
                offerId: line.offerId,
                productId: line.productId,
                variantId: line.variantId,
                titleSnapshot: line.title,
                imageSnapshot: line.imageUrl,
                variantSnapshot: line.variantName,
                sellerSnapshot: seller.store,
                currency: Currency.SYP,
                unitPrice: new D(line.unitPrice),
                quantity: line.quantity,
                lineTotal: new D(line.lineTotal),
              })),
            },
            events: {
              create: [
                {
                  toStatus: SellerOrderStatus.NEW,
                  actorRole: 'SYSTEM',
                  title: 'وصل طلب جديد',
                  createdAt: placedAt,
                },
                ...(subStatus === SellerOrderStatus.NEW
                  ? []
                  : [
                      {
                        fromStatus: SellerOrderStatus.NEW,
                        toStatus: subStatus,
                        actorRole: 'SELLER',
                        title: 'تم تحديث حالة التجهيز',
                        createdAt: new Date(placedAt.getTime() + 5.4e6),
                      },
                    ]),
              ],
            },
          },
          include: { items: true },
        });

        // ── Shipment ───────────────────────────────────────────────────
        if (shipped) {
          const courier =
            couriers.find((row) =>
              row.governorates.includes(customer.governorate),
            ) ?? couriers[0];
          const failed = subStatus === SellerOrderStatus.DELIVERY_FAILED;
          const shipmentStatus = failed
            ? ShipmentStatus.FAILED
            : delivered
              ? ShipmentStatus.DELIVERED
              : ShipmentStatus.IN_TRANSIT;

          const shipment = await prisma.shipment.create({
            data: {
              trackingCode: `TRK-${sellerOrder.number}`,
              sellerOrderId: sellerOrder.id,
              courierId: courier.id,
              zoneId: zone.id,
              status: shipmentStatus,
              currency: Currency.SYP,
              codAmount:
                method === PaymentMethodType.COD ? new D(grandTotal) : null,
              collectedAmount:
                method === PaymentMethodType.COD && delivered
                  ? new D(grandTotal)
                  : null,
              isExpress: rng.bool(0.2),
              pickedUpAt: new Date(placedAt.getTime() + 8.6e6),
              deliveredAt,
              maskedPhone: `${customer.phone.slice(0, 7)}****`,
              attemptCount: failed ? 2 : 1,
              failureReason: failed
                ? rng.pick([
                    DeliveryFailureReason.NO_ANSWER,
                    DeliveryFailureReason.WRONG_ADDRESS,
                    DeliveryFailureReason.POSTPONED,
                  ])
                : null,
              failureNote: failed ? 'لم يتم الرد بعد محاولتين' : null,
              createdAt: placedAt,
            },
          });

          const track: { status: ShipmentStatus; note: string }[] = [
            { status: ShipmentStatus.CREATED, note: 'تم إنشاء الشحنة' },
            { status: ShipmentStatus.ASSIGNED, note: 'تم إسناد الشحنة للمندوب' },
            { status: ShipmentStatus.PICKED_UP, note: 'تم استلام الطلب من البائعة' },
            { status: ShipmentStatus.IN_TRANSIT, note: 'الشحنة في الطريق' },
          ];
          if (delivered) {
            track.push({
              status: ShipmentStatus.OUT_FOR_DELIVERY,
              note: 'خرجت للتسليم',
            });
            track.push({ status: ShipmentStatus.DELIVERED, note: 'تم التسليم' });
          }
          if (failed) {
            track.push({
              status: ShipmentStatus.FAILED,
              note: 'تعذّر التسليم — لم يتم الرد',
            });
          }

          for (const [step, event] of track.entries()) {
            await prisma.shipmentEvent.create({
              data: {
                shipmentId: shipment.id,
                status: event.status,
                note: event.note,
                createdAt: new Date(placedAt.getTime() + (step + 1) * 7.2e6),
              },
            });
          }
        }

        // ── Commission + financial ledger ──────────────────────────────
        if (delivered) {
          const rule =
            rules.find(
              (row) => row.sellerTier === seller.level && row.active,
            ) ?? rules.find((row) => !row.sellerTier);

          await prisma.commissionLedger.create({
            data: {
              ruleId: rule?.id ?? null,
              sellerOrderId: sellerOrder.id,
              sellerId,
              currency: Currency.SYP,
              gross: new D(commissionBase),
              commission: new D(commissionAmount),
              platformFee: new D(0),
              net: new D(sellerNet),
              status:
                Date.now() - (deliveredAt?.getTime() ?? 0) > 14 * 864e5
                  ? CommissionStatus.PAID
                  : CommissionStatus.EARNED,
              paidAt:
                Date.now() - (deliveredAt?.getTime() ?? 0) > 14 * 864e5
                  ? new Date((deliveredAt?.getTime() ?? 0) + 10 * 864e5)
                  : null,
              createdAt: deliveredAt ?? placedAt,
            },
          });

          await prisma.financialLedgerEntry.createMany({
            data: [
              {
                type: FinancialLedgerType.ORDER_REVENUE,
                orderId: order.id,
                sellerId,
                userId: customer.id,
                amount: new D(commissionBase),
                currency: Currency.SYP,
                description: `إيراد الطلب ${sellerOrder.number}`,
                createdAt: deliveredAt ?? placedAt,
              },
              {
                type: FinancialLedgerType.COMMISSION,
                orderId: order.id,
                sellerId,
                amount: new D(commissionAmount),
                currency: Currency.SYP,
                description: `عمولة المنصة على ${sellerOrder.number}`,
                createdAt: deliveredAt ?? placedAt,
              },
            ],
          });
        }

        seededSubOrders.push({
          id: sellerOrder.id,
          sellerId,
          status: subStatus,
          net: sellerNet,
          gross: commissionBase,
          commission: commissionAmount,
          deliveredAt,
          items: sellerOrder.items.map((item) => ({
            id: item.id,
            productId: item.productId!,
            quantity: item.quantity,
            lineTotal: Number(item.lineTotal),
          })),
        });
      }

      orders.push({
        id: order.id,
        number,
        customerId: customer.id,
        status: plan.status,
        placedAt,
        grandTotal,
        couponCode: coupon?.code ?? null,
        discountTotal,
        sellerOrders: seededSubOrders,
      });
    }
  }

  await seedReturnsAndDisputes(ctx, orders);
  await seedCourierSettlements(ctx, couriers);

  return orders;
}

interface PlannedLine {
  sellerId: string;
  offerId: string;
  productId: string;
  variantId: string | null;
  variantName: string | null;
  title: string;
  imageUrl: string;
  unitPrice: number;
  quantity: number;
  lineTotal: number;
}

function pickLines(
  ctx: DemoContext,
  sellable: DemoProduct[],
  multiSeller: boolean,
): PlannedLine[] {
  const { rng } = ctx;
  const lines: PlannedLine[] = [];

  // A "partially shipped" order is only meaningful when two boutiques are in
  // the basket, so that case picks the second line by seller rather than by
  // product and gives up only if the catalog genuinely cannot supply one.
  let chosen = rng.sample(sellable, multiSeller ? 2 : rng.int(1, 3));
  const forcedOffers = new Map<string, string>();
  if (multiSeller) {
    const first = chosen[0];
    const firstSeller = first.offers[0].sellerId;
    const second = rng
      .shuffle(sellable)
      .find(
        (product) =>
          product.id !== first.id &&
          product.offers.some((offer) => offer.sellerId !== firstSeller),
      );
    if (!second) return [];
    forcedOffers.set(first.id, first.offers[0].id);
    forcedOffers.set(
      second.id,
      second.offers.find((offer) => offer.sellerId !== firstSeller)!.id,
    );
    chosen = [first, second];
  }

  for (const product of chosen) {
    const forced = forcedOffers.get(product.id);
    const offer = forced
      ? product.offers.find((row) => row.id === forced)!
      : rng.pick(product.offers);
    const variant = offer.variants.length ? rng.pick(offer.variants) : null;
    const quantity = rng.weighted([
      [1, 8],
      [2, 3],
      [3, 1],
    ]);
    lines.push({
      sellerId: offer.sellerId,
      offerId: offer.id,
      productId: product.id,
      variantId: variant?.id ?? null,
      variantName: variant?.name ?? null,
      title: product.title,
      imageUrl: product.imageUrl,
      unitPrice: offer.priceSyp,
      quantity,
      lineTotal: offer.priceSyp * quantity,
    });
  }

  return lines;
}

/** Returns, exchanges and disputes — Q67 P1's cost-bearer rules in practice. */
async function seedReturnsAndDisputes(
  ctx: DemoContext,
  orders: SeededOrder[],
): Promise<void> {
  const { prisma, rng } = ctx;

  const returnable = orders.filter((order) =>
    order.sellerOrders.some(
      (sub) =>
        sub.status === SellerOrderStatus.RETURNED ||
        sub.status === SellerOrderStatus.REFUNDED ||
        sub.status === SellerOrderStatus.DELIVERED,
    ),
  );

  let counter = 0;
  for (const order of rng.sample(returnable, 7)) {
    const sub = order.sellerOrders[0];
    if (!sub || sub.items.length === 0) continue;
    counter += 1;

    const reason = rng.pick([
      ReturnReason.SIZE_ISSUE,
      ReturnReason.NOT_AS_DESCRIBED,
      ReturnReason.DEFECTIVE,
      ReturnReason.CHANGED_MIND,
      ReturnReason.DAMAGED_IN_TRANSIT,
    ]);
    // The customer pays the return leg only when they simply changed their mind.
    const bearer =
      reason === ReturnReason.CHANGED_MIND ||
      reason === ReturnReason.SIZE_ISSUE
        ? ReturnCostBearer.CUSTOMER
        : ReturnCostBearer.SELLER;

    const status = rng.weighted<ReturnStatus>([
      [ReturnStatus.REFUNDED, 3],
      [ReturnStatus.APPROVED, 2],
      [ReturnStatus.REQUESTED, 2],
      [ReturnStatus.IN_TRANSIT, 1],
      [ReturnStatus.REJECTED, 1],
    ]);

    const item = sub.items[0];
    await prisma.returnRequest.create({
      data: {
        number: `RET-${order.number.slice(5)}-${counter}`,
        sellerOrderId: sub.id,
        requestedById: order.customerId,
        reason,
        reasonNote: 'القياس لا يناسبني، أرغب بالاستبدال أو الإرجاع.',
        status,
        resolution:
          status === ReturnStatus.REFUNDED
            ? ReturnResolution.REFUND_TO_WALLET
            : ReturnResolution.NONE,
        shippingBorneBy: bearer,
        currency: Currency.SYP,
        refundAmount:
          status === ReturnStatus.REFUNDED ? new D(item.lineTotal) : null,
        windowClosesAt: new Date(
          (sub.deliveredAt ?? order.placedAt).getTime() + 7 * 864e5,
        ),
        decidedById: status === ReturnStatus.REQUESTED ? null : ctx.adminId,
        decidedAt: status === ReturnStatus.REQUESTED ? null : rng.pastDate(10),
        createdAt: rng.pastDate(20, 1),
        items: {
          create: [{ orderItemId: item.id, quantity: 1 }],
        },
      },
    });

    if (status === ReturnStatus.REFUNDED) {
      await prisma.financialLedgerEntry.create({
        data: {
          type: FinancialLedgerType.REFUND,
          orderId: order.id,
          sellerId: sub.sellerId,
          userId: order.customerId,
          amount: new D(item.lineTotal),
          currency: Currency.SYP,
          description: `استرجاع مبلغ الطلب ${order.number}`,
        },
      });
      await prisma.payment.updateMany({
        where: { orderId: order.id },
        data: { refundedAmount: new D(item.lineTotal) },
      });
    }

    // Two of the returns escalate into disputes.
    if (counter <= 2) {
      const dispute = await prisma.dispute.create({
        data: {
          number: `DSP-${order.number.slice(5)}`,
          sellerOrderId: sub.id,
          openedById: order.customerId,
          status:
            counter === 1
              ? DisputeStatus.UNDER_REVIEW
              : DisputeStatus.RESOLVED_FOR_CUSTOMER,
          subject: `نزاع حول الطلب ${order.number}`,
          currency: Currency.SYP,
          frozenAmount: new D(item.lineTotal),
          dueAt: rng.futureDate(10, 2),
          decisionNote:
            counter === 1 ? null : 'تمت إعادة المبلغ للزبونة بعد مراجعة الأدلة.',
          decidedById: counter === 1 ? null : ctx.adminId,
          decidedAt: counter === 1 ? null : rng.pastDate(5),
          createdAt: rng.pastDate(15, 3),
        },
      });

      await prisma.disputeMessage.createMany({
        data: [
          {
            disputeId: dispute.id,
            authorId: order.customerId,
            body: 'المنتج وصل مختلفاً عن الوصف، أرفقت الصور.',
            createdAt: rng.pastDate(14, 3),
          },
          {
            disputeId: dispute.id,
            authorId: sub.sellerId,
            body: 'تم شحن القطعة الصحيحة، سنراجع الأمر مع المندوب.',
            createdAt: rng.pastDate(12, 2),
          },
          {
            disputeId: dispute.id,
            authorId: ctx.adminId,
            body: 'بانتظار رد البائعة خلال ٤٨ ساعة.',
            isInternal: true,
            createdAt: rng.pastDate(10, 1),
          },
        ],
      });
    }
  }
}

/** Q59 P1 — COD cash has to be reconciled with the courier every day. */
async function seedCourierSettlements(
  ctx: DemoContext,
  couriers: { id: string }[],
): Promise<void> {
  const { prisma, rng } = ctx;

  for (const courier of couriers) {
    for (let day = 1; day <= 5; day += 1) {
      const periodDate = new Date(Date.now() - day * 864e5);
      periodDate.setHours(0, 0, 0, 0);
      const expected = roundSyp(rng.int(4_000, 40_000));
      const collected = rng.bool(0.75)
        ? expected
        : roundSyp(expected * rng.float(0.8, 0.98, 3));

      await prisma.cashSettlement.create({
        data: {
          courierId: courier.id,
          periodDate,
          currency: Currency.SYP,
          expected: new D(expected),
          collected: new D(collected),
          variance: new D(collected - expected),
          settledAt: collected === expected ? periodDate : null,
          settledById: collected === expected ? ctx.adminId : null,
          note: collected === expected ? null : 'فرق بانتظار التسوية',
        },
      });
    }
  }
}

/**
 * Reviews are written only by customers who actually received the item, plus a
 * thin layer of unverified ones — which is what `verified_purchase` on the
 * review card is meant to distinguish.
 */
export async function seedReviews(
  ctx: DemoContext,
  orders: SeededOrder[],
  communityIds: string[],
): Promise<void> {
  const { prisma, rng } = ctx;

  const delivered = orders.filter((order) =>
    order.sellerOrders.some((sub) => sub.deliveredAt !== null),
  );

  // (product, customer) and (seller, customer) pairs are unique per order, and
  // the same shopper can buy the same product twice — dedupe before writing.
  const productSeen = new Set<string>();
  const sellerSeen = new Set<string>();

  for (const order of delivered) {
    for (const sub of order.sellerOrders) {
      if (!sub.deliveredAt) continue;
      if (!rng.bool(0.72)) continue;

      for (const item of sub.items) {
        const key = `${item.productId}:${order.customerId}`;
        if (productSeen.has(key)) continue;
        productSeen.add(key);

        const positive = rng.bool(0.8);
        const rating = positive ? rng.int(4, 5) : rng.int(2, 3);
        await prisma.productReview.create({
          data: {
            productId: item.productId,
            userId: order.customerId,
            orderId: order.id,
            rating,
            title: rng.pick(REVIEW_TITLES),
            body: positive
              ? rng.pick(REVIEW_BODIES_POSITIVE)
              : rng.pick(REVIEW_BODIES_MIXED),
            verifiedPurchase: true,
            status: ReviewStatus.APPROVED,
            helpfulCount: rng.int(0, 24),
            createdAt: new Date(
              sub.deliveredAt.getTime() + rng.int(1, 10) * 864e5,
            ),
          },
        });
      }

      const sellerKey = `${sub.sellerId}:${order.customerId}`;
      if (sellerSeen.has(sellerKey)) continue;
      sellerSeen.add(sellerKey);

      const rating = rng.weighted([
        [5, 6],
        [4, 3],
        [3, 1],
      ]);
      await prisma.sellerReview.create({
        data: {
          sellerId: sub.sellerId,
          userId: order.customerId,
          orderId: order.id,
          rating,
          title: rng.pick(REVIEW_TITLES),
          body:
            rating >= 4
              ? rng.pick(REVIEW_BODIES_POSITIVE)
              : rng.pick(REVIEW_BODIES_MIXED),
          verifiedPurchase: true,
          status: ReviewStatus.APPROVED,
          createdAt: new Date(
            sub.deliveredAt.getTime() + rng.int(1, 8) * 864e5,
          ),
        },
      });
    }
  }

  // Unverified reviews from the community, spread over the whole catalog.
  // Every purchasable product gets a handful: a catalog where two thirds of
  // the cards show a zero rating is not a catalog anyone can evaluate, and
  // "no reviews yet" is already covered by the products left out below.
  for (const product of ctx.products) {
    if (rng.bool(0.08)) continue; // a slice stays genuinely unreviewed

    for (const userId of rng.sample(communityIds, rng.int(2, 7))) {
      const key = `${product.id}:${userId}`;
      if (productSeen.has(key)) continue;
      productSeen.add(key);

      const status = rng.weighted<ReviewStatus>([
        [ReviewStatus.APPROVED, 14],
        [ReviewStatus.PENDING, 2],
        [ReviewStatus.FLAGGED, 1],
      ]);
      const positive = rng.bool(0.78);
      const review = await prisma.productReview.create({
        data: {
          productId: product.id,
          userId,
          rating: positive ? rng.int(4, 5) : rng.int(2, 4),
          title: rng.pick(REVIEW_TITLES),
          body: positive
            ? rng.pick(REVIEW_BODIES_POSITIVE)
            : rng.pick(REVIEW_BODIES_MIXED),
          verifiedPurchase: false,
          status,
          helpfulCount: rng.int(0, 8),
          createdAt: rng.pastDate(90),
        },
      });

      // Only the reviews that were actually acted on get a moderation log —
      // the PENDING ones are what fills the admin queue.
      if (status !== ReviewStatus.PENDING && rng.bool(0.25)) {
        await prisma.reviewModerationLog.create({
          data: {
            moderatorId: ctx.adminId,
            targetType: 'PRODUCT',
            productReviewId: review.id,
            fromStatus: ReviewStatus.PENDING,
            toStatus: status,
            reason:
              status === ReviewStatus.FLAGGED
                ? 'يحتاج مراجعة إضافية'
                : 'مطابق لشروط النشر',
            createdAt: rng.pastDate(60),
          },
        });
      }
    }
  }
}

/**
 * Records what the platform owes on the points it just handed out.
 *
 * The seed minted `PointsTransaction` rows straight into the database, which
 * is fine for the rewards screen and wrong for the books: a point is a promise
 * to hand over credit later, so it belongs on the balance sheet the moment it
 * is granted. Without this the `LOYALTY_LIABILITY` account sat at zero until
 * the first shopper converted points in the app — and then went *negative*,
 * because a conversion debits a liability nobody had ever credited. The
 * finance console reported the books unsound, correctly.
 *
 * One accrual per shopper, for the credit her outstanding balance can actually
 * be converted into (points only convert in tens), posted through the same
 * `LedgerService` the app uses so the entry is shaped exactly like a real one.
 */
async function accrueLoyaltyLiability(
  ctx: DemoContext,
  balances: Map<string, number>,
): Promise<void> {
  const ledger = new LedgerService(ctx.prisma as unknown as PrismaService);

  for (const [userId, points] of balances.entries()) {
    const convertible =
      Math.floor(points / POINTS_PER_REDEMPTION) * SYP_PER_REDEMPTION;
    if (convertible <= 0) continue;

    const owed = Money.of(convertible, Currency.SYP);
    await ledger.post({
      type: JournalEntryType.LOYALTY_ACCRUED,
      reference: `demo:loyalty-accrue:${userId}`,
      description: 'نقاط ولاء ممنوحة',
      lines: [
        {
          account: { code: LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE },
          direction: LedgerDirection.DEBIT,
          amount: owed,
          memo: `${points} point(s)`,
        },
        {
          account: { code: LedgerAccountCode.LOYALTY_LIABILITY },
          direction: LedgerDirection.CREDIT,
          amount: owed,
        },
      ],
    });
  }
}

/** Points, cashback and the weekly payout run that follows delivered orders. */
export async function seedMoneyMovements(
  ctx: DemoContext,
  orders: SeededOrder[],
): Promise<void> {
  const { prisma, rng } = ctx;

  // ── Loyalty points: earned on delivery, occasionally redeemed ────────
  const balances = new Map<string, number>();
  const delivered = orders
    .filter((order) => order.sellerOrders.some((sub) => sub.deliveredAt))
    .sort((a, b) => a.placedAt.getTime() - b.placedAt.getTime());

  for (const order of delivered) {
    const earned = Math.max(1, Math.round(order.grandTotal / SYP_PER_POINT));
    const balance = (balances.get(order.customerId) ?? 0) + earned;
    balances.set(order.customerId, balance);

    await prisma.pointsTransaction.create({
      data: {
        userId: order.customerId,
        type: PointsTransactionType.EARN,
        points: earned,
        reason: `نقاط الطلب ${order.number}`,
        orderId: order.id,
        balanceAfter: balance,
        expiresAt: new Date(order.placedAt.getTime() + 365 * 864e5),
        createdAt: order.placedAt,
      },
    });

    const customer = ctx.customers.find((row) => row.id === order.customerId);
    if (customer && FREE_SHIPPING_TIERS.includes(customer.tier)) {
      await prisma.cashbackLedger.create({
        data: {
          userId: order.customerId,
          orderId: order.id,
          currency: Currency.SYP,
          amount: new D(roundSyp(order.grandTotal * 0.02)),
          status: rng.weighted<CashbackStatus>([
            [CashbackStatus.EARNED, 5],
            [CashbackStatus.REDEEMED, 2],
            [CashbackStatus.PENDING, 1],
          ]),
          expiresAt: new Date(order.placedAt.getTime() + 180 * 864e5),
          createdAt: order.placedAt,
        },
      });
    }

    if (rng.bool(0.18) && balance > 60) {
      const redeemed = Math.min(balance, rng.int(20, 60));
      const after = balance - redeemed;
      balances.set(order.customerId, after);
      await prisma.pointsTransaction.create({
        data: {
          userId: order.customerId,
          type: PointsTransactionType.REDEEM,
          points: -redeemed,
          reason: 'استبدال نقاط بخصم',
          balanceAfter: after,
          createdAt: new Date(order.placedAt.getTime() + 2 * 864e5),
        },
      });
    }
  }

  for (const [userId, points] of balances.entries()) {
    await prisma.user.update({ where: { id: userId }, data: { points } });
  }

  await accrueLoyaltyLiability(ctx, balances);

  // ── Weekly payouts over the paid commission ledgers (Q19 P1) ─────────
  for (const seller of ctx.sellers) {
    const ledgers = await prisma.commissionLedger.findMany({
      where: { sellerId: seller.id, status: CommissionStatus.PAID },
      orderBy: { createdAt: 'asc' },
    });
    if (ledgers.length === 0) continue;

    for (let start = 0; start < ledgers.length; start += 4) {
      const batch = ledgers.slice(start, start + 4);
      const gross = batch.reduce((sum, row) => sum + Number(row.gross), 0);
      const commission = batch.reduce(
        (sum, row) => sum + Number(row.commission),
        0,
      );
      const net = gross - commission;
      const periodStart = batch[0].createdAt;
      const periodEnd = new Date(
        batch[batch.length - 1].createdAt.getTime() + 864e5,
      );
      const status = rng.weighted<PayoutStatus>([
        [PayoutStatus.PAID, 5],
        [PayoutStatus.APPROVED, 2],
        [PayoutStatus.PENDING, 1],
      ]);

      const payout = await prisma.sellerPayout.create({
        data: {
          sellerId: seller.id,
          periodStart,
          periodEnd,
          gross: new D(gross),
          commission: new D(commission),
          platformFees: new D(0),
          net: new D(net),
          currency: Currency.SYP,
          status,
          reference: status === PayoutStatus.PAID ? `PAYOUT-${start}-${seller.id.slice(0, 6)}` : null,
          approvedAt:
            status === PayoutStatus.PENDING ? null : new Date(periodEnd),
          paidAt:
            status === PayoutStatus.PAID
              ? new Date(periodEnd.getTime() + 2 * 864e5)
              : null,
          createdAt: periodEnd,
        },
      });

      await prisma.sellerPayoutLedger.createMany({
        data: batch.map((row) => ({ payoutId: payout.id, ledgerId: row.id })),
      });

      if (status === PayoutStatus.PAID) {
        await prisma.financialLedgerEntry.create({
          data: {
            type: FinancialLedgerType.PAYOUT,
            sellerId: seller.id,
            amount: new D(net),
            currency: Currency.SYP,
            description: `تحويل مستحقات ${seller.store}`,
            createdAt: new Date(periodEnd.getTime() + 2 * 864e5),
          },
        });
      }
    }
  }
}
