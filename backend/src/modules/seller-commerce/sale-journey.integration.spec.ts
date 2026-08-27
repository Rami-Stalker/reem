import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CourierKind,
  Currency,
  DeliveryFailureReason,
  FulfilmentMode,
  LedgerAccountCode,
  OrderStatus,
  PaymentMethodType,
  PaymentStatus,
  PrismaClient,
  ReturnReason,
  SellerOrderStatus,
  ShipmentStatus,
  UserRole,
} from '@prisma/client';

import { AuthUser } from '../../common/decorators/current-user.decorator';
import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { CommissionsService } from '../commissions/commissions.service';
import { DisputesService } from '../finance/disputes.service';
import { CustomerRefundsService } from '../finance/customer-refunds.service';
import { FinancialAuditService } from '../finance/financial-audit.service';
import { LoyaltyService } from '../finance/loyalty.service';
import { ShipmentsService } from '../delivery/shipments.service';
import { LedgerService } from '../ledger/ledger.service';
import { WalletService } from '../ledger/wallet.service';
import { SellerOrderWorkflowService } from '../orders/workflow/seller-order-workflow.service';
import { ReturnRefundsService } from '../returns/return-refunds.service';
import { ReturnsService } from '../returns/returns.service';
import { SellerOrdersService } from './seller-orders.service';

/**
 * One sale, from the seller's queue to the customer's door.
 *
 * This is the journey the platform could not previously make: a paid parcel
 * arrived in `AWAITING_SELLER_CONFIRMATION` and nothing in the codebase could
 * move it, so no order ever reached `DELIVERED` — and everything that hangs off
 * that moment (the return window, the escrow clock, reviews, loyalty) was
 * unreachable in practice while looking perfectly implemented in isolation.
 *
 * The assertions therefore care less about each individual call succeeding
 * than about the *consequences* landing: the timestamps, the parent order, the
 * payment, the escrow clock and the fact that a return is possible at the end.
 */
const prisma = new PrismaClient();

class Rollback extends Error {}
type Tx = Parameters<Parameters<typeof prisma.$transaction>[0]>[0];

let reachable = false;

test.before(async () => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    reachable = true;
  } catch {
    reachable = false;
  }
});

function dbTest(name: string, body: (world: World) => Promise<void>): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    let failure: unknown;
    try {
      await prisma.$transaction(
        async (tx) => {
          try {
            await body(build(tx));
          } catch (error) {
            failure = error;
          }
          throw new Rollback();
        },
        { timeout: 60_000 },
      );
    } catch (error) {
      if (!(error instanceof Rollback)) throw error;
    }
    if (failure) throw failure;
  });
}

/** Nested transactions flattened onto the one the test rolls back. */
function asPrisma(tx: Tx): PrismaService {
  return new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (fn: (inner: Tx) => unknown) => fn(tx);
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
}

interface World {
  tx: Tx;
  ledger: LedgerService;
  wallets: WalletService;
  sellerOrders: SellerOrdersService;
  shipments: ShipmentsService;
  returns: ReturnsService;
  refunds: CustomerRefundsService;
}

const audit = {
  record: async () => {},
  recordBalanceChange: async () => {},
} as unknown as FinancialAuditService;

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const ledger = new LedgerService(db);
  const wallets = new WalletService(db, ledger);
  const loyalty = new LoyaltyService(db, ledger, wallets);
  const commissions = new CommissionsService(db, ledger, loyalty, audit);
  const workflow = new SellerOrderWorkflowService(db);
  const customerRefunds = new CustomerRefundsService(
    db,
    ledger,
    wallets,
    workflow,
    audit,
  );
  const sellerOrders = new SellerOrdersService(
    db,
    workflow,
    commissions,
    customerRefunds,
  );
  const shipments = new ShipmentsService(
    db,
    commissions,
    workflow,
    customerRefunds,
  );
  const refunds = new ReturnRefundsService(
    db,
    ledger,
    wallets,
    commissions,
    audit,
    customerRefunds,
  );
  const disputes = new DisputesService(db, ledger, wallets, audit);
  const returns = new ReturnsService(db, refunds, disputes, workflow);
  return {
    tx,
    ledger,
    wallets,
    sellerOrders,
    shipments,
    returns,
    refunds: customerRefunds,
  };
}

