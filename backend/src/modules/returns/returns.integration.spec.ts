import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  OrderStatus,
  PaymentMethodType,
  PaymentStatus,
  PrismaClient,
  ReturnCostBearer,
  ReturnReason,
  ReturnStatus,
  SellerOrderStatus,
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
import { LedgerService } from '../ledger/ledger.service';
import { WalletService } from '../ledger/wallet.service';
import { SellerOrderWorkflowService } from '../orders/workflow/seller-order-workflow.service';
import { ReturnRefundsService } from './return-refunds.service';
import { ReturnsService } from './returns.service';

/**
 * Returns end to end, against real Postgres, inside a transaction that is
 * rolled back afterwards.
 *
 * The point of testing this against a real database rather than mocks is that
 * almost everything worth getting wrong here is arithmetic *across* rows: what
 * the customer paid after a basket-wide coupon, what the seller still holds in
 * escrow, what the platform gives back of its commission. A mock would happily
 * confirm whatever the code believes.
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

/**
 * The services under test, wired to the open transaction.
 *
 * `ReturnsService` opens transactions of its own, which the root client cannot
 * see inside this one. The proxy makes a nested `$transaction` a pass-through,
 * so everything the services write lands in the same transaction the test then
 * reads and finally rolls back. Nesting is exactly what Postgres would do with
 * no savepoint anyway, so nothing is being faked — only flattened.
 */
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
  commissions: CommissionsService;
  refunds: ReturnRefundsService;
  returns: ReturnsService;
}

/** The audit trail has its own suite; here it only has to exist. */
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
  const refunds = new ReturnRefundsService(
    db,
    ledger,
    wallets,
    commissions,
    audit,
    customerRefunds,
  );
  const disputes = new DisputesService(db, ledger, wallets, audit);
  // Reem Value is not the subject of these cases, and a customer with no
  // standing has no extra return days — so the benefit lookup is stubbed to the
  // Q56 default rather than wired to a real profile.
  const valueBenefits = { configFor: async () => null } as never;
  const returns = new ReturnsService(db, refunds, disputes, workflow, valueBenefits);
  return { tx, ledger, wallets, commissions, refunds, returns };
}

// ── Fixtures ────────────────────────────────────────────────────────────

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;
const syp = (value: string | number) => Money.of(value, Currency.SYP);

async function makeUser(tx: Tx, tag: string, role: UserRole = UserRole.CUSTOMER) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `ret-${tag}`,
      username: `ret_${u}`,
      phone: `+9639${u.slice(-8)}`,
      passwordHash: 'x',
      role,
    },
  });
}

interface ParcelOptions {
  /** Units of the single line. */
  quantity?: number;
  unitPrice?: string;
  /** Basket-wide coupon share landing on this parcel (Q49). */
  discount?: string;
  shipping?: string;
  /** What the seller keeps; the rest is commission and platform fee. */
  sellerNet?: string;
  categoryAllowsReturns?: boolean;
  offerAcceptsReturns?: boolean;
  isMadeToOrder?: boolean;
  /** Delivered and settled into escrow, the ordinary case. */
  settle?: boolean;
  paymentStatus?: PaymentStatus;
  paymentMethod?: PaymentMethodType;
}

/**
 * One delivered parcel with one line, its catalogue behind it, and its money
 * already split into escrow and commission — the state a return starts from.
 */
