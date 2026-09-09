import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  DeliveryFailureReason,
  DeliveryProviderKind,
  FulfilmentMode,
  OrderStatus,
  PaymentMethodType,
  PaymentStatus,
  PrismaClient,
  SellerOrderStatus,
  ShipmentStatus,
  UserRole,
  WebhookAuthScheme,
} from '@prisma/client';

import { Money } from '../../../common/money';
import { PrismaService } from '../../../prisma/prisma.service';
import { CommissionsService } from '../../commissions/commissions.service';
import { CustomerRefundsService } from '../../finance/customer-refunds.service';
import { FinancialAuditService } from '../../finance/financial-audit.service';
import { LoyaltyService } from '../../finance/loyalty.service';
import { CodTrustService } from '../../cod-trust/cod-trust.service';
import { CodFactsService } from '../../cod-trust/cod-facts.service';
import { LedgerService } from '../../ledger/ledger.service';
import { WalletService } from '../../ledger/wallet.service';
import { InventoryReservationService } from '../../orders/workflow/inventory-reservation.service';
import { SellerOrderWorkflowService } from '../../orders/workflow/seller-order-workflow.service';
import { ShipmentsService } from '../shipments.service';
import { DeliveryProviderRegistry } from '../providers/delivery-provider.registry';
import { DeliveryDispatchService } from './delivery-dispatch.service';

/**
 * A parcel handed to a delivery company, and what its callbacks do to the
 * order.
 *
 * This is the case that matters most in the whole integration: a carrier says
 * "delivered" and the platform must land the sub-order, open the return
 * window, book the cash it collected and settle the seller — exactly as it
 * does when one of our own couriers taps the button. And it must do it once,
 * however many times the carrier says it.
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
  dispatches: DeliveryDispatchService;
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
  // No adapter is exercised here: these cases are about what the platform does
  // with a carrier's word, not about how the word arrived.
  const registry = new DeliveryProviderRegistry([]);
  return { tx, dispatches: new DeliveryDispatchService(db, registry, shipments) };
}

// ── Fixtures ────────────────────────────────────────────────────────────

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;
const syp = (value: string | number) => Money.of(value, Currency.SYP);

async function makeUser(tx: Tx, tag: string, role: UserRole = UserRole.CUSTOMER) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `di-${tag}`,
      username: `di_${u}`,
      phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role,
    },
  });
}

/** A packed parcel already with a carrier, which is where dispatch leaves it. */
async function makeParcelWithCarrier(tx: Tx) {
  const subtotal = syp('100000');
  const shipping = syp('10000');
  const net = syp('85000');

  const customer = await makeUser(tx, 'cus');
  const seller = await makeUser(tx, 'sel', UserRole.SELLER);

  const category = await tx.category.create({
    data: { slug: `cat-${uniq('c')}`, nameAr: 'تجربة', nameEn: 'Test' },
  });
  const product = await tx.product.create({
    data: {
      slug: `prod-${uniq('p')}`,
      title: 'طقم أطفال',
      description: 'للاختبار',
      categoryId: category.id,
    },
  });
  const offer = await tx.sellerOffer.create({
    data: {
      productId: product.id,
      sellerId: seller.id,
      currency: Currency.SYP,
      price: '50000',
      stock: 5,
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
      placedAt: new Date(),
      payment: {
        create: {
          method: PaymentMethodType.COD,
          status: PaymentStatus.PENDING,
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
      status: SellerOrderStatus.READY_TO_SHIP,
      fulfilmentMode: FulfilmentMode.PLATFORM_COURIER,
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
          sellerSnapshot: 'متجر تجريبي',
          currency: Currency.SYP,
          unitPrice: '50000',
          quantity: 2,
          lineTotal: subtotal.toPrisma(),
        },
      },
    },
  });

  const shipment = await tx.shipment.create({
    data: {
      trackingCode: `REM-${uniq('t').slice(-8).toUpperCase()}`,
      sellerOrderId: sellerOrder.id,
      currency: Currency.SYP,
      codAmount: subtotal.plus(shipping).toPrisma(),
      status: ShipmentStatus.ASSIGNED,
    },
  });

  const account = await tx.deliveryProviderAccount.create({
    data: {
      code: `acme_${uniq('a').slice(-6)}`,
      displayName: 'أكمي للتوصيل',
      kind: DeliveryProviderKind.EXTERNAL_API,
      isEnabled: true,
      supportsWebhook: true,
      webhookAuth: WebhookAuthScheme.HMAC_SHA256,
      governorates: ['دمشق'],
    },
  });

  const dispatch = await tx.deliveryDispatch.create({
    data: {
      shipmentId: shipment.id,
      providerId: account.id,
      providerCode: account.code,
      status: ShipmentStatus.ASSIGNED,
      externalDeliveryId: `ACME-${uniq('x').slice(-8)}`,
      trackingNumber: 'AWB-123',
      idempotencyKey: `reem-dispatch-${shipment.id}`,
      assignedAt: new Date(),
    },
  });

  return { order, sellerOrder, shipment, dispatch, account, customer, seller };
}