// ── Fixtures ────────────────────────────────────────────────────────────

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;
const syp = (value: string | number) => Money.of(value, Currency.SYP);

async function makeUser(tx: Tx, tag: string, role: UserRole = UserRole.CUSTOMER) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `sj-${tag}`,
      username: `sj_${u}`,
      phone: `+9639${u.slice(-8)}`,
      passwordHash: 'x',
      role,
    },
  });
}

const principal = (id: string, role: UserRole): AuthUser => ({
  id,
  phone: null,
  role,
});

interface SaleOptions {
  fulfilmentMode?: FulfilmentMode;
  method?: PaymentMethodType;
  paymentStatus?: PaymentStatus;
  withShipment?: boolean;
  privacyMask?: boolean;
}

/**
 * A paid order sitting exactly where checkout leaves it: confirmed, fanned out
 * to the seller, and waiting for someone to do something about it.
 */
async function makeSale(tx: Tx, options: SaleOptions = {}) {
  const mode = options.fulfilmentMode ?? FulfilmentMode.PLATFORM_COURIER;
  const method = options.method ?? PaymentMethodType.COD;
  const subtotal = syp('400000');
  const shipping = syp('25000');
  const net = syp('340000');

  const customer = await makeUser(tx, 'cus');
  const seller = await makeUser(tx, 'sel', UserRole.SELLER);

  const category = await tx.category.create({
    data: { slug: `cat-${uniq('c')}`, nameAr: 'تجربة', nameEn: 'Test' },
  });
  const product = await tx.product.create({
    data: {
      slug: `prod-${uniq('p')}`,
      title: 'عباءة مطرّزة',
      description: 'للاختبار',
      categoryId: category.id,
    },
  });
  const offer = await tx.sellerOffer.create({
    data: {
      productId: product.id,
      sellerId: seller.id,
      currency: Currency.SYP,
      price: '200000',
      stock: 8,
    },
  });

  const order = await tx.order.create({
    data: {
      number: `ORD-${uniq('o').slice(-12)}`,
      userId: customer.id,
      status: OrderStatus.CONFIRMED,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: subtotal.toPrisma(),
      shippingTotal: shipping.toPrisma(),
      grandTotal: subtotal.plus(shipping).toPrisma(),
      recipientName: 'ريم الدالي',
      recipientPhone: '+963900111222',
      governorate: 'دمشق',
      district: 'المزة',
      city: 'دمشق',
      addressLine: 'شارع الجلاء، بناء 12',
      landmark: 'قرب الصيدلية',
      privacyMaskEnabled: options.privacyMask ?? false,
      placedAt: new Date(),
      payment: {
        create: {
          method,
          status: options.paymentStatus ?? PaymentStatus.PENDING,
          currency: Currency.SYP,
          amount: subtotal.plus(shipping).toPrisma(),
        },
      },
    },
  });

  const sellerOrder = await tx.sellerOrder.create({
    data: {
      orderId: order.id,
      number: `${order.number}-1`,
      sellerId: seller.id,
      status: SellerOrderStatus.AWAITING_SELLER_CONFIRMATION,
      fulfilmentMode: mode,
      currency: Currency.SYP,
      itemsSubtotal: subtotal.toPrisma(),
      shippingCost: shipping.toPrisma(),
      commissionBase: subtotal.toPrisma(),
      commissionAmount: subtotal.minus(net).toPrisma(),
      sellerNet: net.toPrisma(),
      confirmedAt: new Date(),
      items: {
        create: {
          offerId: offer.id,
          productId: product.id,
          titleSnapshot: product.title,
          sellerSnapshot: 'أتيليه تجريبي',
          currency: Currency.SYP,
          unitPrice: '200000',
          quantity: 2,
          lineTotal: subtotal.toPrisma(),
        },
      },
    },
    include: { items: true },
  });

  let courierUser: { id: string } | null = null;
  let shipment: { id: string } | null = null;

  if (options.withShipment ?? mode === FulfilmentMode.PLATFORM_COURIER) {
    courierUser = await makeUser(tx, 'crr', UserRole.SELLER);
    const courier = await tx.courier.create({
      data: {
        userId: courierUser.id,
        kind: CourierKind.PLATFORM_STAFF,
        displayName: 'مندوب تجريبي',
        phone: '+963900333444',
        governorates: ['دمشق'],
      },
    });
    shipment = await tx.shipment.create({
      data: {
        trackingCode: `REM-${uniq('t').slice(-8).toUpperCase()}`,
        sellerOrderId: sellerOrder.id,
        courierId: courier.id,
        status: ShipmentStatus.ASSIGNED,
        currency: Currency.SYP,
        codAmount:
          method === PaymentMethodType.COD ? subtotal.toPrisma() : null,
      },
    });
  }

  return {
    customer: principal(customer.id, UserRole.CUSTOMER),
    seller: principal(seller.id, UserRole.SELLER),
    courierUserId: courierUser?.id ?? null,
    shipmentId: shipment?.id ?? null,
    customerId: customer.id,
    sellerId: seller.id,
    offerId: offer.id,
    order,
    sellerOrder,
    subtotal,
    shipping,
    net,
  };
}

