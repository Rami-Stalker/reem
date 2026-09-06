import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CodAssurance,
  CodAssuranceState,
  CodRiskTier,
  Currency,
  DeliveryFailureReason,
  FulfilmentMode,
  OrderStatus,
  PaymentMethodType,
  PaymentStatus,
  PrismaClient,
  SellerOrderStatus,
  ShipmentStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { CodFactsService } from './cod-facts.service';
import { CodTrustService } from './cod-trust.service';

/**
 * The half of the engine the kernel tests cannot reach.
 *
 * `cod-risk.spec.ts` proves the arithmetic given facts. This proves the facts:
 * that a refusal recorded by a courier on a shipment eight weeks ago actually
 * arrives at the scorer as a refusal, that a delivery arrives as a delivery,
 * and that the two are never counted as the same parcel. Every one of those
 * joins crosses three tables, and a wrong `where` clause there produces a
 * confident score computed from nothing.
 *
 * Runs against real Postgres inside a rolled-back transaction.
 */
const prisma = new PrismaClient();

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

const trustFor = (tx: Tx) => {
  const db = tx as unknown as PrismaService;
  // The OTP and audit dependencies are never reached by `assess` — it gathers
  // and scores, and nothing else. Passing them as null keeps the test honest
  // about what it is exercising.
  return new CodTrustService(db, new CodFactsService(db), null as never, null as never);
};

async function makeUser(tx: Tx, tag: string, role: UserRole = UserRole.CUSTOMER) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `trust-${tag}`,
      username: `trust_${u}`,
      phone: `+9639${u.slice(-8)}`,
      passwordHash: 'x',
      role,
      isVerified: true,
    },
  });
}

/**
 * One past parcel with a known ending, for a given customer.
 *
 * `outcome` mirrors the three disjoint states the facts service reads:
 * delivered with no failure recorded, refused at the door, or a door nobody
 * answered.
 */
async function pastParcel(
  tx: Tx,
  input: {
    customerId: string;
    sellerId: string;
    outcome: 'delivered' | 'refused' | 'failed';
    total?: string;
    governorate?: string;
    recipientPhone?: string;
  },
) {
  const total = input.total ?? '600000';
  const order = await tx.order.create({
    data: {
      number: `ORD-${uniq('o').slice(-10)}`,
      userId: input.customerId,
      status: OrderStatus.DELIVERED,
      currency: Currency.SYP,
      // 1 USD = 15,000 SYP, frozen — so 600,000 SYP reads back as 40 USD.
      fxRate: '15000',
      itemsSubtotal: total,
      grandTotal: total,
      placedAt: new Date(),
      recipientName: 'ريم',
      recipientPhone: input.recipientPhone ?? '+963900000001',
      governorate: input.governorate ?? 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة، شارع الجلاء، بناء ٤',
      payment: {
        create: {
          method: PaymentMethodType.COD,
          status: PaymentStatus.PENDING,
          currency: Currency.SYP,
          amount: total,
        },
      },
    },
  });

  const sellerOrder = await tx.sellerOrder.create({
    data: {
      orderId: order.id,
      number: `SUB-${uniq('s').slice(-10)}`,
      sellerId: input.sellerId,
      status:
        input.outcome === 'delivered'
          ? SellerOrderStatus.DELIVERED
          : SellerOrderStatus.REJECTED_ON_DELIVERY,
      fulfilmentMode: FulfilmentMode.PLATFORM_COURIER,
      currency: Currency.SYP,
      itemsSubtotal: total,
      commissionBase: total,
      commissionAmount: '0',
      sellerNet: total,
    },
  });

  await tx.shipment.create({
    data: {
      trackingCode: `RM${uniq('t').slice(-9)}`,
      sellerOrderId: sellerOrder.id,
      currency: Currency.SYP,
      status:
        input.outcome === 'delivered'
          ? ShipmentStatus.DELIVERED
          : ShipmentStatus.FAILED,
      failureReason:
        input.outcome === 'refused'
          ? DeliveryFailureReason.CUSTOMER_REFUSED
          : input.outcome === 'failed'
            ? DeliveryFailureReason.NO_ANSWER
            : null,
      deliveredAt: input.outcome === 'delivered' ? new Date() : null,
    },
  });

  return { order, sellerOrder };
}

