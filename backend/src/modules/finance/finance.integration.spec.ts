import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CourierKind,
  Currency,
  DisputeStatus,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  OrderStatus,
  PaymentMethodType,
  PrismaClient,
  SellerOrderStatus,
  UserRole,
  WalletTransactionSource,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService } from '../ledger/ledger.service';
import { WalletService } from '../ledger/wallet.service';
import { CommissionsService } from '../commissions/commissions.service';
import { CourierSettlementService } from './courier-settlement.service';
import { DisputesService } from './disputes.service';
import { LoyaltyService } from './loyalty.service';
import { AdminFinanceService } from './admin-finance.service';
import { FinancialAuditService } from './financial-audit.service';
import { FxRevaluationService } from './fx-revaluation.service';
import { ReconciliationService } from './reconciliation.service';
import { SellerEarningsService } from './seller-earnings.service';

/**
 * Dispute freezes and loyalty conversion, end to end against real Postgres.
 *
 * As with the ledger suite, everything runs inside a transaction that is
 * rolled back, so the assertions meet real constraints and the database is
 * left exactly as it was found.
 */
const prisma = new PrismaClient();
const ledger = new LedgerService(prisma as unknown as PrismaService);
const wallets = new WalletService(prisma as unknown as PrismaService, ledger);
/**
 * The audit trail is exercised by its own suite; here it only has to exist so
 * the services under test can call it.
 */
const audit = {
  record: async () => {},
  recordBalanceChange: async () => {},
} as unknown as FinancialAuditService;

const disputes = new DisputesService(
  prisma as unknown as PrismaService,
  ledger,
  wallets,
  audit,
);
const loyalty = new LoyaltyService(
  prisma as unknown as PrismaService,
  ledger,
  wallets,
);
const courierSettlements = new CourierSettlementService(
  prisma as unknown as PrismaService,
  ledger,
  audit,
);
const sellerEarnings = new SellerEarningsService(
  prisma as unknown as PrismaService,
  ledger,
);

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

const syp = (value: string) => Money.of(value, Currency.SYP);

let sequence = 0;
function unique(tag: string): string {
  sequence += 1;
  return `${Date.now()}${sequence}${Math.floor(Math.random() * 1000)}${tag}`;
}

async function makeUser(tx: Tx, tag: string) {
  const u = unique(tag);
  return tx.user.create({
    data: {
      name: `fin-${tag}`,
      username: `fin_${u}`,
      phone: `+9639${u.slice(-8)}`,
      passwordHash: 'x',
    },
  });
}

/**
 * A minimal delivered sub-order with its money already settled into escrow —
 * the state a dispute is normally raised against.
 */
async function makeSettledSellerOrder(
  tx: Tx,
  options: { escrowReleased: boolean; net?: string; subtotal?: string } = {
    escrowReleased: false,
  },
) {
  const seller = await makeUser(tx, 'sel');
  const customer = await makeUser(tx, 'cus');

  const subtotal = options.subtotal ?? '1000000';
  const net = options.net ?? '850000';
  const commission = syp(subtotal).minus(syp(net));

  const order = await tx.order.create({
    data: {
      number: `ORD-${unique('o').slice(-12)}`,
      userId: customer.id,
      status: OrderStatus.DELIVERED,
      currency: Currency.SYP,
      fxRate: '1',
      itemsSubtotal: subtotal,
      grandTotal: subtotal,
      recipientName: 'اختبار',
      recipientPhone: '+963900000000',
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'شارع',
    },
  });

  const sellerOrder = await tx.sellerOrder.create({
    data: {
      orderId: order.id,
      number: `SUB-${unique('s').slice(-12)}`,
      sellerId: seller.id,
      status: SellerOrderStatus.DELIVERED,
      currency: Currency.SYP,
      itemsSubtotal: subtotal,
      // Q50 — commission is charged on the post-discount price.
      commissionBase: subtotal,
      commissionAmount: commission.toPrisma(),
      sellerNet: net,
      escrowReleased: options.escrowReleased,
    },
  });

  // Settle it the way CommissionsService does.
  await ledger.post(
    {
      type: JournalEntryType.COMMISSION_EARNED,
      reference: `settle:${sellerOrder.id}`,
      description: 'settled',
      orderId: order.id,
      sellerOrderId: sellerOrder.id,
      lines: [
        {
          account: { code: LedgerAccountCode.PLATFORM_CASH },
          direction: LedgerDirection.DEBIT,
          amount: syp(subtotal),
        },
        {
          account: {
            code: options.escrowReleased
              ? LedgerAccountCode.SELLER_PAYABLE
              : LedgerAccountCode.SELLER_ESCROW,
            ownerId: seller.id,
          },
          direction: LedgerDirection.CREDIT,
          amount: syp(net),
        },
        {
          account: { code: LedgerAccountCode.COMMISSION_REVENUE },
          direction: LedgerDirection.CREDIT,
          amount: commission,
        },
      ],
    },
    tx,
  );

  return { seller, customer, order, sellerOrder };
}

