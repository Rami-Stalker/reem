import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CourierKind,
  Currency,
  DeliveryFailureReason,
  FulfilmentMode,
  InventoryReservationState,
  LedgerAccountCode,
  OrderStatus,
  PaymentMethodType,
  PaymentStatus,
  DeliveryProviderKind,
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
import { CarrierLinkService } from '../delivery/dispatch/carrier-link.service';
import { DeliveryDispatchService } from '../delivery/dispatch/delivery-dispatch.service';
import { DeliveryProviderRegistry } from '../delivery/providers/delivery-provider.registry';
import { ManualCarrierProvider } from '../delivery/providers/manual-carrier.provider';
import { CodTrustService } from '../cod-trust/cod-trust.service';
import { CodFactsService } from '../cod-trust/cod-facts.service';
import { LedgerService } from '../ledger/ledger.service';
import { WalletService } from '../ledger/wallet.service';
import { InventoryReservationService } from '../orders/workflow/inventory-reservation.service';
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
  db: PrismaService;
  /** Seller orders wired to a real dispatch with the phone-worked adapter. */
  withManualCarrier: () => { sellerOrders: SellerOrdersService; links: CarrierLinkService };
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
  const workflow = new SellerOrderWorkflowService(db, new InventoryReservationService(db));
  const customerRefunds = new CustomerRefundsService(
    db,
    ledger,
    wallets,
    workflow,
    audit,
  );
  // Real rather than stubbed: delivery now closes the cash-on-delivery trust
  // loop, and a journey test that skipped that step would stop proving the
  // journey. Only the Prisma dependency is exercised by the outcome write.
  const codTrust = new CodTrustService(
    db,
    new CodFactsService(db),
    null as never,
    null as never,
  );
  const shipments = new ShipmentsService(
    db,
    commissions,
    workflow,
    customerRefunds,
    codTrust,
  );
  // Marking a parcel ready now hands it to a delivery company. These cases are
  // about the sale, not about carriers, and the fixtures create their own
  // shipments — so dispatch is stubbed to the no-op it would be with no carrier
  // configured, which is exactly what `dispatch()` does in that case.
  const dispatches = {
    dispatch: async () => null,
  } as unknown as DeliveryDispatchService;
  const sellerOrders = new SellerOrdersService(
    db,
    workflow,
    commissions,
    customerRefunds,
    dispatches,
    shipments,
    new CarrierLinkService(db, dispatches, shipments),
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
  // Ohara Value is not the subject of these cases, and a customer with no
  // standing has no extra return days — so the benefit lookup is stubbed to the
  // Q56 default rather than wired to a real profile.
  const valueBenefits = { configFor: async () => null } as never;
  const returns = new ReturnsService(db, refunds, disputes, workflow, valueBenefits);
  const withManualCarrier = () => {
    const realDispatch = new DeliveryDispatchService(
      db,
      new DeliveryProviderRegistry([new ManualCarrierProvider(db)]),
      shipments,
    );
    const links = new CarrierLinkService(db, realDispatch, shipments);
    return {
      links,
      sellerOrders: new SellerOrdersService(
        db,
        workflow,
        commissions,
        customerRefunds,
        realDispatch,
        shipments,
        links,
      ),
    };
  };
  return {
    tx,
    db,
    withManualCarrier,
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
      phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
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

  // The hold checkout would have written for this line.
  //
  // Stock now goes back through the reservation that took it, never through a
  // bare increment — that is what makes releasing idempotent. A fixture that
  // skipped this would be modelling an order shape the platform no longer
  // produces, and every restock assertion below would be testing the absence
  // of a record rather than the release of one.
  await tx.inventoryReservation.create({
    data: {
      orderId: order.id,
      sellerOrderId: sellerOrder.id,
      offerId: offer.id,
      quantity: 2,
      state: InventoryReservationState.COMMITTED,
      committedAt: new Date(),
    },
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
  const onTheRoad = await world.sellerOrders.handOver(
    sale.seller,
    sale.sellerOrder.id,
    'بنفسها',
  );
  // The button that closes the journey has to be offered. It was read from
  // the seller's edges, where DELIVERED is unreachable, so a parcel she had
  // handed over sat in «قيد الشحن» with no action at all.
  assert.ok(
    (onTheRoad as { available_actions: string[] }).available_actions.includes(
      'deliver',
    ),
  );
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
    /يُعلَّم كمُسلَّم من قِبل المندوب/,
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
    /الطلب غير موجود/,
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


// ── Delivery modes, proof of delivery, carriers worked by phone ─────────

/** A shipment opened the way checkout opens one — with a handover code. */
async function openShipment(world: World, sellerOrderId: string) {
  await world.shipments.createForSellerOrder(sellerOrderId, {}, world.tx);
  return world.tx.shipment.findUniqueOrThrow({ where: { sellerOrderId } });
}

const actions = (detail: unknown) =>
  (detail as { available_actions: string[] }).available_actions;

dbTest('a self-delivered cash parcel walks the road and leaves her owing only the commission', async (world) => {
  const sale = await makeSale(world.tx, {
    fulfilmentMode: FulfilmentMode.SELLER_SHIPS,
    withShipment: false,
  });
  const shipment = await openShipment(world, sale.sellerOrder.id);
  assert.match(shipment.handoverCode ?? '', /^\d{4}$/);

  await world.sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.ready(sale.seller, sale.sellerOrder.id);
  const handed = await world.sellerOrders.handOver(sale.seller, sale.sellerOrder.id);
  assert.deepEqual(actions(handed), ['out_for_delivery', 'deliver', 'fail']);

  await world.sellerOrders.outForDelivery(sale.seller, sale.sellerOrder.id);
  assert.equal(await statusOf(world.tx, sale.sellerOrder.id), SellerOrderStatus.IN_TRANSIT);

  // Platform-wide accounts are shared with every other suite, so they are
  // compared before and after rather than against zero.
  const balance = (code: LedgerAccountCode, ownerId?: string) =>
    world.ledger.balanceOf({ code, ownerId }, Currency.SYP, world.tx);
  const cashBefore = await balance(LedgerAccountCode.PLATFORM_CASH);
  const shippingBefore = await balance(LedgerAccountCode.SHIPPING_REVENUE);

  await world.sellerOrders.deliver(sale.seller, sale.sellerOrder.id, {
    handoverCode: shipment.handoverCode!,
  });

  const after = await world.tx.shipment.findUniqueOrThrow({ where: { id: shipment.id } });
  assert.equal(after.status, ShipmentStatus.DELIVERED);
  assert.notEqual(after.handoverVerifiedAt, null);
  assert.equal(await statusOf(world.tx, sale.sellerOrder.id), SellerOrderStatus.DELIVERED);

  // The cash is in her hand: nothing is booked to a courier or to platform
  // cash, and the delivery fee is hers rather than platform revenue.
  assert.equal((await balance(LedgerAccountCode.PLATFORM_CASH)).toString(), cashBefore.toString());
  assert.equal(
    (await balance(LedgerAccountCode.SHIPPING_REVENUE)).toString(),
    shippingBefore.toString(),
  );
  const escrow = await balance(LedgerAccountCode.SELLER_ESCROW, sale.sellerId);
  const payable = await balance(LedgerAccountCode.SELLER_PAYABLE, sale.sellerId);
  assert.equal(escrow.toString(), sale.net.toString());
  // Once escrow releases, what is left on her account is exactly the commission.
  const commission = sale.subtotal.minus(sale.net);
  assert.equal(Math.abs(Number(escrow.plus(payable).toString())), Number(commission.toString()));
});

dbTest('a prepaid parcel cannot be marked delivered without the customer’s code', async (world) => {
  const sale = await makeSale(world.tx, {
    fulfilmentMode: FulfilmentMode.SELLER_SHIPS,
    method: PaymentMethodType.SHAM_CASH,
    paymentStatus: PaymentStatus.PAID,
    withShipment: false,
  });
  const shipment = await openShipment(world, sale.sellerOrder.id);
  assert.equal(shipment.codAmount, null);

  await world.sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.ready(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.handOver(sale.seller, sale.sellerOrder.id);

  await assert.rejects(
    () => world.sellerOrders.deliver(sale.seller, sale.sellerOrder.id),
    (error: { response?: { code?: string } }) => error.response?.code === 'HANDOVER_CODE_REQUIRED',
  );
  const wrong = shipment.handoverCode === '0000' ? '1111' : '0000';
  await assert.rejects(
    () => world.sellerOrders.deliver(sale.seller, sale.sellerOrder.id, { handoverCode: wrong }),
    (error: { response?: { code?: string } }) => error.response?.code === 'HANDOVER_CODE_WRONG',
  );
  const counted = await world.tx.shipment.findUniqueOrThrow({ where: { id: shipment.id } });
  assert.equal(counted.handoverAttempts, 1);
  assert.notEqual(await statusOf(world.tx, sale.sellerOrder.id), SellerOrderStatus.DELIVERED);

  await world.sellerOrders.deliver(sale.seller, sale.sellerOrder.id, {
    handoverCode: shipment.handoverCode!,
  });
  assert.equal(await statusOf(world.tx, sale.sellerOrder.id), SellerOrderStatus.DELIVERED);
});

dbTest('a seller can report a missed attempt and try again', async (world) => {
  const sale = await makeSale(world.tx, {
    fulfilmentMode: FulfilmentMode.SELLER_SHIPS,
    withShipment: false,
  });
  const shipment = await openShipment(world, sale.sellerOrder.id);
  await world.sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.ready(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.handOver(sale.seller, sale.sellerOrder.id);

  const failed = await world.sellerOrders.failDelivery(
    sale.seller,
    sale.sellerOrder.id,
    DeliveryFailureReason.NO_ANSWER,
  );
  assert.equal(await statusOf(world.tx, sale.sellerOrder.id), SellerOrderStatus.DELIVERY_FAILED);
  assert.ok(actions(failed).includes('out_for_delivery'));

  await world.sellerOrders.deliver(sale.seller, sale.sellerOrder.id, {
    handoverCode: shipment.handoverCode!,
  });
  const after = await world.tx.shipment.findUniqueOrThrow({ where: { id: shipment.id } });
  assert.equal(after.status, ShipmentStatus.DELIVERED);
  assert.equal(after.attemptCount, 1);
});

dbTest('a company worked by phone reports through its driver link', async (world) => {
  const { sellerOrders, links } = world.withManualCarrier();
  await world.tx.deliveryProviderAccount.updateMany({ data: { isEnabled: false } });
  await world.tx.deliveryProviderAccount.create({
    data: {
      code: `manual-${uniq('m')}`,
      adapter: 'manual',
      displayName: 'شركة الشام للتوصيل',
      kind: DeliveryProviderKind.MANUAL,
      isEnabled: true,
      priority: 0,
      governorates: [],
      webhookAuth: 'NONE',
    },
  });

  const sale = await makeSale(world.tx, { withShipment: false });
  const shipment = await openShipment(world, sale.sellerOrder.id);

  await sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  const ready = await sellerOrders.ready(sale.seller, sale.sellerOrder.id);
  assert.ok(actions(ready).includes('carrier_picked_up'));
  const link = (ready as { shipment: { carrier: { driver_link_path: string | null; reports_by_link: boolean } } })
    .shipment.carrier;
  assert.equal(link.reports_by_link, true);
  const token = link.driver_link_path!.replace('/carrier/', '');

  const view = await links.view(token);
  assert.equal(view.recipient?.phone, '+963900111222');
  assert.deepEqual(view.available_steps, ['pick_up']);

  await links.actByToken(token, 'pick_up', {});
  assert.equal(await statusOf(world.tx, sale.sellerOrder.id), SellerOrderStatus.HANDED_TO_COURIER);

  await assert.rejects(() => links.actByToken(token, 'deliver', { handoverCode: '99999'.slice(0, 4) === shipment.handoverCode ? '0000' : '9999' }));
  const done = await links.actByToken(token, 'deliver', { handoverCode: shipment.handoverCode! });
  assert.equal(done.status, 'delivered');
  assert.equal(done.recipient, null, 'a closed link stops showing her address');
  assert.equal(await statusOf(world.tx, sale.sellerOrder.id), SellerOrderStatus.DELIVERED);

  // The company is a courier row, and the cash it took is held against it.
  const carried = await world.tx.shipment.findUniqueOrThrow({ where: { id: shipment.id } });
  assert.notEqual(carried.courierId, null);
  const held = await world.ledger.balanceOf(
    { code: LedgerAccountCode.COURIER_CASH_IN_TRANSIT, ownerId: carried.courierId! },
    Currency.SYP,
    world.tx,
  );
  assert.equal(held.isZero(), false);
});

dbTest('the seller can relay what the phone-worked company told her', async (world) => {
  const { sellerOrders } = world.withManualCarrier();
  await world.tx.deliveryProviderAccount.updateMany({ data: { isEnabled: false } });
  await world.tx.deliveryProviderAccount.create({
    data: {
      code: `manual-${uniq('m')}`,
      adapter: 'manual',
      displayName: 'شركة التوصيل',
      kind: DeliveryProviderKind.MANUAL,
      isEnabled: true,
      priority: 0,
      governorates: [],
      webhookAuth: 'NONE',
    },
  });
  const sale = await makeSale(world.tx, { withShipment: false });
  const shipment = await openShipment(world, sale.sellerOrder.id);
  await sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  await sellerOrders.ready(sale.seller, sale.sellerOrder.id);

  await sellerOrders.carrierPickedUp(sale.seller, sale.sellerOrder.id);
  const onRoad = await sellerOrders.outForDelivery(sale.seller, sale.sellerOrder.id);
  assert.equal(await statusOf(world.tx, sale.sellerOrder.id), SellerOrderStatus.IN_TRANSIT);
  assert.deepEqual(actions(onRoad), ['deliver', 'fail']);

  await sellerOrders.deliver(sale.seller, sale.sellerOrder.id, {
    handoverCode: shipment.handoverCode!,
  });
  assert.equal(await statusOf(world.tx, sale.sellerOrder.id), SellerOrderStatus.DELIVERED);
});

dbTest('a platform-courier parcel still cannot be moved by the seller', async (world) => {
  const sale = await makeSale(world.tx);
  await world.sellerOrders.confirm(sale.seller, sale.sellerOrder.id);
  await world.sellerOrders.ready(sale.seller, sale.sellerOrder.id);
  await assert.rejects(() => world.sellerOrders.outForDelivery(sale.seller, sale.sellerOrder.id));
});
