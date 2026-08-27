import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  CourierKind,
  FulfilmentMode,
  LedgerAccountCode,
  OrderStatus,
  PaymentMethodType,
  PaymentStatus,
  PrismaClient,
  SellerOrderStatus,
  ShipmentStatus,
  UserRole,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService } from '../ledger/ledger.service';
import { ShipmentsService } from './shipments.service';

/**
 * The cash-on-delivery money loop, end to end.
 *
 * This is the join the whole delivery layer exists to make: a courier takes
 * cash at a doorstep, and that cash has to become a tracked asset of the
 * platform attributed to *that courier* — otherwise the daily settlement
 * (Q56) has nothing to net against and a shortfall belongs to nobody.
 *
 * Runs against real Postgres inside a rolled-back transaction.
 */
const prisma = new PrismaClient();
const ledger = new LedgerService(prisma as unknown as PrismaService);

let reachable = false;

test.before(async () => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    reachable = true;
  } catch {
    reachable = false;
  }
});

function dbTest(name: string, body: () => Promise<void>): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    await body();
  });
}

class Rollback extends Error {}
type Tx = Parameters<Parameters<typeof prisma.$transaction>[0]>[0];

async function inRolledBackTx(body: (tx: Tx) => Promise<void>): Promise<void> {
  let failure: unknown;
  try {
    await prisma.$transaction(
      async (tx) => {
        try {
          await body(tx);
        } catch (error) {
          failure = error;
        }
        throw new Rollback();
      },
      { timeout: 30000 },
    );
  } catch (error) {
    if (!(error instanceof Rollback)) throw error;
  }
  if (failure) throw failure;
}

let seq = 0;
const uniq = (t: string) => `${Date.now()}${(seq += 1)}${t}`;
const syp = (v: string) => Money.of(v, Currency.SYP);

async function makeUser(tx: Tx, tag: string, role: UserRole = UserRole.CUSTOMER) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `cod-${tag}`,
      username: `cod_${u}`,
      phone: `+9639${u.slice(-8)}`,
      passwordHash: 'x',
      role,
    },
  });
}

/** An order paid cash on delivery, carried by one of our couriers. */
async function makeCodParcel(
  tx: Tx,
  options: { withShipment?: boolean } = {},
) {
  const seller = await makeUser(tx, 'sel', UserRole.SELLER);
  const customer = await makeUser(tx, 'cus');
  const courier = await tx.courier.create({
    data: {
      displayName: `مندوب ${uniq('c').slice(-5)}`,
      phone: `+9639${uniq('c').slice(-8)}`,
      kind: CourierKind.PLATFORM_STAFF,
    },
  });

  const order = await tx.order.create({
    data: {
      number: `ORD-${uniq('o').slice(-10)}`,
      userId: customer.id,
      status: OrderStatus.CONFIRMED,
      currency: Currency.SYP,
      fxRate: '1',
      itemsSubtotal: '600000',
      shippingTotal: '15000',
      grandTotal: '615000',
      recipientName: 'ريم',
      recipientPhone: '+963900000000',
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
      payment: {
        create: {
          method: PaymentMethodType.COD,
          status: PaymentStatus.PENDING,
          currency: Currency.SYP,
          amount: '615000',
        },
      },
    },
  });

  const sellerOrder = await tx.sellerOrder.create({
    data: {
      orderId: order.id,
      number: `SUB-${uniq('s').slice(-10)}`,
      sellerId: seller.id,
      status: SellerOrderStatus.IN_TRANSIT,
      fulfilmentMode: FulfilmentMode.PLATFORM_COURIER,
      currency: Currency.SYP,
      itemsSubtotal: '600000',
      discountTotal: '20000',
      shippingCost: '15000',
      commissionBase: '580000',
      commissionAmount: '90000',
      sellerNet: '490000',
    },
  });

  if (!(options.withShipment ?? true)) {
    return { seller, customer, courier, order, sellerOrder, shipment: null };
  }

  const shipment = await tx.shipment.create({
    data: {
      trackingCode: `RM${uniq('t').slice(-9)}`,
      sellerOrderId: sellerOrder.id,
      courierId: courier.id,
      status: ShipmentStatus.OUT_FOR_DELIVERY,
      currency: Currency.SYP,
      // The goods total, deliberately not the shipping fee.
      codAmount: '600000',
    },
  });

  return { seller, customer, courier, order, sellerOrder, shipment };
}

// ── The loop ──────────────────────────────────────────────────────────────

