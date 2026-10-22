import assert from 'node:assert/strict';
import test from 'node:test';
import { ConfigService } from '@nestjs/config';
import {
  Currency,
  OrderStatus,
  PaymentMethodType,
  PaymentStatus,
  PrismaClient,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService } from '../ledger/ledger.service';
import { PaymentsService, TRANSFER_REVIEW_HOURS } from './payments.service';
import { PaymentProviderRegistry } from './providers/payment-provider.registry';
import {
  BankCardProvider,
  BankTransferProvider,
  CodProvider,
  CourierCollectProvider,
  HawalaProvider,
  MtnCashProvider,
  PlatformWalletProvider,
  ShamCashProvider,
  SyriatelCashProvider,
} from './providers/payment.providers';

/**
 * Q51 — a bank transfer or hawala, from her reference to finance's decision.
 *
 * Before this, a woman could send the reference and nothing on the platform
 * could act on it: the order sat pending until it expired with her money on
 * its way. Everything here runs in a transaction that is rolled back.
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
  payments: PaymentsService;
  confirmed: string[];
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const confirmed: string[] = [];
  const registry = new PaymentProviderRegistry([
    new CodProvider(),
    new CourierCollectProvider(),
    new SyriatelCashProvider(),
    new MtnCashProvider(),
    new ShamCashProvider(),
    new BankCardProvider(),
    new BankTransferProvider(),
    new HawalaProvider(),
    new PlatformWalletProvider(),
  ]);
  // Checkout's confirmation is exercised by its own suites; here it only has
  // to prove it ran inside the payment's transaction.
  const checkout = {
    confirm: async (orderId: string, _actor: string | null, inner?: Tx) => {
      assert.ok(inner, 'the order is confirmed in the payment transaction');
      confirmed.push(orderId);
      await inner.order.update({
        where: { id: orderId },
        data: { status: OrderStatus.CONFIRMED },
      });
    },
  };
  const payments = new PaymentsService(
    db,
    registry,
    { emit: () => true } as never,
    checkout as never,
    new LedgerService(db),
    {} as never,
    new ConfigService({
      payments: { manualInstructions: { HAWALA: 'مكتب الهرم' } },
    }),
  );
  return { tx, payments, confirmed };
}

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

let seq = 0;
const uniq = (tag: string) =>
  `${Date.now().toString(36)}${(seq += 1).toString(36)}${tag}`;

async function makeOrder(
  tx: Tx,
  options: { method?: PaymentMethodType; status?: OrderStatus } = {},
) {
  const customer = await tx.user.create({
    data: {
      name: 'زبونة',
      username: `tr_${uniq('c')}`,
      phone: `+9639${Math.floor(10_000_000 + Math.random() * 89_999_999)}`,
      passwordHash: 'x',
      role: UserRole.CUSTOMER,
    },
  });
  const order = await tx.order.create({
    data: {
      number: `TR-${uniq('o').slice(-12)}`,
      userId: customer.id,
      status: options.status ?? OrderStatus.PENDING_PAYMENT,
      currency: Currency.SYP,
      fxRate: '130',
      itemsSubtotal: '25000',
      grandTotal: '25000',
      recipientName: 'ريم',
      recipientPhone: '+963900000000',
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
      expiresAt: new Date(Date.now() + 60 * 60 * 1000),
      payment: {
        create: {
          method: options.method ?? PaymentMethodType.HAWALA,
          status: PaymentStatus.PENDING,
          currency: Currency.SYP,
          amount: '25000',
          transactionRef: `HWL-${uniq('r')}`,
        },
      },
    },
    include: { payment: true },
  });
  return { customer, order, payment: order.payment! };
}

const admin = async (tx: Tx) =>
  tx.user.create({
    data: {
      name: 'مالية',
      username: `tr_${uniq('a')}`,
      phone: `+9639${Math.floor(10_000_000 + Math.random() * 89_999_999)}`,
      passwordHash: 'x',
      role: UserRole.FINANCE_ADMIN,
    },
  });

dbTest('her reference restarts the deadline, and finance sees it in the queue', async (world) => {
  const { customer, order, payment } = await makeOrder(world.tx);
  await world.payments.submitReference(customer.id, payment.id, 'HW-778812');

  const after = await world.tx.order.findUniqueOrThrow({ where: { id: order.id } });
  const floor = Date.now() + (TRANSFER_REVIEW_HOURS - 1) * 60 * 60 * 1000;
  assert.ok(after.expiresAt!.getTime() > floor, 'finance gets its full window');

  const queue = await world.payments.pendingTransfers();
  const row = queue.find((item) => item.id === payment.id);
  assert.ok(row, 'it is in the queue');
  assert.equal(row.provider_ref, 'HW-778812');
  assert.ok(row.reference_submitted_at);
});

dbTest('finance confirming a transfer settles it and confirms the order, once', async (world) => {
  const { customer, order, payment } = await makeOrder(world.tx);
  await world.payments.submitReference(customer.id, payment.id, 'HW-1');
  const finance = await admin(world.tx);

  const confirmed = await world.payments.confirmTransfer(finance.id, payment.id);
  assert.equal(confirmed.status, 'paid');
  assert.deepEqual(world.confirmed, [order.id]);

  // The money landed: the receivable the rail books is discharged into cash.
  const capture = await world.tx.journalEntry.count({
    where: { reference: `payment-captured:${payment.id}` },
  });
  assert.equal(capture, 1);

  // A second press is answered, not repeated.
  const again = await world.payments.confirmTransfer(finance.id, payment.id);
  assert.equal(again.status, 'paid');
  assert.equal(world.confirmed.length, 1);
});

dbTest('a reference that does not match is sent back to her with the reason', async (world) => {
  const { customer, order, payment } = await makeOrder(world.tx);
  await world.payments.submitReference(customer.id, payment.id, 'HW-WRONG');
  const finance = await admin(world.tx);

  const rejected = await world.payments.rejectTransfer(
    finance.id,
    payment.id,
    'الرقم غير موجود لدى المكتب',
  );
  assert.equal(rejected.status, 'pending', 'she can still pay');
  assert.equal(rejected.provider_ref, null);
  assert.equal(rejected.failure_reason, 'الرقم غير موجود لدى المكتب');

  const note = await world.tx.orderEvent.findFirst({
    where: { orderId: order.id, title: 'لم نتمكّن من مطابقة الحوالة' },
  });
  assert.ok(note, 'her timeline says why');

  // And the right one goes through.
  const resent = await world.payments.submitReference(customer.id, payment.id, 'HW-RIGHT');
  assert.equal(resent.failure_reason, null);
});

dbTest('an order that has already expired cannot be confirmed', async (world) => {
  const { payment } = await makeOrder(world.tx, { status: OrderStatus.CANCELLED });
  const finance = await admin(world.tx);
  await assert.rejects(
    () => world.payments.confirmTransfer(finance.id, payment.id),
    (error: unknown) =>
      JSON.stringify((error as { getResponse(): unknown }).getResponse()).includes(
        'ORDER_NOT_AWAITING_PAYMENT',
      ),
  );
});

dbTest('cash is never confirmed from the finance desk', async (world) => {
  const { payment } = await makeOrder(world.tx, { method: PaymentMethodType.COD });
  const finance = await admin(world.tx);
  await assert.rejects(
    () => world.payments.confirmTransfer(finance.id, payment.id),
    /Only bank transfers and hawala/,
  );
});