/** A settled parcel with a dispute already open on it. */
async function makeDisputedOrder(tx: Tx) {
  const { seller, customer, sellerOrder } = await makeSettledSellerOrder(tx);
  const dispute = await disputes.open(
    {
      sellerOrderId: sellerOrder.id,
      openedById: customer.id,
      subject: 'الطلب لم يطابق الوصف',
    },
    tx,
  );
  return { dispute, sellerOrder, sellerId: seller.id, customerId: customer.id };
}

// ── Dispute freezing (Q107) ───────────────────────────────────────────────

dbTest('opening a dispute moves the money out of escrow into held', async () => {
  await inRolledBackTx(async (tx) => {
    const { seller, sellerOrder } = await makeSettledSellerOrder(tx);

    const dispute = await disputes.open(
      {
        sellerOrderId: sellerOrder.id,
        openedById: sellerOrder.sellerId,
        subject: 'المنتج مختلف عن الصورة',
      },
      tx,
    );

    assert.equal(dispute.status, DisputeStatus.OPEN);

    const escrow = await tx.ledgerAccount.findFirstOrThrow({
      where: { code: LedgerAccountCode.SELLER_ESCROW, ownerKey: seller.id },
    });
    assert.equal(escrow.balance.toString(), '0', 'escrow must be emptied');

    const held = await tx.ledgerAccount.findFirstOrThrow({
      where: { code: LedgerAccountCode.DISPUTE_HELD, ownerKey: seller.id },
    });
    assert.equal(held.balance.toString(), '850000');

    // Nothing is payable while it is under review — this is what makes the
    // freeze structural rather than a flag a payout query must remember.
    const payable = await tx.ledgerAccount.findFirst({
      where: { code: LedgerAccountCode.SELLER_PAYABLE, ownerKey: seller.id },
    });
    assert.equal(payable?.balance.toString() ?? '0', '0');
  });
});

dbTest('a dispute raised after the return window takes from payable', async () => {
  await inRolledBackTx(async (tx) => {
    const { seller, sellerOrder } = await makeSettledSellerOrder(tx, {
      escrowReleased: true,
    });

        await disputes.open(
      {
        sellerOrderId: sellerOrder.id,
        openedById: sellerOrder.sellerId,
        subject: 'شكوى متأخرة',
      },
      tx,
    );

    const payable = await tx.ledgerAccount.findFirstOrThrow({
      where: { code: LedgerAccountCode.SELLER_PAYABLE, ownerKey: seller.id },
    });
    assert.equal(payable.balance.toString(), '0');

    const held = await tx.ledgerAccount.findFirstOrThrow({
      where: { code: LedgerAccountCode.DISPUTE_HELD, ownerKey: seller.id },
    });
    assert.equal(held.balance.toString(), '850000');
  });
});

dbTest('freezing more than the sub-order is worth is refused', async () => {
  await inRolledBackTx(async (tx) => {
    const { sellerOrder } = await makeSettledSellerOrder(tx);
    
    await assert.rejects(
      disputes.open(
        {
          sellerOrderId: sellerOrder.id,
          openedById: sellerOrder.sellerId,
          subject: 'مبالغة',
          amount: '9999999',
        },
        tx,
      ),
      /only worth/,
    );
  });
});