const basket = (orderValueUsd: number) => ({
  orderValueUsd,
  sellerCount: 1,
  itemCount: 2,
  maxUnitsOnOneLine: 1,
});

const destination = (overrides: Record<string, unknown> = {}) => ({
  governorate: 'دمشق',
  addressLine: 'المزة، شارع الجلاء، بناء ٤، طابق ٢',
  landmark: 'مقابل الحديقة',
  isRural: false,
  recipientPhone: '+963900000001',
  fromAddressBook: true,
  ...overrides,
}) as Parameters<CodTrustService['assess']>[0]['destination'];

// ── The joins ──────────────────────────────────────────────────────────────

dbTest('a courier’s refusal reaches the scorer as a refusal', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'sel', UserRole.SELLER);
    const customer = await makeUser(tx, 'cus');

    for (let i = 0; i < 3; i += 1) {
      await pastParcel(tx, {
        customerId: customer.id,
        sellerId: seller.id,
        outcome: 'refused',
      });
    }

    const assessment = await trustFor(tx).assess({
      userId: customer.id,
      destination: destination(),
      basket: basket(40),
    });

    assert.equal(assessment.facts.customer.refusedParcels, 3);
    assert.equal(assessment.facts.customer.deliveredParcels, 0);
    // Three refusals is the one rule that stops negotiating.
    assert.equal(assessment.decision.assurance, CodAssurance.PREPAYMENT);
    assert.ok(assessment.decision.ruleCodes.includes('repeat_refusals'));
  });
});

dbTest('a delivered parcel and a refused one are never the same parcel', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'sel', UserRole.SELLER);
    const customer = await makeUser(tx, 'cus');

    await pastParcel(tx, { customerId: customer.id, sellerId: seller.id, outcome: 'delivered' });
    await pastParcel(tx, { customerId: customer.id, sellerId: seller.id, outcome: 'refused' });
    await pastParcel(tx, { customerId: customer.id, sellerId: seller.id, outcome: 'failed' });

    const { facts } = await trustFor(tx).assess({
      userId: customer.id,
      destination: destination(),
      basket: basket(40),
    });

    // The three sets partition the parcels. If a refused-then-redelivered
    // parcel ever counted twice, the rates below would exceed one and every
    // score computed from them would be nonsense.
    assert.equal(facts.customer.deliveredParcels, 1);
    assert.equal(facts.customer.refusedParcels, 1);
    assert.equal(facts.customer.failedParcels, 1);
  });
});

dbTest('a clean history buys her out of the friction a stranger gets', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'sel', UserRole.SELLER);
    const known = await makeUser(tx, 'known');
    const stranger = await makeUser(tx, 'new');

    for (let i = 0; i < 6; i += 1) {
      await pastParcel(tx, {
        customerId: known.id,
        sellerId: seller.id,
        outcome: 'delivered',
      });
    }

    const trust = trustFor(tx);
    // 40 USD — above the first-order threshold, so the stranger is asked for a
    // code and the customer with a history is not. Same basket, same address.
    const loyal = await trust.assess({
      userId: known.id,
      destination: destination(),
      basket: basket(40),
    });
    const first = await trust.assess({
      userId: stranger.id,
      destination: destination(),
      basket: basket(40),
    });

    assert.equal(loyal.decision.tier, CodRiskTier.TRUSTED);
    assert.equal(loyal.decision.assurance, CodAssurance.NONE);
    assert.equal(first.decision.assurance, CodAssurance.ORDER_CONFIRMATION);
    assert.ok(first.decision.ruleCodes.includes('first_order_above_threshold'));
    assert.ok(loyal.score.score < first.score.score);
  });
});