const statusOf = async (tx: Tx, id: string) =>
  (await tx.sellerOrder.findUniqueOrThrow({ where: { id } })).status;

// ── The whole journey ───────────────────────────────────────────────────

dbTest(
  'a paid order travels from the seller queue to the customer door',
  async (world) => {
    const sale = await makeSale(world.tx);
    const { sellerOrders, shipments, tx } = world;

    // 1. It is waiting in her queue, and the queue says what she can do.
    const queue = await sellerOrders.queue(sale.seller, 'new', {
      page: 1,
      limit: 20,
      skip: 0,
    } as never);
    assert.equal(queue.counts.new >= 1, true);
    const row = queue.data.find((entry) => entry.id === sale.sellerOrder.id);
    assert.ok(row, 'the parcel is in the new tab');
    assert.deepEqual(row.available_actions, ['confirm', 'cancel']);

    // 2. She accepts and packs it.
    await sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
    assert.equal(
      await statusOf(tx, sale.sellerOrder.id),
      SellerOrderStatus.PREPARING,
    );

    await sellerOrders.ready(sale.seller, sale.sellerOrder.id);
    assert.equal(
      await statusOf(tx, sale.sellerOrder.id),
      SellerOrderStatus.READY_TO_SHIP,
    );

    // 3. The courier collects — and the parcel moves with the shipment.
    await shipments.pickUp(sale.shipmentId!, sale.courierUserId!);
    assert.equal(
      await statusOf(tx, sale.sellerOrder.id),
      SellerOrderStatus.HANDED_TO_COURIER,
    );
    const shipped = await tx.sellerOrder.findUniqueOrThrow({
      where: { id: sale.sellerOrder.id },
    });
    assert.notEqual(shipped.shippedAt, null);

    await shipments.outForDelivery(sale.shipmentId!, sale.courierUserId!);
    assert.equal(
      await statusOf(tx, sale.sellerOrder.id),
      SellerOrderStatus.IN_TRANSIT,
    );

    // The parent order follows its children without anyone writing it.
    const midway = await tx.order.findUniqueOrThrow({
      where: { id: sale.order.id },
    });
    assert.equal(midway.status, OrderStatus.SHIPPED);

    // 4. Delivered, with the cash collected at the door.
    await shipments.deliver({
      shipmentId: sale.shipmentId!,
      courierUserId: sale.courierUserId!,
      collected: sale.subtotal.toPrisma().toString(),
      proofImageUrl: 'https://media.reem.test/proof.jpg',
    });

    const delivered = await tx.sellerOrder.findUniqueOrThrow({
      where: { id: sale.sellerOrder.id },
    });
    assert.equal(delivered.status, SellerOrderStatus.DELIVERED);
    assert.notEqual(delivered.deliveredAt, null);

    // The escrow clock starts here — not at payment. Seven days from the door.
    assert.notEqual(delivered.escrowReleaseAt, null);
    const days =
      (delivered.escrowReleaseAt!.getTime() - delivered.deliveredAt!.getTime()) /
      86_400_000;
    assert.equal(Math.round(days), 7);

    // The cash-on-delivery order is paid now that its only parcel arrived.
    const payment = await tx.payment.findUniqueOrThrow({
      where: { orderId: sale.order.id },
    });
    assert.equal(payment.status, PaymentStatus.PAID);
    assert.equal(
      Money.of(payment.capturedAmount, Currency.SYP).toString(),
      sale.subtotal.toString(),
    );

    // And the money reached the books: the seller's net is in escrow.
    const escrow = await world.ledger.balanceOf(
      { code: LedgerAccountCode.SELLER_ESCROW, ownerId: sale.sellerId },
      Currency.SYP,
      tx,
    );
    assert.equal(escrow.toString(), sale.net.toString());

    // 5. Which is what finally makes a return possible at all.
    const eligibility = await world.returns.eligibility(
      sale.customer,
      sale.sellerOrder.id,
    );
    assert.equal(eligibility.is_window_open, true);
    assert.equal(eligibility.lines[0].change_of_mind.allowed, true);
  },
);