dbTest('deciding for the customer empties held into her wallet', async () => {
  await inRolledBackTx(async (tx) => {
    const { seller, customer, sellerOrder } = await makeSettledSellerOrder(tx);
    
    const dispute = await disputes.open(
      {
        sellerOrderId: sellerOrder.id,
        openedById: customer.id,
        subject: 'عيب مصنعي',
      },
      tx,
    );
    const decided = await disputes.decide(
      dispute.id,
      { outcome: 'CUSTOMER', note: 'الأدلة تدعم الزبونة' },
      customer.id,
      tx,
    );

    assert.equal(decided.status, DisputeStatus.RESOLVED_FOR_CUSTOMER);

    const held = await tx.ledgerAccount.findFirstOrThrow({
      where: { code: LedgerAccountCode.DISPUTE_HELD, ownerKey: seller.id },
    });
    assert.equal(held.balance.toString(), '0', 'a decided dispute holds nothing');

    const walletAccount = await tx.ledgerAccount.findFirstOrThrow({
      where: { code: LedgerAccountCode.CUSTOMER_WALLET, ownerKey: customer.id },
    });
    assert.equal(walletAccount.balance.toString(), '850000');

    // The customer-facing wallet row must agree with the ledger.
    const wallet = await tx.wallet.findFirstOrThrow({
      where: { userId: customer.id },
    });
    assert.equal(wallet.balance.toString(), '850000');

    const statement = await tx.walletTransaction.findFirstOrThrow({
      where: { walletId: wallet.id },
    });
    assert.equal(statement.balanceAfter.toString(), '850000');
  });
});

dbTest('a split ruling divides held between customer and seller', async () => {
  await inRolledBackTx(async (tx) => {
    const { seller, customer, sellerOrder } = await makeSettledSellerOrder(tx);
    
    const dispute = await disputes.open(
      {
        sellerOrderId: sellerOrder.id,
        openedById: customer.id,
        subject: 'خلاف جزئي',
      },
      tx,
    );
    await disputes.decide(
      dispute.id,
      { outcome: 'SPLIT', customerShare: '300000' },
      customer.id,
      tx,
    );

    const held = await tx.ledgerAccount.findFirstOrThrow({
      where: { code: LedgerAccountCode.DISPUTE_HELD, ownerKey: seller.id },
    });
    assert.equal(held.balance.toString(), '0');

    const payable = await tx.ledgerAccount.findFirstOrThrow({
      where: { code: LedgerAccountCode.SELLER_PAYABLE, ownerKey: seller.id },
    });
    assert.equal(payable.balance.toString(), '550000');

    const wallet = await tx.ledgerAccount.findFirstOrThrow({
      where: { code: LedgerAccountCode.CUSTOMER_WALLET, ownerKey: customer.id },
    });
    assert.equal(wallet.balance.toString(), '300000');
  });
});

dbTest('a split awarding more than was frozen is refused', async () => {
  await inRolledBackTx(async (tx) => {
    const { customer, sellerOrder } = await makeSettledSellerOrder(tx);
    
    const dispute = await disputes.open(
      {
        sellerOrderId: sellerOrder.id,
        openedById: customer.id,
        subject: 'خلاف',
      },
      tx,
    );

    await assert.rejects(
      disputes.decide(
        dispute.id,
        { outcome: 'SPLIT', customerShare: '900000' },
        customer.id,
        tx,
      ),
      /between zero and the frozen/,
    );
  });
});

dbTest('a dispute cannot be decided twice', async () => {
  await inRolledBackTx(async (tx) => {
    const { customer, sellerOrder } = await makeSettledSellerOrder(tx);
    
    const dispute = await disputes.open(
      {
        sellerOrderId: sellerOrder.id,
        openedById: customer.id,
        subject: 'خلاف',
      },
      tx,
    );
    await disputes.decide(dispute.id, { outcome: 'SELLER' }, customer.id, tx);

    await assert.rejects(
      disputes.decide(dispute.id, { outcome: 'CUSTOMER' }, customer.id, tx),
      /already been decided/,
    );
  });
});

// ── Loyalty (Q43) ─────────────────────────────────────────────────────────