dbTest('her median order value is read in USD, not in the currency of the day', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'sel', UserRole.SELLER);
    const customer = await makeUser(tx, 'cus');

    // Three 600,000 SYP orders at a frozen 15,000/USD — 40 USD each.
    for (let i = 0; i < 3; i += 1) {
      await pastParcel(tx, {
        customerId: customer.id,
        sellerId: seller.id,
        outcome: 'delivered',
        total: '600000',
      });
    }

    const { facts } = await trustFor(tx).assess({
      userId: customer.id,
      destination: destination(),
      basket: basket(40),
    });

    // Read raw, the median would be 600000 and every basket on the platform
    // would look like a rounding error beside it.
    assert.equal(facts.customer.medianOrderValue, 40);
  });
});

dbTest('a number several accounts ship to is counted, and her own is not', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'sel', UserRole.SELLER);
    const customer = await makeUser(tx, 'cus');
    const shared = '+963911111111';

    await pastParcel(tx, {
      customerId: customer.id,
      sellerId: seller.id,
      outcome: 'delivered',
      recipientPhone: shared,
    });

    const others = await Promise.all([
      makeUser(tx, 'o1'),
      makeUser(tx, 'o2'),
    ]);
    for (const other of others) {
      await pastParcel(tx, {
        customerId: other.id,
        sellerId: seller.id,
        outcome: 'delivered',
        recipientPhone: shared,
      });
    }

    const { facts } = await trustFor(tx).assess({
      userId: customer.id,
      destination: destination({ recipientPhone: shared }),
      basket: basket(40),
    });

    // Two others, not three: counting her own account against her would put
    // every returning customer one notch up the ladder.
    assert.equal(facts.destination.otherAccountsOnPhone, 2);
  });
});

dbTest('a guest is scored on the absence of an account, not on nothing', async () => {
  await inRolledBackTx(async (tx) => {
    const { facts, decision } = await trustFor(tx).assess({
      userId: null,
      destination: destination({ fromAddressBook: false }),
      basket: basket(20),
    });

    assert.equal(facts.customer.isGuest, true);
    assert.equal(facts.customer.phoneVerified, false);
    assert.equal(decision.assurance, CodAssurance.ORDER_CONFIRMATION);
    assert.ok(decision.ruleCodes.includes('guest_above_threshold'));
  });
});

// ── Persistence and the loop back ──────────────────────────────────────────

dbTest('the assessment is written against the order it gated', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'sel', UserRole.SELLER);
    const customer = await makeUser(tx, 'cus');
    const { order } = await pastParcel(tx, {
      customerId: customer.id,
      sellerId: seller.id,
      outcome: 'delivered',
    });

    const trust = trustFor(tx);
    const assessment = await trust.assess({
      userId: customer.id,
      destination: destination(),
      basket: basket(40),
    });

    const written = await trust.record(tx, {
      orderId: order.id,
      userId: customer.id,
      assessment,
      state: CodAssuranceState.PENDING,
    });

    assert.equal(written.orderId, order.id);
    assert.equal(Number(written.score), assessment.score.score);
    assert.ok(Array.isArray(written.factors));
    // The window has to exist, or a held order is held forever.
    assert.ok(written.expiresAt instanceof Date);
    assert.ok(written.expiresAt!.getTime() > Date.now());
  });
});

dbTest('a refusal overwrites a delivery already recorded against the order', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'sel', UserRole.SELLER);
    const customer = await makeUser(tx, 'cus');
    const { order } = await pastParcel(tx, {
      customerId: customer.id,
      sellerId: seller.id,
      outcome: 'delivered',
    });

    const trust = trustFor(tx);
    await trust.record(tx, {
      orderId: order.id,
      userId: customer.id,
      assessment: await trust.assess({
        userId: customer.id,
        destination: destination(),
        basket: basket(40),
      }),
      state: CodAssuranceState.NOT_REQUIRED,
    });

    // A basket split across sellers: one parcel lands, another comes back.
    await trust.observe(order.id, 'delivered');
    await trust.observe(order.id, 'refused');

    const stored = await tx.codRiskAssessment.findUniqueOrThrow({
      where: { orderId: order.id },
    });
    assert.equal(stored.observedOutcome, 'refused');

    // And the reverse does not happen: a late delivery cannot bury a refusal.
    await trust.observe(order.id, 'delivered');
    const after = await tx.codRiskAssessment.findUniqueOrThrow({
      where: { orderId: order.id },
    });
    assert.equal(after.observedOutcome, 'refused');
  });
});