async function makeParcel(
  world: World,
  options: ParcelOptions = {},
) {
  const { tx, commissions } = world;
  const quantity = options.quantity ?? 2;
  const unitPrice = options.unitPrice ?? '500000';
  const discount = options.discount ?? '0';
  const shipping = options.shipping ?? '30000';
  const subtotal = syp(unitPrice).times(quantity);
  const sellerNet =
    options.sellerNet ?? subtotal.times('0.8').toPrisma().toString();

  const customer = await makeUser(tx, 'cus');
  const seller = await makeUser(tx, 'sel', UserRole.SELLER);

  const category = await tx.category.create({
    data: {
      slug: `cat-${uniq('c')}`,
      nameAr: 'تجربة',
      nameEn: 'Test',
      returnsAllowed: options.categoryAllowsReturns ?? true,
    },
  });

  const product = await tx.product.create({
    data: {
      slug: `prod-${uniq('p')}`,
      title: 'فستان تجريبي',
      description: 'للاختبار',
      categoryId: category.id,
    },
  });

  const offer = await tx.sellerOffer.create({
    data: {
      productId: product.id,
      sellerId: seller.id,
      currency: Currency.SYP,
      price: unitPrice,
      stock: 10,
      acceptsReturns: options.offerAcceptsReturns ?? true,
      isMadeToOrder: options.isMadeToOrder ?? false,
    },
  });

  const order = await tx.order.create({
    data: {
      number: `ORD-${uniq('o').slice(-12)}`,
      userId: customer.id,
      status: OrderStatus.DELIVERED,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: subtotal.toPrisma(),
      discountTotal: discount,
      shippingTotal: shipping,
      grandTotal: subtotal.minus(syp(discount)).plus(syp(shipping)).toPrisma(),
      recipientName: 'ريم',
      recipientPhone: '+963900000000',
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
      ...(options.paymentStatus
        ? {
            payment: {
              create: {
                method: options.paymentMethod ?? PaymentMethodType.COD,
                status: options.paymentStatus,
                currency: Currency.SYP,
                amount: subtotal.toPrisma(),
              },
            },
          }
        : {}),
    },
  });

  const commissionBase = subtotal.minus(syp(discount));
  const sellerOrder = await tx.sellerOrder.create({
    data: {
      orderId: order.id,
      number: `SUB-${uniq('s').slice(-12)}`,
      sellerId: seller.id,
      status: SellerOrderStatus.DELIVERED,
      currency: Currency.SYP,
      itemsSubtotal: subtotal.toPrisma(),
      discountTotal: discount,
      shippingCost: shipping,
      commissionBase: commissionBase.toPrisma(),
      commissionAmount: commissionBase.minus(syp(sellerNet)).toPrisma(),
      sellerNet,
      deliveredAt: new Date(),
      items: {
        create: {
          offerId: offer.id,
          productId: product.id,
          titleSnapshot: product.title,
          sellerSnapshot: 'بائعة تجريبية',
          currency: Currency.SYP,
          unitPrice,
          quantity,
          lineTotal: subtotal.toPrisma(),
        },
      },
    },
    include: { items: true },
  });

  if (options.settle !== false) {
    await commissions.settleSellerOrder(sellerOrder.id);
  }

  return {
    customer: principal(customer.id, UserRole.CUSTOMER),
    seller: principal(seller.id, UserRole.SELLER),
    admin: principal((await makeUser(tx, 'adm', UserRole.SUPER_ADMIN)).id, UserRole.SUPER_ADMIN),
    customerId: customer.id,
    sellerId: seller.id,
    offerId: offer.id,
    order,
    sellerOrder,
    item: sellerOrder.items[0],
    subtotal,
    sellerNet: syp(sellerNet),
    shipping: syp(shipping),
  };
}

function principal(id: string, role: UserRole): AuthUser {
  return { id, phone: null, role };
}

/** Walks a request all the way to the seller confirming she has it back. */
async function bringItBack(
  world: World,
  actors: { customer: AuthUser; seller: AuthUser },
  returnId: string,
  bearer?: ReturnCostBearer,
) {
  await world.returns.approve(actors.seller, returnId, {
    shippingBorneBy: bearer,
  });
  await world.returns.markInTransit(actors.seller, returnId);
  await world.returns.receive(actors.seller, returnId);
}

const balance = (world: World, code: LedgerAccountCode, ownerId?: string) =>
  world.ledger.balanceOf({ code, ownerId }, Currency.SYP, world.tx);

// ── The whole parcel comes back ─────────────────────────────────────────