// Q43's rates were quoted in the old lira — 10,000 ل.س a point, 10 points for
// 5,000 ل.س. Syria dropped two zeros, so the same programme is 100 ل.س a point
// and 50 ل.س for ten. What is pinned here is that the rate moved with the
// currency and not, say, a hundredfold cheaper loyalty scheme.
test('Q43 earn rate: 100 new SYP of purchases is one point', () => {
  const service = Object.create(LoyaltyService.prototype) as LoyaltyService;
  assert.equal(service.pointsFor(syp('100')), 1);
  assert.equal(service.pointsFor(syp('950')), 9);
  assert.equal(service.pointsFor(syp('99')), 0);
  // A USD sub-order earns nothing until the client sets a USD rate.
  assert.equal(service.pointsFor(Money.of('100', Currency.USD)), 0);
});

test('Q43 redemption rate: 10 points is 50 new SYP of credit', () => {
  const service = Object.create(LoyaltyService.prototype) as LoyaltyService;
  assert.equal(service.creditFor(10).toJSON().amount, '50.0000');
  assert.equal(service.creditFor(25).toJSON().amount, '100.0000');
  assert.equal(service.creditFor(9).toJSON().amount, '0.0000');
});

dbTest('converting points moves the loyalty liability into her wallet', async () => {
  await inRolledBackTx(async (tx) => {
    const customer = await makeUser(tx, 'loy');
    await tx.user.update({
      where: { id: customer.id },
      data: { points: 30 },
    });

    /**
     * `LOYALTY_LIABILITY` is a platform-wide singleton, so the seeded shop's
     * own Q43 accruals are already sitting in it. The assertion below therefore
     * measures the *change* this test causes rather than the account's absolute
     * balance — the earlier absolute check only passed on a database whose
     * liability happened to be zero, and broke the first time the demo data was
     * reseeded with delivered orders in it.
     */
    const liabilityBefore = await tx.ledgerAccount
      .findFirst({
        where: {
          code: LedgerAccountCode.LOYALTY_LIABILITY,
          ownerKey: 'platform',
        },
        select: { balance: true },
      })
      .then((row) => Number(row?.balance ?? 0));

    // The liability has to exist before it can be converted.
    await ledger.post(
      {
        type: JournalEntryType.LOYALTY_ACCRUED,
        reference: `demo-accrue:${customer.id}`,
        description: 'accrued',
        lines: [
          {
            account: { code: LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE },
            direction: LedgerDirection.DEBIT,
            amount: syp('150'),
          },
          {
            account: { code: LedgerAccountCode.LOYALTY_LIABILITY },
            direction: LedgerDirection.CREDIT,
            amount: syp('150'),
          },
        ],
      },
      tx,
    );

        const result = await loyalty.convertToWallet(customer.id, 20, tx);

    assert.equal(result.points_converted, 20);
    assert.equal(result.points_remaining, 10);
    assert.equal(result.credited.amount, '100.0000');

    const walletAccount = await tx.ledgerAccount.findFirstOrThrow({
      where: { code: LedgerAccountCode.CUSTOMER_WALLET, ownerKey: customer.id },
    });
    assert.equal(walletAccount.balance.toString(), '100');

    // 150 accrued minus 100 converted leaves 50 still promised.
    const liability = await tx.ledgerAccount.findFirstOrThrow({
      where: { code: LedgerAccountCode.LOYALTY_LIABILITY, ownerKey: 'platform' },
    });
    assert.equal(Number(liability.balance) - liabilityBefore, 50);
  });
});

dbTest('points convert only in multiples of ten', async () => {
  await inRolledBackTx(async (tx) => {
    const customer = await makeUser(tx, 'mul');
    await tx.user.update({ where: { id: customer.id }, data: { points: 50 } });

        await assert.rejects(
      loyalty.convertToWallet(customer.id, 15, tx),
      /multiples of 10/,
    );
  });
});

dbTest('converting more points than she has is refused', async () => {
  await inRolledBackTx(async (tx) => {
    const customer = await makeUser(tx, 'few');
    await tx.user.update({ where: { id: customer.id }, data: { points: 10 } });

        await assert.rejects(
      loyalty.convertToWallet(customer.id, 20, tx),
      /Not enough points/,
    );
  });
});

// ── Courier cash (Q56) ────────────────────────────────────────────────────