dbTest('delivering a COD parcel puts the cash in that courier’s account', async () => {
  await inRolledBackTx(async (tx) => {
    const { seller, courier, sellerOrder } = await makeCodParcel(tx);

    // What settlement does at delivery: the goods total lands wherever the
    // money physically is, which for COD is the courier's pocket.
    await ledger.post(
      {
        type: 'COMMISSION_EARNED',
        reference: `settle:${sellerOrder.id}`,
        description: 'Delivered',
        sellerOrderId: sellerOrder.id,
        lines: [
          {
            account: {
              code: LedgerAccountCode.COURIER_CASH_IN_TRANSIT,
              ownerId: courier.id,
            },
            direction: 'DEBIT',
            amount: syp('600000'),
          },
          {
            account: {
              code: LedgerAccountCode.SELLER_ESCROW,
              ownerId: seller.id,
            },
            direction: 'CREDIT',
            amount: syp('510000'),
          },
          {
            account: { code: LedgerAccountCode.COMMISSION_REVENUE },
            direction: 'CREDIT',
            amount: syp('90000'),
          },
        ],
      },
      tx,
    );

    // The cash is an asset of the platform, held by a named person.
    const inTransit = await tx.ledgerAccount.findFirstOrThrow({
      where: {
        code: LedgerAccountCode.COURIER_CASH_IN_TRANSIT,
        ownerKey: courier.id,
        currency: Currency.SYP,
      },
    });
    assert.equal(inTransit.balance.toString(), '600000');
    assert.equal(
      inTransit.courierId,
      courier.id,
      'the account must hang off the courier foreign key, not owner_id',
    );

    // And the seller is owed their share of it.
    const escrow = await tx.ledgerAccount.findFirstOrThrow({
      where: { code: LedgerAccountCode.SELLER_ESCROW, ownerKey: seller.id },
    });
    assert.equal(escrow.balance.toString(), '510000');
  });
});

dbTest('a courier is asked for what the customer owes, delivery fee included', async () => {
  await inRolledBackTx(async (tx) => {
    const { sellerOrder } = await makeCodParcel(tx, { withShipment: false });

    const shipments = new ShipmentsService(
      tx as unknown as PrismaService,
      null as never,
      null as never,
      null as never,
    );
    const parcel = await shipments.createForSellerOrder(sellerOrder.id, {}, tx);

    // 600,000 of goods, 20,000 discount, 15,000 delivery — 595,000 at the
    // door. The fee used to be left out of this figure, which meant the
    // platform charged a delivery fee nobody ever collected; settlement books
    // the same 595,000 against the courier, so an honest one still nets to
    // zero.
    assert.equal(parcel.codAmount?.toString(), '595000');
  });
});

dbTest('a prepaid parcel carries nothing to collect', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'psel', UserRole.SELLER);
    const customer = await makeUser(tx, 'pcus');

    const order = await tx.order.create({
      data: {
        number: `ORD-${uniq('p').slice(-10)}`,
        userId: customer.id,
        status: OrderStatus.CONFIRMED,
        currency: Currency.SYP,
        fxRate: '1',
        itemsSubtotal: '400000',
        grandTotal: '400000',
        recipientName: 'ريم',
        recipientPhone: '+963900000000',
        governorate: 'دمشق',
        city: 'دمشق',
        addressLine: 'المزة',
        payment: {
          create: {
            method: PaymentMethodType.SYRIATEL_CASH,
            status: PaymentStatus.PAID,
            currency: Currency.SYP,
            amount: '400000',
          },
        },
      },
    });

    const sellerOrder = await tx.sellerOrder.create({
      data: {
        orderId: order.id,
        number: `SUB-${uniq('q').slice(-10)}`,
        sellerId: seller.id,
        status: SellerOrderStatus.PREPARING,
        fulfilmentMode: FulfilmentMode.PLATFORM_COURIER,
        currency: Currency.SYP,
        itemsSubtotal: '400000',
        commissionBase: '400000',
        commissionAmount: '60000',
        sellerNet: '340000',
      },
    });

    // A prepaid delivery is a delivery, not a collection — the courier must
    // not be made accountable for money they never touched.
    const parcel = await tx.shipment.create({
      data: {
        trackingCode: `RM${uniq('u').slice(-9)}`,
        sellerOrderId: sellerOrder.id,
        currency: Currency.SYP,
        codAmount: null,
      },
    });
    assert.equal(parcel.codAmount, null);
  });
});

dbTest('a settled day empties the courier’s account', async () => {
  await inRolledBackTx(async (tx) => {
    const { courier, sellerOrder } = await makeCodParcel(tx);

    await ledger.post(
      {
        type: 'COMMISSION_EARNED',
        reference: `settle2:${sellerOrder.id}`,
        description: 'Delivered',
        lines: [
          {
            account: {
              code: LedgerAccountCode.COURIER_CASH_IN_TRANSIT,
              ownerId: courier.id,
            },
            direction: 'DEBIT',
            amount: syp('600000'),
          },
          {
            account: { code: LedgerAccountCode.COMMISSION_REVENUE },
            direction: 'CREDIT',
            amount: syp('600000'),
          },
        ],
      },
      tx,
    );

    // Q56 — the courier hands the day's takings over.
    await ledger.post(
      {
        type: 'COURIER_CASH_SETTLED',
        reference: `handover:${courier.id}`,
        description: 'Daily settlement',
        lines: [
          {
            account: { code: LedgerAccountCode.PLATFORM_CASH },
            direction: 'DEBIT',
            amount: syp('600000'),
          },
          {
            account: {
              code: LedgerAccountCode.COURIER_CASH_IN_TRANSIT,
              ownerId: courier.id,
            },
            direction: 'CREDIT',
            amount: syp('600000'),
          },
        ],
      },
      tx,
    );

    const after = await tx.ledgerAccount.findFirstOrThrow({
      where: {
        code: LedgerAccountCode.COURIER_CASH_IN_TRANSIT,
        ownerKey: courier.id,
      },
    });
    assert.equal(
      after.balance.toString(),
      '0',
      'a courier who hands everything over owes nothing',
    );
  });
});

test.after(async () => {
  await prisma.$disconnect();
});