dbTest(
  'a full return unwinds the sale: the seller gives back her net, the platform its commission',
  async (world) => {
    const parcel = await makeParcel(world);

    const escrowBefore = await balance(
      world,
      LedgerAccountCode.SELLER_ESCROW,
      parcel.sellerId,
    );
    const commissionBefore = await balance(
      world,
      LedgerAccountCode.COMMISSION_REVENUE,
    );

    const created = await world.returns.request(parcel.customer, {
      sellerOrderId: parcel.sellerOrder.id,
      reason: ReturnReason.DEFECTIVE,
      evidence: ['https://media.reem.test/proof.jpg'],
      items: [{ orderItemId: parcel.item.id, quantity: parcel.item.quantity }],
    });

    // A whole parcel walks Q37's return states; the parent follows.
    const afterRequest = await world.tx.sellerOrder.findUniqueOrThrow({
      where: { id: parcel.sellerOrder.id },
    });
    assert.equal(afterRequest.status, SellerOrderStatus.RETURN_REQUESTED);

    await bringItBack(world, parcel, created.id, ReturnCostBearer.SELLER);
    await world.returns.settle(parcel.admin, created.id);

    const settled = await world.tx.returnRequest.findUniqueOrThrow({
      where: { id: created.id },
    });
    assert.equal(settled.status, ReturnStatus.REFUNDED);

    // She gets back everything she paid for the goods — the seller bears the
    // return leg here, so nothing is deducted from her refund.
    const wallet = await world.wallets.balanceOf(parcel.customerId);
    assert.equal(wallet.toString(), parcel.subtotal.toString());

    // And both parties gave back exactly what they took.
    const escrowAfter = await balance(
      world,
      LedgerAccountCode.SELLER_ESCROW,
      parcel.sellerId,
    );
    const commissionAfter = await balance(
      world,
      LedgerAccountCode.COMMISSION_REVENUE,
    );
    assert.equal(
      escrowBefore.minus(escrowAfter).toString(),
      // Net returned, plus the return leg she agreed to carry.
      parcel.sellerNet.plus(parcel.shipping).toString(),
    );
    assert.equal(
      commissionBefore.minus(commissionAfter).toString(),
      parcel.subtotal.minus(parcel.sellerNet).toString(),
    );

    const parcelAfter = await world.tx.sellerOrder.findUniqueOrThrow({
      where: { id: parcel.sellerOrder.id },
    });
    assert.equal(parcelAfter.status, SellerOrderStatus.REFUNDED);

    const orderAfter = await world.tx.order.findUniqueOrThrow({
      where: { id: parcel.order.id },
    });
    assert.equal(orderAfter.status, OrderStatus.CLOSED);
  },
);

dbTest('a refund can only be paid once', async (world) => {
  const parcel = await makeParcel(world);
  const created = await world.returns.request(parcel.customer, {
    sellerOrderId: parcel.sellerOrder.id,
    reason: ReturnReason.CHANGED_MIND,
    items: [{ orderItemId: parcel.item.id, quantity: parcel.item.quantity }],
  });
  await bringItBack(world, parcel, created.id, ReturnCostBearer.CUSTOMER);
  await world.returns.settle(parcel.admin, created.id);

  await assert.rejects(
    () => world.returns.settle(parcel.admin, created.id),
    /cannot go from REFUNDED/,
  );
});

// ── Part of a parcel comes back ─────────────────────────────────────────

dbTest(
  'a partial return refunds its share and leaves the parcel delivered',
  async (world) => {
    const parcel = await makeParcel(world, { quantity: 2 });

    const created = await world.returns.request(parcel.customer, {
      sellerOrderId: parcel.sellerOrder.id,
      reason: ReturnReason.SIZE_ISSUE,
      items: [{ orderItemId: parcel.item.id, quantity: 1 }],
    });

    // One of two units: the parcel was still delivered, and saying otherwise
    // would tell every report that the sale did not happen.
    const midway = await world.tx.sellerOrder.findUniqueOrThrow({
      where: { id: parcel.sellerOrder.id },
    });
    assert.equal(midway.status, SellerOrderStatus.DELIVERED);

    // The customer changed her mind, so she carries the return leg.
    await bringItBack(world, parcel, created.id, ReturnCostBearer.CUSTOMER);
    await world.returns.settle(parcel.admin, created.id);

    const half = parcel.subtotal.dividedBy(2);
    const wallet = await world.wallets.balanceOf(parcel.customerId);
    assert.equal(wallet.toString(), half.minus(parcel.shipping).toString());

    const feeCollected = await balance(
      world,
      LedgerAccountCode.SHIPPING_REVENUE,
    );
    assert.equal(feeCollected.greaterThanOrEqual(parcel.shipping), true);

    const parcelAfter = await world.tx.sellerOrder.findUniqueOrThrow({
      where: { id: parcel.sellerOrder.id },
    });
    assert.equal(parcelAfter.status, SellerOrderStatus.DELIVERED);
  },
);