dbTest('a fully settled courier day nets their in-transit account to zero', async () => {
  await inRolledBackTx(async (tx) => {
    const courier = await tx.courier.create({
      data: {
        displayName: `courier-${unique('c').slice(-8)}`,
        phone: `+9639${unique('c').slice(-8)}`,
        kind: CourierKind.PLATFORM_STAFF,
      },
    });

    // A day of cash-on-delivery: the settlement debited the courier, because
    // that is who is actually holding the money.
    await ledger.post(
      {
        type: JournalEntryType.COMMISSION_EARNED,
        reference: `cod:${courier.id}`,
        description: 'COD collected on delivery',
        lines: [
          {
            account: {
              code: LedgerAccountCode.COURIER_CASH_IN_TRANSIT,
              ownerId: courier.id,
            },
            direction: LedgerDirection.DEBIT,
            amount: syp('400000'),
          },
          {
            account: { code: LedgerAccountCode.COMMISSION_REVENUE },
            direction: LedgerDirection.CREDIT,
            amount: syp('400000'),
          },
        ],
      },
      tx,
    );

    const inTransit = await tx.ledgerAccount.findFirstOrThrow({
      where: {
        code: LedgerAccountCode.COURIER_CASH_IN_TRANSIT,
        ownerKey: courier.id,
      },
    });
    assert.equal(inTransit.balance.toString(), '400000');

    await courierSettlements.settle(
      {
        courierId: courier.id,
        date: new Date(),
        collected: syp('400000'),
        settledById: courier.id,
      },
      tx,
    );

    const after = await tx.ledgerAccount.findFirstOrThrow({
      where: { id: inTransit.id },
    });
    assert.equal(
      after.balance.toString(),
      '0',
      'handing over everything must clear the courier',
    );
  });
});

dbTest('a short settlement leaves the shortfall against that courier', async () => {
  await inRolledBackTx(async (tx) => {
    const courier = await tx.courier.create({
      data: {
        displayName: `courier-${unique('d').slice(-8)}`,
        phone: `+9639${unique('d').slice(-8)}`,
        kind: CourierKind.PLATFORM_STAFF,
      },
    });

    await ledger.post(
      {
        type: JournalEntryType.COMMISSION_EARNED,
        reference: `cod-short:${courier.id}`,
        description: 'COD collected',
        lines: [
          {
            account: {
              code: LedgerAccountCode.COURIER_CASH_IN_TRANSIT,
              ownerId: courier.id,
            },
            direction: LedgerDirection.DEBIT,
            amount: syp('300000'),
          },
          {
            account: { code: LedgerAccountCode.COMMISSION_REVENUE },
            direction: LedgerDirection.CREDIT,
            amount: syp('300000'),
          },
        ],
      },
      tx,
    );

    const settlement = await courierSettlements.settle(
      {
        courierId: courier.id,
        date: new Date(),
        collected: syp('250000'),
        settledById: courier.id,
      },
      tx,
    );

    // The 50,000 they did not hand over stays attributed to them rather than
    // being written off into a platform-wide number.
    const after = await tx.ledgerAccount.findFirstOrThrow({
      where: {
        code: LedgerAccountCode.COURIER_CASH_IN_TRANSIT,
        ownerKey: courier.id,
      },
    });
    assert.equal(after.balance.toString(), '50000');
    assert.equal(settlement.collected.toString(), '250000');
  });
});

dbTest('settling the same courier day twice is refused', async () => {
  await inRolledBackTx(async (tx) => {
    const courier = await tx.courier.create({
      data: {
        displayName: `courier-${unique('e').slice(-8)}`,
        phone: `+9639${unique('e').slice(-8)}`,
        kind: CourierKind.PLATFORM_STAFF,
      },
    });

    const day = new Date();
    await courierSettlements.settle(
      {
        courierId: courier.id,
        date: day,
        collected: syp('10000'),
        settledById: courier.id,
      },
      tx,
    );

    await assert.rejects(
      courierSettlements.settle(
        {
          courierId: courier.id,
          date: day,
          collected: syp('10000'),
          settledById: courier.id,
        },
        tx,
      ),
      /already been settled/,
    );
  });
});

// ── Where the money sits at settlement ────────────────────────────────────

test('cash-on-delivery settles against the courier, not platform cash', () => {
  const service = Object.create(CommissionsService.prototype) as {
    collectionAccount(o: unknown): { code: string; ownerId?: string | null };
  };

  const cod = service.collectionAccount({
    shipment: { courierId: 'courier-1' },
    order: { payment: { method: PaymentMethodType.COD } },
  });
  assert.equal(cod.code, LedgerAccountCode.COURIER_CASH_IN_TRANSIT);
  assert.equal(cod.ownerId, 'courier-1');
});