dbTest('the courier cannot collect a parcel nobody has packed', async (world) => {
  const sale = await makeSale(world.tx);

  await assert.rejects(
    () => world.shipments.pickUp(sale.shipmentId!, sale.courierUserId!),
    /not ready yet/,
  );

  // The shipment did not move either — one refusal, not a half-done handover.
  const shipment = await world.tx.shipment.findUniqueOrThrow({
    where: { id: sale.shipmentId! },
  });
  assert.equal(shipment.status, ShipmentStatus.ASSIGNED);
});

dbTest('a refusal at the door is not the same as a missed attempt', async (world) => {
  const sale = await makeSale(world.tx);
  await world.sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.ready(sale.seller, sale.sellerOrder.id);
  await world.shipments.pickUp(sale.shipmentId!, sale.courierUserId!);
  await world.shipments.outForDelivery(sale.shipmentId!, sale.courierUserId!);

  await world.shipments.failAttempt(
    sale.shipmentId!,
    sale.courierUserId!,
    DeliveryFailureReason.CUSTOMER_REFUSED,
    'رفضت الاستلام',
  );

  assert.equal(
    await statusOf(world.tx, sale.sellerOrder.id),
    SellerOrderStatus.REJECTED_ON_DELIVERY,
  );

  // Nothing is owed to the seller for a parcel that came back.
  const parcel = await world.tx.sellerOrder.findUniqueOrThrow({
    where: { id: sale.sellerOrder.id },
  });
  assert.equal(parcel.escrowReleaseAt, null);
  assert.notEqual(parcel.closedAt, null);
});

dbTest('a missed attempt leaves the parcel retriable', async (world) => {
  const sale = await makeSale(world.tx);
  await world.sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.ready(sale.seller, sale.sellerOrder.id);
  await world.shipments.pickUp(sale.shipmentId!, sale.courierUserId!);
  await world.shipments.outForDelivery(sale.shipmentId!, sale.courierUserId!);

  await world.shipments.failAttempt(
    sale.shipmentId!,
    sale.courierUserId!,
    DeliveryFailureReason.NO_ANSWER,
    'لم تجب',
  );

  assert.equal(
    await statusOf(world.tx, sale.sellerOrder.id),
    SellerOrderStatus.DELIVERY_FAILED,
  );
});

// ── The seller who ships it herself (Q57) ───────────────────────────────