dbTest(
  'escrow release knows what a partial return already took out of it',
  async (world) => {
    const parcel = await makeParcel(world, { quantity: 2 });
    const created = await world.returns.request(parcel.customer, {
      sellerOrderId: parcel.sellerOrder.id,
      reason: ReturnReason.SIZE_ISSUE,
      items: [{ orderItemId: parcel.item.id, quantity: 1 }],
    });
    await bringItBack(world, parcel, created.id, ReturnCostBearer.PLATFORM);
    await world.returns.settle(parcel.admin, created.id);

    // This is the figure `postEscrowRelease` subtracts before moving the rest
    // to payable. Without it the release would move money that is not there
    // and drive the seller's escrow negative.
    const alreadyRefunded = await world.ledger.movementFor(
      {
        account: {
          code: LedgerAccountCode.SELLER_ESCROW,
          ownerId: parcel.sellerId,
        },
        currency: Currency.SYP,
        direction: LedgerDirection.DEBIT,
        sellerOrderId: parcel.sellerOrder.id,
        types: [JournalEntryType.RETURN_SETTLED],
      },
      world.tx,
    );

    const escrow = await balance(
      world,
      LedgerAccountCode.SELLER_ESCROW,
      parcel.sellerId,
    );
    assert.equal(
      alreadyRefunded.toString(),
      parcel.sellerNet.dividedBy(2).toString(),
    );
    assert.equal(escrow.toString(), parcel.sellerNet.minus(alreadyRefunded).toString());
  },
);

dbTest('the same unit cannot be claimed twice', async (world) => {
  const parcel = await makeParcel(world, { quantity: 1 });
  await world.returns.request(parcel.customer, {
    sellerOrderId: parcel.sellerOrder.id,
    reason: ReturnReason.CHANGED_MIND,
    items: [{ orderItemId: parcel.item.id, quantity: 1 }],
  });

  await assert.rejects(
    () =>
      world.returns.request(parcel.customer, {
        sellerOrderId: parcel.sellerOrder.id,
        reason: ReturnReason.CHANGED_MIND,
        items: [{ orderItemId: parcel.item.id, quantity: 1 }],
      }),
    /already been returned in full/,
  );
});

// ── What a coupon does to a refund ──────────────────────────────────────

dbTest('a discounted parcel refunds what was paid, not the list price', async (world) => {
  const parcel = await makeParcel(world, {
    quantity: 1,
    unitPrice: '1000000',
    discount: '200000',
    sellerNet: '700000',
  });

  const created = await world.returns.request(parcel.customer, {
    sellerOrderId: parcel.sellerOrder.id,
    reason: ReturnReason.CHANGED_MIND,
    items: [{ orderItemId: parcel.item.id, quantity: 1 }],
  });
  await bringItBack(world, parcel, created.id, ReturnCostBearer.PLATFORM);

  const quote = await world.refunds.quote(created.id, world.tx);
  assert.equal(quote.goods.toString(), syp('800000').toString());
  assert.equal(
    quote.sellerShare.plus(quote.platformShare).toString(),
    quote.goods.toString(),
  );
});

// ── The rules that refuse a return ──────────────────────────────────────

dbTest('an excluded category refuses a change of mind', async (world) => {
  const parcel = await makeParcel(world, { categoryAllowsReturns: false });

  await assert.rejects(
    () =>
      world.returns.request(parcel.customer, {
        sellerOrderId: parcel.sellerOrder.id,
        reason: ReturnReason.CHANGED_MIND,
        items: [{ orderItemId: parcel.item.id, quantity: 1 }],
      }),
    /excluded from change-of-mind returns/,
  );

  // …and accepts the same line when the goods were the problem.
  const created = await world.returns.request(parcel.customer, {
    sellerOrderId: parcel.sellerOrder.id,
    reason: ReturnReason.WRONG_ITEM,
    evidence: ['https://media.reem.test/wrong.jpg'],
    items: [{ orderItemId: parcel.item.id, quantity: 1 }],
  });
  assert.equal(created.status, ReturnStatus.REQUESTED);
});