test('e-payments settle against the gateway until they clear', () => {
  const service = Object.create(CommissionsService.prototype) as {
    collectionAccount(o: unknown): { code: string; ownerId?: string | null };
  };

  for (const method of [
    PaymentMethodType.SYRIATEL_CASH,
    PaymentMethodType.MTN_CASH,
    PaymentMethodType.SHAM_CASH,
    PaymentMethodType.BANK_CARD,
  ]) {
    const account = service.collectionAccount({
      shipment: null,
      order: { payment: { method } },
    });
    assert.equal(
      account.code,
      LedgerAccountCode.GATEWAY_RECEIVABLE,
      `${method} should sit with the provider until it clears`,
    );
  }
});

test('a COD order with no courier falls back to platform cash', () => {
  const service = Object.create(CommissionsService.prototype) as {
    collectionAccount(o: unknown): { code: string; ownerId?: string | null };
  };

  // Nobody to attribute the cash to, so it is not attributed to no one.
  const account = service.collectionAccount({
    shipment: null,
    order: { payment: { method: PaymentMethodType.COD } },
  });
  assert.equal(account.code, LedgerAccountCode.PLATFORM_CASH);
});

// ── Seller statement (Q69, Q98) ───────────────────────────────────────────

dbTest('a seller sees escrow, payable and frozen as three separate figures', async () => {
  await inRolledBackTx(async (tx) => {
    const { seller, customer, sellerOrder } = await makeSettledSellerOrder(tx);
    await tx.user.update({
      where: { id: seller.id },
      data: { role: UserRole.SELLER },
    });

    // Part of the money is released, part is disputed, part stays in escrow.
    await ledger.post(
      {
        type: JournalEntryType.ESCROW_RELEASED,
        reference: `earn:release:${sellerOrder.id}`,
        description: 'Return window closed',
        lines: [
          {
            account: {
              code: LedgerAccountCode.SELLER_ESCROW,
              ownerId: seller.id,
            },
            direction: LedgerDirection.DEBIT,
            amount: syp('500000'),
          },
          {
            account: {
              code: LedgerAccountCode.SELLER_PAYABLE,
              ownerId: seller.id,
            },
            direction: LedgerDirection.CREDIT,
            amount: syp('500000'),
          },
        ],
      },
      tx,
    );

    await disputes.open(
      {
        sellerOrderId: sellerOrder.id,
        openedById: customer.id,
        subject: 'خلاف',
        amount: '200000',
      },
      tx,
    );

    const summary = await sellerEarnings.summaryFor(
      seller.id,
      Currency.SYP,
      tx,
    );

    // 850,000 earned − 500,000 released − 200,000 frozen (taken from payable,
    // since the sub-order's escrow had not been released when it was opened…
    // the freeze pulls from escrow because escrowReleased is still false).
    assert.equal(summary.held_in_escrow.amount, '150000.0000');
    assert.equal(summary.available_for_payout.amount, '500000.0000');
    assert.equal(summary.frozen_in_disputes.amount, '200000.0000');
  });
});

dbTest('a seller never sees another seller’s movements', async () => {
  await inRolledBackTx(async (tx) => {
    const mine = await makeSettledSellerOrder(tx);
    const theirs = await makeSettledSellerOrder(tx);

    await tx.user.update({
      where: { id: mine.seller.id },
      data: { role: UserRole.SELLER },
    });

    const summary = await sellerEarnings.summaryFor(
      mine.seller.id,
      Currency.SYP,
      tx,
    );

    assert.ok(summary.movements.length > 0, 'she should see her own movements');
    for (const movement of summary.movements) {
      assert.notEqual(
        movement.seller_order_id,
        theirs.sellerOrder.id,
        'another seller’s parcel must never appear',
      );
    }
  });
});