dbTest('a seller carrying her own parcel completes the journey', async (world) => {
  const sale = await makeSale(world.tx, {
    fulfilmentMode: FulfilmentMode.SELLER_SHIPS,
    withShipment: false,
  });

  await world.sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.ready(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.handOver(sale.seller, sale.sellerOrder.id, 'بنفسها');
  await world.sellerOrders.deliver(sale.seller, sale.sellerOrder.id, {
    collected: sale.subtotal.toPrisma().toString(),
  });

  const delivered = await world.tx.sellerOrder.findUniqueOrThrow({
    where: { id: sale.sellerOrder.id },
  });
  assert.equal(delivered.status, SellerOrderStatus.DELIVERED);
  assert.notEqual(delivered.deliveredAt, null);

  const escrow = await world.ledger.balanceOf(
    { code: LedgerAccountCode.SELLER_ESCROW, ownerId: sale.sellerId },
    Currency.SYP,
    world.tx,
  );
  assert.equal(escrow.toString(), sale.net.toString());
});

dbTest('a seller cannot declare a courier parcel delivered', async (world) => {
  const sale = await makeSale(world.tx);
  await world.sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.ready(sale.seller, sale.sellerOrder.id);

  await assert.rejects(
    () => world.sellerOrders.deliver(sale.seller, sale.sellerOrder.id),
    /marked delivered by its courier/,
  );
});

// ── What she sees of the customer (Q44 / Q57) ───────────────────────────

dbTest('a courier parcel hides the address from the seller', async (world) => {
  const sale = await makeSale(world.tx);
  const detail = await world.sellerOrders.detail(
    sale.seller,
    sale.sellerOrder.id,
  );

  assert.equal(detail.customer.is_masked, true);
  assert.equal(detail.customer.phone, null);
  assert.equal(detail.customer.address_line, null);
  // Enough to greet her by and to know which city to pack for.
  assert.equal(detail.customer.name, 'ريم');
  assert.equal(detail.customer.governorate, 'دمشق');
});

dbTest('a self-shipped parcel gives the seller the door she has to reach', async (world) => {
  const sale = await makeSale(world.tx, {
    fulfilmentMode: FulfilmentMode.SELLER_SHIPS,
    withShipment: false,
  });
  const detail = await world.sellerOrders.detail(
    sale.seller,
    sale.sellerOrder.id,
  );

  assert.equal(detail.customer.is_masked, false);
  assert.equal(detail.customer.phone, '+963900111222');
  assert.equal(detail.customer.address_line, 'شارع الجلاء، بناء 12');
  assert.equal(detail.customer.name, 'ريم الدالي');
});

dbTest('the customer can ask for more privacy even when the seller ships', async (world) => {
  const sale = await makeSale(world.tx, {
    fulfilmentMode: FulfilmentMode.SELLER_SHIPS,
    withShipment: false,
    privacyMask: true,
  });
  const detail = await world.sellerOrders.detail(
    sale.seller,
    sale.sellerOrder.id,
  );

  // She still needs the address to deliver it — the name is what shrinks.
  assert.equal(detail.customer.name, 'ريم');
  assert.equal(detail.customer.address_line, 'شارع الجلاء، بناء 12');
  assert.equal(detail.customer.is_masked, true);
});

dbTest("a seller cannot open another seller's parcel", async (world) => {
  const sale = await makeSale(world.tx);
  const other = principal(
    (await makeUser(world.tx, 'oth', UserRole.SELLER)).id,
    UserRole.SELLER,
  );

  await assert.rejects(
    () => world.sellerOrders.detail(other, sale.sellerOrder.id),
    /Order not found/,
  );
});

// ── Cancelling ──────────────────────────────────────────────────────────

dbTest('a seller cancellation puts the stock back', async (world) => {
  const sale = await makeSale(world.tx);
  const before = await world.tx.sellerOffer.findUniqueOrThrow({
    where: { id: sale.offerId },
  });

  await world.sellerOrders.cancel(
    sale.seller,
    sale.sellerOrder.id,
    'نفد المقاس المطلوب',
  );

  const after = await world.tx.sellerOffer.findUniqueOrThrow({
    where: { id: sale.offerId },
  });
  assert.equal(after.stock, before.stock + 2);

  assert.equal(
    await statusOf(world.tx, sale.sellerOrder.id),
    SellerOrderStatus.CANCELLED_BY_SELLER,
  );

  // The parcel leaves the courier's round with it.
  const shipment = await world.tx.shipment.findUniqueOrThrow({
    where: { id: sale.shipmentId! },
  });
  assert.equal(shipment.status, ShipmentStatus.CANCELLED);

  // And the whole order is cancelled, since it had nothing else in it.
  const order = await world.tx.order.findUniqueOrThrow({
    where: { id: sale.order.id },
  });
  assert.equal(order.status, OrderStatus.CANCELLED);
});

dbTest('a delivered parcel can no longer be cancelled', async (world) => {
  const sale = await makeSale(world.tx, {
    fulfilmentMode: FulfilmentMode.SELLER_SHIPS,
    withShipment: false,
  });
  await world.sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.ready(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.handOver(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.deliver(sale.seller, sale.sellerOrder.id);

  await assert.rejects(
    () =>
      world.sellerOrders.cancel(sale.seller, sale.sellerOrder.id, 'غيرت رأيي'),
    /Cannot move a sub-order from DELIVERED/,
  );
});

// ── The timeline both sides read ────────────────────────────────────────

dbTest('every step lands on the order timeline', async (world) => {
  const sale = await makeSale(world.tx);
  await world.sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.ready(sale.seller, sale.sellerOrder.id);
  await world.shipments.pickUp(sale.shipmentId!, sale.courierUserId!);
  await world.shipments.outForDelivery(sale.shipmentId!, sale.courierUserId!);
  await world.shipments.deliver({
    shipmentId: sale.shipmentId!,
    courierUserId: sale.courierUserId!,
  });

  const events = await world.tx.orderEvent.findMany({
    where: { sellerOrderId: sale.sellerOrder.id },
    orderBy: { createdAt: 'asc' },
  });

  assert.deepEqual(
    events.map((event) => event.toStatus),
    [
      SellerOrderStatus.PREPARING,
      SellerOrderStatus.READY_TO_SHIP,
      SellerOrderStatus.HANDED_TO_COURIER,
      SellerOrderStatus.IN_TRANSIT,
      SellerOrderStatus.DELIVERED,
    ],
  );

  // The courier's steps are recorded as the courier's, not as the seller
  // account their login happens to use.
  const handover = events.find(
    (event) => event.toStatus === SellerOrderStatus.HANDED_TO_COURIER,
  );
  assert.equal(handover?.actorRole, 'COURIER');
});

// ── Returns, now that a parcel can actually be delivered ────────────────

dbTest('the customer can return what she received', async (world) => {
  const sale = await makeSale(world.tx);
  await world.sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.ready(sale.seller, sale.sellerOrder.id);
  await world.shipments.pickUp(sale.shipmentId!, sale.courierUserId!);
  await world.shipments.outForDelivery(sale.shipmentId!, sale.courierUserId!);
  await world.shipments.deliver({
    shipmentId: sale.shipmentId!,
    courierUserId: sale.courierUserId!,
    collected: sale.subtotal.toPrisma().toString(),
  });

  const request = await world.returns.request(sale.customer, {
    sellerOrderId: sale.sellerOrder.id,
    reason: ReturnReason.CHANGED_MIND,
    items: [{ orderItemId: sale.sellerOrder.items[0].id, quantity: 1 }],
  });

  assert.match(request.number, /^RET-/);
  // A partial return leaves the parcel delivered, because it was.
  assert.equal(
    await statusOf(world.tx, sale.sellerOrder.id),
    SellerOrderStatus.DELIVERED,
  );
});

// ── Cancelling a parcel that was already paid for ───────────────────────

dbTest('a prepaid parcel cancelled by the seller pays the customer back', async (world) => {
  const sale = await makeSale(world.tx, {
    method: PaymentMethodType.SYRIATEL_CASH,
    paymentStatus: PaymentStatus.PAID,
  });

  // What the provider's capture leaves behind: cash in, against a receivable
  // that settlement would later have discharged.
  const receivableBefore = await world.ledger.balanceOf(
    { code: LedgerAccountCode.GATEWAY_RECEIVABLE },
    Currency.SYP,
    world.tx,
  );

  await world.sellerOrders.cancel(
    sale.seller,
    sale.sellerOrder.id,
    'نفد المقاس المطلوب',
  );

  // She gets the goods *and* the delivery fee back: it was the only parcel in
  // the basket, so the van is not going out at all.
  const wallet = await world.wallets.balanceOf(sale.customerId);
  assert.equal(
    wallet.toString(),
    sale.subtotal.plus(sale.shipping).toString(),
  );

  // And the payment is unwound where it actually sat.
  const receivableAfter = await world.ledger.balanceOf(
    { code: LedgerAccountCode.GATEWAY_RECEIVABLE },
    Currency.SYP,
    world.tx,
  );
  assert.equal(
    receivableAfter.minus(receivableBefore).toString(),
    sale.subtotal.plus(sale.shipping).toString(),
  );

  // The parcel is closed, not left promising a refund nobody pays.
  assert.equal(
    await statusOf(world.tx, sale.sellerOrder.id),
    SellerOrderStatus.REFUNDED,
  );
});

dbTest('a cash-on-delivery cancellation refunds nothing, and says so', async (world) => {
  const sale = await makeSale(world.tx);

  await world.sellerOrders.cancel(
    sale.seller,
    sale.sellerOrder.id,
    'لا أستطيع التجهيز بالوقت المطلوب',
  );

  // She never paid, so there is nothing to give back — and the parcel still
  // closes rather than waiting for ever on a refund that cannot happen.
  const wallet = await world.wallets.balanceOf(sale.customerId);
  assert.equal(wallet.isZero(), true);
  assert.equal(
    await statusOf(world.tx, sale.sellerOrder.id),
    SellerOrderStatus.CANCELLED_BY_SELLER,
  );
});

dbTest('a refund is paid once, however many times it is asked for', async (world) => {
  const sale = await makeSale(world.tx, {
    method: PaymentMethodType.SYRIATEL_CASH,
    paymentStatus: PaymentStatus.PAID,
  });

  await world.sellerOrders.cancel(sale.seller, sale.sellerOrder.id, 'نفد المقاس');
  const afterFirst = await world.wallets.balanceOf(sale.customerId);

  // The sweep runs over everything; a parcel it has already paid must answer
  // "nothing owed" rather than pay again.
  const second = await world.refunds.refundUndeliveredParcel(
    sale.sellerOrder.id,
    null,
  );
  assert.equal(second.refunded.isZero(), true);

  const afterSecond = await world.wallets.balanceOf(sale.customerId);
  assert.equal(afterSecond.toString(), afterFirst.toString());
});

dbTest('the delivery fee is not refunded while the basket lives on', async (world) => {
  const sale = await makeSale(world.tx, {
    method: PaymentMethodType.SYRIATEL_CASH,
    paymentStatus: PaymentStatus.PAID,
  });

  // A second seller's parcel in the same basket, still going out.
  const otherSeller = await makeUser(world.tx, 'sel2', UserRole.SELLER);
  await world.tx.sellerOrder.create({
    data: {
      orderId: sale.order.id,
      number: `${sale.order.number}-2`,
      sellerId: otherSeller.id,
      status: SellerOrderStatus.PREPARING,
      currency: Currency.SYP,
      itemsSubtotal: '100000',
      shippingCost: '0',
      commissionBase: '100000',
      commissionAmount: '15000',
      sellerNet: '85000',
    },
  });

  await world.sellerOrders.cancel(sale.seller, sale.sellerOrder.id, 'نفد المقاس');

  // She paid for delivery once (Q65) and the van is still coming, so only the
  // goods come back. Refunding a share of the fee would be a gift.
  const wallet = await world.wallets.balanceOf(sale.customerId);
  assert.equal(wallet.toString(), sale.subtotal.toString());
});

dbTest('a prepaid parcel refused at the door pays her back — minus the journey', async (world) => {
  const sale = await makeSale(world.tx, {
    method: PaymentMethodType.SYRIATEL_CASH,
    paymentStatus: PaymentStatus.PAID,
  });
  const stockBefore = await world.tx.sellerOffer.findUniqueOrThrow({
    where: { id: sale.offerId },
  });

  await world.sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.ready(sale.seller, sale.sellerOrder.id);
  await world.shipments.pickUp(sale.shipmentId!, sale.courierUserId!);
  await world.shipments.outForDelivery(sale.shipmentId!, sale.courierUserId!);

  await world.shipments.failAttempt(
    sale.shipmentId!,
    sale.courierUserId!,
    DeliveryFailureReason.CUSTOMER_REFUSED,
    'رفضت الاستلام',
  );

  // The goods come back, so her money does — but not the delivery fee. The
  // van made that journey whether or not she opened the door.
  const wallet = await world.wallets.balanceOf(sale.customerId);
  assert.equal(wallet.toString(), sale.subtotal.toString());

  assert.equal(
    await statusOf(world.tx, sale.sellerOrder.id),
    SellerOrderStatus.REFUNDED,
  );

  // And the seller has her stock again.
  const stockAfter = await world.tx.sellerOffer.findUniqueOrThrow({
    where: { id: sale.offerId },
  });
  assert.equal(stockAfter.stock, stockBefore.stock + 2);
});

dbTest('a missed attempt refunds nothing — the parcel is still coming', async (world) => {
  const sale = await makeSale(world.tx, {
    method: PaymentMethodType.SYRIATEL_CASH,
    paymentStatus: PaymentStatus.PAID,
  });
  await world.sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.ready(sale.seller, sale.sellerOrder.id);
  await world.shipments.pickUp(sale.shipmentId!, sale.courierUserId!);
  await world.shipments.outForDelivery(sale.shipmentId!, sale.courierUserId!);

  await world.shipments.failAttempt(
    sale.shipmentId!,
    sale.courierUserId!,
    DeliveryFailureReason.NO_ANSWER,
    'لم تجب',
  );

  const wallet = await world.wallets.balanceOf(sale.customerId);
  assert.equal(wallet.isZero(), true, 'a retry is not a refund');
});