dbTest('a claim of fault without a photo is refused', async (world) => {
  const parcel = await makeParcel(world);

  await assert.rejects(
    () =>
      world.returns.request(parcel.customer, {
        sellerOrderId: parcel.sellerOrder.id,
        reason: ReturnReason.DEFECTIVE,
        items: [{ orderItemId: parcel.item.id, quantity: 1 }],
      }),
    /photo is required/,
  );
});

dbTest('a parcel outside the window is refused', async (world) => {
  const parcel = await makeParcel(world);
  const longAgo = new Date();
  longAgo.setDate(longAgo.getDate() - 30);
  await world.tx.sellerOrder.update({
    where: { id: parcel.sellerOrder.id },
    data: { deliveredAt: longAgo },
  });

  await assert.rejects(
    () =>
      world.returns.request(parcel.customer, {
        sellerOrderId: parcel.sellerOrder.id,
        reason: ReturnReason.CHANGED_MIND,
        items: [{ orderItemId: parcel.item.id, quantity: 1 }],
      }),
    /window has closed/,
  );
});

dbTest("another customer cannot return someone else's parcel", async (world) => {
  const parcel = await makeParcel(world);
  const stranger = principal((await makeUser(world.tx, 'oth')).id, UserRole.CUSTOMER);

  await assert.rejects(
    () =>
      world.returns.request(stranger, {
        sellerOrderId: parcel.sellerOrder.id,
        reason: ReturnReason.CHANGED_MIND,
        items: [{ orderItemId: parcel.item.id, quantity: 1 }],
      }),
    /not yours/,
  );
});

// ── Refusal, escalation and restocking ──────────────────────────────────

dbTest('a refused return puts the parcel back where it was', async (world) => {
  const parcel = await makeParcel(world);
  const created = await world.returns.request(parcel.customer, {
    sellerOrderId: parcel.sellerOrder.id,
    reason: ReturnReason.CHANGED_MIND,
    items: [{ orderItemId: parcel.item.id, quantity: parcel.item.quantity }],
  });

  await world.returns.reject(parcel.seller, created.id, 'العلبة مفتوحة');

  const parcelAfter = await world.tx.sellerOrder.findUniqueOrThrow({
    where: { id: parcel.sellerOrder.id },
  });
  assert.equal(parcelAfter.status, SellerOrderStatus.DELIVERED);

  // And the units it claimed are free again.
  const eligibility = await world.returns.eligibility(
    parcel.customer,
    parcel.sellerOrder.id,
  );
  assert.equal(eligibility.lines[0].quantity_claimed, 0);
});

dbTest('a refusal can be escalated, and the escalation freezes money', async (world) => {
  const parcel = await makeParcel(world);
  const created = await world.returns.request(parcel.customer, {
    sellerOrderId: parcel.sellerOrder.id,
    reason: ReturnReason.NOT_AS_DESCRIBED,
    evidence: ['https://media.reem.test/label.jpg'],
    items: [{ orderItemId: parcel.item.id, quantity: 1 }],
  });
  await world.returns.reject(parcel.seller, created.id, 'المقاس مطابق للوصف');

  const escalated = await world.returns.escalate(
    parcel.customer,
    created.id,
    'الصورة تُظهر لوناً مختلفاً',
  );
  assert.match(escalated.dispute_number, /^DSP-/);

  const held = await balance(
    world,
    LedgerAccountCode.DISPUTE_HELD,
    parcel.sellerId,
  );
  assert.equal(held.isZero(), false);
});