// ── Cases ───────────────────────────────────────────────────────────────

dbTest('a carrier delivering a parcel lands the order with it', async (world) => {
  const sale = await makeParcelWithCarrier(world.tx);

  await world.dispatches.applyStatus(sale.dispatch, {
    externalDeliveryId: sale.dispatch.externalDeliveryId!,
    status: ShipmentStatus.PICKED_UP,
    providerStatus: 'picked_up',
  });

  let parcel = await world.tx.sellerOrder.findUniqueOrThrow({
    where: { id: sale.sellerOrder.id },
  });
  const afterPickup = await world.tx.deliveryDispatch.findUniqueOrThrow({
    where: { id: sale.dispatch.id },
  });
  assert.equal(
    parcel.status,
    SellerOrderStatus.HANDED_TO_COURIER,
    `a pick-up moves the sub-order, not just the shipment (dispatch=${afterPickup.status}, err=${afterPickup.lastError})`,
  );

  await world.dispatches.applyStatus(
    await world.tx.deliveryDispatch.findUniqueOrThrow({
      where: { id: sale.dispatch.id },
    }),
    {
      externalDeliveryId: sale.dispatch.externalDeliveryId!,
      status: ShipmentStatus.OUT_FOR_DELIVERY,
      providerStatus: 'out_for_delivery',
    },
  );

  await world.dispatches.applyStatus(
    await world.tx.deliveryDispatch.findUniqueOrThrow({
      where: { id: sale.dispatch.id },
    }),
    {
      externalDeliveryId: sale.dispatch.externalDeliveryId!,
      status: ShipmentStatus.DELIVERED,
      providerStatus: 'delivered',
      collectedAmount: '110000',
    },
  );

  parcel = await world.tx.sellerOrder.findUniqueOrThrow({
    where: { id: sale.sellerOrder.id },
  });
  const shipment = await world.tx.shipment.findUniqueOrThrow({
    where: { id: sale.shipment.id },
  });
  const payment = await world.tx.payment.findFirstOrThrow({
    where: { orderId: sale.order.id },
  });

  assert.equal(parcel.status, SellerOrderStatus.DELIVERED);
  assert.ok(parcel.deliveredAt, 'the return window opens from this timestamp');
  assert.equal(shipment.status, ShipmentStatus.DELIVERED);
  assert.equal(
    Money.of(shipment.collectedAmount!, Currency.SYP).toString(),
    Money.of('110000', Currency.SYP).toString(),
    'the cash the carrier collected is recorded on the parcel',
  );
  assert.equal(
    Money.of(payment.capturedAmount, Currency.SYP).toString(),
    Money.of('110000', Currency.SYP).toString(),
    'and pays the order down',
  );
});