dbTest('movements are signed from the seller’s point of view', async () => {
  await inRolledBackTx(async (tx) => {
    const { seller } = await makeSettledSellerOrder(tx);
    await tx.user.update({
      where: { id: seller.id },
      data: { role: UserRole.SELLER },
    });

    const summary = await sellerEarnings.summaryFor(
      seller.id,
      Currency.SYP,
      tx,
    );

    // The settlement credited her escrow, so it must read as money coming in.
    const earned = summary.movements.find(
      (m) => m.type === JournalEntryType.COMMISSION_EARNED,
    );
    assert.ok(earned, 'the settlement should appear');
    assert.equal(earned!.amount.amount, '850000.0000');
  });
});

dbTest('an internal transfer is one statement line, not two', async () => {
  await inRolledBackTx(async (tx) => {
    const { seller, sellerOrder } = await makeSettledSellerOrder(tx);
    await tx.user.update({
      where: { id: seller.id },
      data: { role: UserRole.SELLER },
    });

    // Escrow → payable touches two of her accounts in one entry.
    await ledger.post(
      {
        type: JournalEntryType.ESCROW_RELEASED,
        reference: `xfer:${sellerOrder.id}`,
        description: 'Return window closed',
        lines: [
          {
            account: {
              code: LedgerAccountCode.SELLER_ESCROW,
              ownerId: seller.id,
            },
            direction: LedgerDirection.DEBIT,
            amount: syp('850000'),
          },
          {
            account: {
              code: LedgerAccountCode.SELLER_PAYABLE,
              ownerId: seller.id,
            },
            direction: LedgerDirection.CREDIT,
            amount: syp('850000'),
          },
        ],
      },
      tx,
    );

    const summary = await sellerEarnings.summaryFor(
      seller.id,
      Currency.SYP,
      tx,
    );

    const released = summary.movements.filter(
      (m) => m.type === JournalEntryType.ESCROW_RELEASED,
    );
    assert.equal(
      released.length,
      1,
      'a release must not read as −850,000 then +850,000',
    );
    assert.equal(released[0].is_transfer, true);
    // Described by where the money landed.
    assert.equal(released[0].account, LedgerAccountCode.SELLER_PAYABLE);
    assert.equal(released[0].amount.amount, '850000.0000');
  });
});

// ── Admin finance overview ────────────────────────────────────────────────

dbTest('the overview reports what is held against what is owed', async () => {
  await inRolledBackTx(async (tx) => {
    const { seller, customer } = await makeSettledSellerOrder(tx);

    // Give the customer wallet credit so there are two kinds of obligation.
    await wallets.credit(
      {
        userId: customer.id,
        amount: syp('100000'),
        source: WalletTransactionSource.CAMPAIGN_GIFT,
        reason: 'gift',
        reference: `ov:gift:${customer.id}`,
      },
      tx,
    );

    const reconciliation = new ReconciliationService(tx as never, ledger);
    const fx = new FxRevaluationService(tx as never, ledger, {
      current: async () => {
        throw new Error('no rate published');
      },
    } as never);
    const service = new AdminFinanceService(
      tx as never,
      ledger,
      reconciliation,
      new CourierSettlementService(tx as never, ledger, audit),
      fx,
    );

    const overview = await service.overview(Currency.SYP, tx);

    // Positions sum every party's account, so they carry whatever the rest of
    // the system has already settled. What this asserts is that *this* seller
    // and *this* customer appear in them with the right figures, and that the
    // aggregates account for them.
    const escrowRow = overview.rows.find(
      (row) =>
        row.code === LedgerAccountCode.SELLER_ESCROW &&
        row.owner_id === seller.id,
    );
    assert.equal(escrowRow?.balance.amount, '850000.0000');

    const walletRow = overview.rows.find(
      (row) =>
        row.code === LedgerAccountCode.CUSTOMER_WALLET &&
        row.owner_id === customer.id,
    );
    assert.equal(walletRow?.balance.amount, '100000.0000');

    // Owed must be at least these two obligations.
    assert.ok(
      Number(overview.positions.total_owed.amount) >= 950000,
      'total owed must include both obligations',
    );

    // The book must balance regardless of what the positions say — this is
    // the assertion that would catch money appearing from nowhere.
    assert.equal(overview.balanced, true);
    assert.equal(overview.discrepancy.amount, '0.0000');
  });
});