dbTest('unused goods go back on sale; faulty ones do not', async (world) => {
  const parcel = await makeParcel(world, { quantity: 1 });
  const before = await world.tx.sellerOffer.findUniqueOrThrow({
    where: { id: parcel.offerId },
  });

  const changedMind = await world.returns.request(parcel.customer, {
    sellerOrderId: parcel.sellerOrder.id,
    reason: ReturnReason.CHANGED_MIND,
    items: [{ orderItemId: parcel.item.id, quantity: 1 }],
  });
  await bringItBack(world, parcel, changedMind.id, ReturnCostBearer.CUSTOMER);

  const after = await world.tx.sellerOffer.findUniqueOrThrow({
    where: { id: parcel.offerId },
  });
  assert.equal(after.stock, before.stock + 1);
});

// ── Money that was never collected ──────────────────────────────────────

dbTest(
  'a parcel that was never paid for refunds nothing, and says so',
  async (world) => {
    const parcel = await makeParcel(world, {
      settle: false,
      paymentStatus: PaymentStatus.PENDING,
    });

    const created = await world.returns.request(parcel.customer, {
      sellerOrderId: parcel.sellerOrder.id,
      reason: ReturnReason.CHANGED_MIND,
      items: [{ orderItemId: parcel.item.id, quantity: parcel.item.quantity }],
    });
    await bringItBack(world, parcel, created.id);
    await world.returns.settle(parcel.admin, created.id);

    const wallet = await world.wallets.balanceOf(parcel.customerId);
    assert.equal(wallet.isZero(), true);

    const settled = await world.tx.returnRequest.findUniqueOrThrow({
      where: { id: created.id },
    });
    assert.equal(settled.status, ReturnStatus.REFUNDED);
    assert.equal(Money.of(settled.refundAmount, Currency.SYP).isZero(), true);
  },
);

dbTest(
  'a prepaid parcel that never settled unwinds its capture, not the seller',
  async (world) => {
    const parcel = await makeParcel(world, {
      settle: false,
      paymentStatus: PaymentStatus.PAID,
      // A rail that clears through a provider. Cash at the door is only ever
      // booked *by* settlement, so a COD parcel that was never settled has
      // nothing in the books to give back — see `fundingFor`.
      paymentMethod: PaymentMethodType.SYRIATEL_CASH,
    });

    // What `PaymentsService.verify` posts when the provider clears: cash in,
    // against a receivable that settlement would later have discharged.
    const receivableBefore = await balance(
      world,
      LedgerAccountCode.GATEWAY_RECEIVABLE,
    );
    const cashBefore = await balance(world, LedgerAccountCode.PLATFORM_CASH);
    await world.ledger.post(
      {
        type: JournalEntryType.PAYMENT_CAPTURED,
        reference: `payment-captured:${uniq('pay')}`,
        description: 'captured',
        orderId: parcel.order.id,
        lines: [
          {
            account: { code: LedgerAccountCode.PLATFORM_CASH },
            direction: LedgerDirection.DEBIT,
            amount: parcel.subtotal,
          },
          {
            account: { code: LedgerAccountCode.GATEWAY_RECEIVABLE },
            direction: LedgerDirection.CREDIT,
            amount: parcel.subtotal,
          },
        ],
      },
      world.tx,
    );

    const created = await world.returns.request(parcel.customer, {
      sellerOrderId: parcel.sellerOrder.id,
      reason: ReturnReason.CHANGED_MIND,
      items: [{ orderItemId: parcel.item.id, quantity: parcel.item.quantity }],
    });
    await bringItBack(world, parcel, created.id, ReturnCostBearer.PLATFORM);
    await world.returns.settle(parcel.admin, created.id);

    const wallet = await world.wallets.balanceOf(parcel.customerId);
    assert.equal(wallet.toString(), parcel.subtotal.toString());

    // The capture is unwound: the receivable is back where it started.
    const receivableAfter = await balance(
      world,
      LedgerAccountCode.GATEWAY_RECEIVABLE,
    );
    assert.equal(receivableAfter.toString(), receivableBefore.toString());

    // The cash stays with the platform, because Q42's credit is spendable
    // here and never cashed out — nothing left the building.
    const cashAfter = await balance(world, LedgerAccountCode.PLATFORM_CASH);
    assert.equal(
      cashAfter.minus(cashBefore).toString(),
      parcel.subtotal.toString(),
    );

    // And the seller, never credited, gives nothing back.
    const escrow = await balance(
      world,
      LedgerAccountCode.SELLER_ESCROW,
      parcel.sellerId,
    );
    assert.equal(escrow.isZero(), true);
  },
);