dbTest('the same delivery reported twice is one delivery', async (world) => {
  const sale = await makeParcelWithCarrier(world.tx);

  const walk = async (status: ShipmentStatus, collected?: string) => {
    const current = await world.tx.deliveryDispatch.findUniqueOrThrow({
      where: { id: sale.dispatch.id },
    });
    await world.dispatches.applyStatus(current, {
      externalDeliveryId: current.externalDeliveryId!,
      status,
      collectedAmount: collected,
    });
  };

  await walk(ShipmentStatus.PICKED_UP);
  await walk(ShipmentStatus.OUT_FOR_DELIVERY);
  await walk(ShipmentStatus.DELIVERED, '110000');
  // Carriers resend. Twice more, for good measure.
  await walk(ShipmentStatus.DELIVERED, '110000');
  await walk(ShipmentStatus.DELIVERED, '110000');

  const payment = await world.tx.payment.findFirstOrThrow({
    where: { orderId: sale.order.id },
  });
  assert.equal(
    Money.of(payment.capturedAmount, Currency.SYP).toString(),
    Money.of('110000', Currency.SYP).toString(),
    'a redelivered callback must not collect the cash twice',
  );

  const events = await world.tx.shipmentEvent.count({
    where: { shipmentId: sale.shipment.id, status: ShipmentStatus.DELIVERED },
  });
  assert.equal(events, 1, 'and must not write a second delivery event');
});

dbTest('an event that arrives late cannot walk a parcel backwards', async (world) => {
  const sale = await makeParcelWithCarrier(world.tx);

  const advance = async (status: ShipmentStatus) => {
    const current = await world.tx.deliveryDispatch.findUniqueOrThrow({
      where: { id: sale.dispatch.id },
    });
    await world.dispatches.applyStatus(current, {
      externalDeliveryId: current.externalDeliveryId!,
      status,
    });
  };

  await advance(ShipmentStatus.PICKED_UP);
  await advance(ShipmentStatus.OUT_FOR_DELIVERY);
  // A retried webhook queue arrives out of order.
  await advance(ShipmentStatus.PICKED_UP);

  const shipment = await world.tx.shipment.findUniqueOrThrow({
    where: { id: sale.shipment.id },
  });
  assert.equal(
    shipment.status,
    ShipmentStatus.OUT_FOR_DELIVERY,
    'the customer must not watch her parcel go back to the warehouse',
  );
});

dbTest('a refusal at the door comes back as a refusal, with the goods', async (world) => {
  const sale = await makeParcelWithCarrier(world.tx);

  const advance = async (
    status: ShipmentStatus,
    failureReason?: DeliveryFailureReason,
  ) => {
    const current = await world.tx.deliveryDispatch.findUniqueOrThrow({
      where: { id: sale.dispatch.id },
    });
    await world.dispatches.applyStatus(current, {
      externalDeliveryId: current.externalDeliveryId!,
      status,
      failureReason,
    });
  };

  await advance(ShipmentStatus.PICKED_UP);
  await advance(ShipmentStatus.OUT_FOR_DELIVERY);
  await advance(ShipmentStatus.FAILED, DeliveryFailureReason.CUSTOMER_REFUSED);

  const parcel = await world.tx.sellerOrder.findUniqueOrThrow({
    where: { id: sale.sellerOrder.id },
  });
  const dispatch = await world.tx.deliveryDispatch.findUniqueOrThrow({
    where: { id: sale.dispatch.id },
  });

  assert.equal(
    parcel.status,
    SellerOrderStatus.REJECTED_ON_DELIVERY,
    'Q37 separates a refusal from a missed attempt, and so must a carrier event',
  );
  assert.equal(dispatch.failureReason, DeliveryFailureReason.CUSTOMER_REFUSED);
  assert.equal(dispatch.attemptCount, 1);
});

dbTest("a carrier's word is recorded even when the parcel refuses the move", async (world) => {
  const sale = await makeParcelWithCarrier(world.tx);

  // DELIVERED straight from ASSIGNED: the shipment's own table refuses it,
  // because a parcel nobody collected cannot have been delivered.
  await world.dispatches.applyStatus(sale.dispatch, {
    externalDeliveryId: sale.dispatch.externalDeliveryId!,
    status: ShipmentStatus.DELIVERED,
    providerStatus: 'delivered',
  });

  const shipment = await world.tx.shipment.findUniqueOrThrow({
    where: { id: sale.shipment.id },
  });
  const dispatch = await world.tx.deliveryDispatch.findUniqueOrThrow({
    where: { id: sale.dispatch.id },
  });

  assert.equal(shipment.status, ShipmentStatus.ASSIGNED, 'ours did not move');
  assert.ok(dispatch.lastError, 'and the disagreement is written down for ops');
  assert.equal(dispatch.providerStatus, 'delivered');
});