dbTest('a healthy book reports sound, and findings are empty', async () => {
  await inRolledBackTx(async (tx) => {
    await makeSettledSellerOrder(tx);

    const reconciliation = new ReconciliationService(tx as never, ledger);
    const service = new AdminFinanceService(
      tx as never,
      ledger,
      reconciliation,
      new CourierSettlementService(tx as never, ledger, audit),
      new FxRevaluationService(tx as never, ledger, {
        current: async () => {
          throw new Error('no rate published');
        },
      } as never),
    );

    const overview = await service.overview(Currency.SYP, tx);

    assert.equal(overview.balanced, true);
    assert.deepEqual(overview.findings, []);
    assert.equal(overview.sound, true);
    // No rate published yet must omit the FX block rather than fail.
    assert.equal(overview.fx, null);
  });
});

test.after(async () => {
  await prisma.$disconnect();
});

// ── The dispute conversation (Q107) ──────────────────────────────────────

const principal = (id: string, role: UserRole) => ({
  id,
  phone: null,
  role,
});

dbTest('both sides of a dispute can put evidence on the record', async () => {
  await inRolledBackTx(async (tx) => {
    const { dispute, sellerOrder, customerId } = await makeDisputedOrder(tx);
    const customer = principal(customerId, UserRole.CUSTOMER);
    const seller = principal(sellerOrder.sellerId, UserRole.SELLER);

    await disputes.addMessage(
      dispute.id,
      customer,
      {
        body: 'وصلني مقاس مختلف',
        evidence: ['https://media.reem.test/label.jpg'],
      },
      tx,
    );
    await disputes.addMessage(
      dispute.id,
      seller,
      { body: 'المقاس مطابق للطلب' },
      tx,
    );

    // Q107 asks for «طلب أدلة من الطرفين»; until now neither side could say a
    // word while the seller's money sat frozen.
    const thread = await disputes.messages(dispute.id, customer, tx);
    assert.equal(thread.length, 2);
    assert.equal(thread[0].evidence.length, 1);
    assert.equal(thread[0].is_mine, true);
    assert.equal(thread[1].is_mine, false);
  });
});

dbTest('an internal note is support talking to support', async () => {
  await inRolledBackTx(async (tx) => {
    const { dispute, customerId } = await makeDisputedOrder(tx);
    const customer = principal(customerId, UserRole.CUSTOMER);
    const agent = principal(
      (await makeUser(tx, 'agent')).id,
      UserRole.SUPPORT_ADMIN,
    );

    await disputes.addMessage(
      dispute.id,
      agent,
      { body: 'الزبونة اتصلت مرتين', isInternal: true },
      tx,
    );

    assert.equal((await disputes.messages(dispute.id, customer, tx)).length, 0);
    assert.equal((await disputes.messages(dispute.id, agent, tx)).length, 1);

    await assert.rejects(
      () =>
        disputes.addMessage(
          dispute.id,
          customer,
          { body: 'ملاحظة', isInternal: true },
          tx,
        ),
      /Only support/,
    );
  });
});

dbTest('a stranger cannot read a dispute or add to it', async () => {
  await inRolledBackTx(async (tx) => {
    const { dispute } = await makeDisputedOrder(tx);
    const stranger = principal(
      (await makeUser(tx, 'stranger')).id,
      UserRole.CUSTOMER,
    );

    // Not a 403: a dispute number is a number, and confirming one exists says
    // something about a sale that is none of their business.
    await assert.rejects(
      () => disputes.messages(dispute.id, stranger, tx),
      /Dispute not found/,
    );
  });
});

dbTest('answering moves a dispute under review without buying more time', async () => {
  await inRolledBackTx(async (tx) => {
    const { dispute, sellerOrder } = await makeDisputedOrder(tx);
    const agent = principal(
      (await makeUser(tx, 'agent2')).id,
      UserRole.SUPPORT_ADMIN,
    );
    void sellerOrder;

    await disputes.addMessage(dispute.id, agent, { body: 'نراجع الطلب' }, tx);

    const after = await tx.dispute.findUniqueOrThrow({
      where: { id: dispute.id },
    });
    assert.equal(after.status, DisputeStatus.UNDER_REVIEW);
    // Q107's clock is the platform's promise, not something it can extend by
    // replying.
    assert.equal(after.dueAt.getTime(), dispute.dueAt.getTime());
  });
});