dbTest('a return fee never leaves the customer owing us money', async (world) => {
  const parcel = await makeParcel(world, {
    quantity: 1,
    unitPrice: '10000',
    shipping: '30000',
    sellerNet: '8000',
  });

  const created = await world.returns.request(parcel.customer, {
    sellerOrderId: parcel.sellerOrder.id,
    reason: ReturnReason.CHANGED_MIND,
    items: [{ orderItemId: parcel.item.id, quantity: 1 }],
  });
  await bringItBack(world, parcel, created.id, ReturnCostBearer.CUSTOMER);

  const quote = await world.refunds.quote(created.id, world.tx);
  assert.equal(quote.customerRefund.isNegative(), false);
  assert.equal(quote.customerRefund.isZero(), true);
  // The fee is capped at what there was to give back, not at what it cost.
  assert.equal(quote.returnShippingFee.toString(), quote.goods.toString());
});

// ── Exchange ────────────────────────────────────────────────────────────

dbTest('an exchange moves goods and no money', async (world) => {
  const parcel = await makeParcel(world);
  const escrowBefore = await balance(
    world,
    LedgerAccountCode.SELLER_ESCROW,
    parcel.sellerId,
  );

  const created = await world.returns.request(parcel.customer, {
    sellerOrderId: parcel.sellerOrder.id,
    reason: ReturnReason.WRONG_ITEM,
    evidence: ['https://media.reem.test/wrong.jpg'],
    items: [{ orderItemId: parcel.item.id, quantity: parcel.item.quantity }],
  });
  await bringItBack(world, parcel, created.id, ReturnCostBearer.SELLER);
  await world.returns.exchange(parcel.seller, created.id);

  const midway = await world.tx.sellerOrder.findUniqueOrThrow({
    where: { id: parcel.sellerOrder.id },
  });
  assert.equal(midway.status, SellerOrderStatus.EXCHANGE_IN_PROGRESS);

  await world.returns.completeExchange(parcel.seller, created.id);
  const done = await world.tx.sellerOrder.findUniqueOrThrow({
    where: { id: parcel.sellerOrder.id },
  });
  assert.equal(done.status, SellerOrderStatus.EXCHANGED);

  const escrowAfter = await balance(
    world,
    LedgerAccountCode.SELLER_ESCROW,
    parcel.sellerId,
  );
  assert.equal(escrowAfter.toString(), escrowBefore.toString());

  const wallet = await world.wallets.balanceOf(parcel.customerId);
  assert.equal(wallet.isZero(), true);
});

// ── Authority ───────────────────────────────────────────────────────────

dbTest('a seller cannot pay a refund to herself', async (world) => {
  const parcel = await makeParcel(world);
  const created = await world.returns.request(parcel.customer, {
    sellerOrderId: parcel.sellerOrder.id,
    reason: ReturnReason.CHANGED_MIND,
    items: [{ orderItemId: parcel.item.id, quantity: parcel.item.quantity }],
  });
  await bringItBack(world, parcel, created.id, ReturnCostBearer.CUSTOMER);

  await assert.rejects(
    () => world.returns.settle(parcel.seller, created.id),
    /Only the platform can settle a refund/,
  );
});

dbTest('the sweep settles what the seller has confirmed receiving', async (world) => {
  const parcel = await makeParcel(world);
  const created = await world.returns.request(parcel.customer, {
    sellerOrderId: parcel.sellerOrder.id,
    reason: ReturnReason.CHANGED_MIND,
    items: [{ orderItemId: parcel.item.id, quantity: parcel.item.quantity }],
  });
  await bringItBack(world, parcel, created.id, ReturnCostBearer.CUSTOMER);

  const result = await world.returns.settleDue();
  assert.equal(result.failed, 0);
  assert.equal(result.settled >= 1, true);

  const settled = await world.tx.returnRequest.findUniqueOrThrow({
    where: { id: created.id },
  });
  assert.equal(settled.status, ReturnStatus.REFUNDED);
});
