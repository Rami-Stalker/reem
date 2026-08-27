import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';
import {
  Currency,
  InvoiceKind,
  OrderStatus,
  PrismaClient,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { InvoicesService } from './invoices.service';

/**
 * Q51 — «الاثنين»: one invoice for the order, one per seller.
 *
 * The things worth proving are not that a row appears. They are that a
 * customer who taps twice gets one document, that a document cannot be issued
 * while the order can still change under it, and that a seller cannot read the
 * customer's copy — which names every other seller in her basket.
 */
const prisma = new PrismaClient();
const invoices = new InvoicesService(prisma as unknown as PrismaService);

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

async function makeUser(tx: Tx, tag: string, role: UserRole = UserRole.CUSTOMER) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `inv-${tag}`,
      username: `inv_${u}`,
      phone: `+9639${u.slice(-8)}`,
      passwordHash: 'x',
      role,
    },
  });
}

/** A two-seller basket, shipped — the shape Q40 and Q51 describe together. */
async function makeBasket(tx: Tx, status: OrderStatus = OrderStatus.SHIPPED) {
  const customer = await makeUser(tx, 'cus');
  const sellerA = await makeUser(tx, 'sa', UserRole.SELLER);
  const sellerB = await makeUser(tx, 'sb', UserRole.SELLER);

  const order = await tx.order.create({
    data: {
      number: `ORD-${uniq('o').slice(-10)}`,
      userId: customer.id,
      status,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: '900000',
      discountTotal: '50000',
      shippingTotal: '20000',
      grandTotal: '870000',
      recipientName: 'ريم الدالي',
      recipientPhone: '+963900000000',
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
    },
  });

  const subA = await tx.sellerOrder.create({
    data: {
      orderId: order.id,
      number: `SUB-${uniq('a').slice(-10)}`,
      sellerId: sellerA.id,
      status: SellerOrderStatus.IN_TRANSIT,
      currency: Currency.SYP,
      itemsSubtotal: '600000',
      discountTotal: '50000',
      shippingCost: '20000',
      commissionBase: '550000',
      commissionAmount: '82500',
      sellerNet: '467500',
      items: {
        create: {
          titleSnapshot: 'فستان سهرة مطرّز',
          sellerSnapshot: 'أتيليه رهف',
          currency: Currency.SYP,
          unitPrice: '600000',
          unitDiscount: '50000',
          quantity: 1,
          lineTotal: '550000',
        },
      },
    },
  });

  const subB = await tx.sellerOrder.create({
    data: {
      orderId: order.id,
      number: `SUB-${uniq('b').slice(-10)}`,
      sellerId: sellerB.id,
      status: SellerOrderStatus.IN_TRANSIT,
      currency: Currency.SYP,
      itemsSubtotal: '300000',
      commissionBase: '300000',
      commissionAmount: '45000',
      sellerNet: '255000',
      items: {
        create: {
          titleSnapshot: 'عطر شرقي ٥٠ مل',
          sellerSnapshot: 'بوتيك ريم',
          currency: Currency.SYP,
          unitPrice: '300000',
          quantity: 1,
          lineTotal: '300000',
        },
      },
    },
  });

  return { customer, sellerA, sellerB, order, subA, subB };
}

// ── Both kinds (Q51) ──────────────────────────────────────────────────────

dbTest('an order gets one invoice and each seller gets their own', async () => {
  await inRolledBackTx(async (tx) => {
    const { order, subA, subB } = await makeBasket(tx);

    const forOrder = await invoices.issueForOrder(order.id, {}, tx);
    const forA = await invoices.issueForSellerOrder(subA.id, {}, tx);
    const forB = await invoices.issueForSellerOrder(subB.id, {}, tx);

    assert.equal(forOrder.kind, InvoiceKind.ORDER);
    assert.equal(forA.kind, InvoiceKind.SELLER_ORDER);
    assert.equal(forB.kind, InvoiceKind.SELLER_ORDER);

    // Three distinct documents against one basket.
    const numbers = new Set([forOrder.number, forA.number, forB.number]);
    assert.equal(numbers.size, 3, 'each document needs its own number');

    // The customer's copy is what she actually paid.
    assert.equal(forOrder.grandTotal.toString(), '870000');

    // A seller's copy covers only their parcel.
    assert.equal(forA.grandTotal.toString(), '570000');
    assert.equal(forB.grandTotal.toString(), '300000');
  });
});

dbTest('only the seller copy carries the commission', async () => {
  await inRolledBackTx(async (tx) => {
    const { order, subA } = await makeBasket(tx);

    const forOrder = await invoices.issueForOrder(order.id, {}, tx);
    const forSeller = await invoices.issueForSellerOrder(subA.id, {}, tx);

    // What the platform took is between the platform and the seller; on the
    // customer's document it would only obscure the figure she paid.
    assert.equal(forOrder.commissionAmount, null);
    assert.equal(forOrder.sellerNet, null);

    assert.equal(forSeller.commissionAmount?.toString(), '82500');
    assert.equal(forSeller.sellerNet?.toString(), '467500');
  });
});

// ── Idempotency ───────────────────────────────────────────────────────────

dbTest('issuing twice returns the same document, not a second one', async () => {
  await inRolledBackTx(async (tx) => {
    const { order } = await makeBasket(tx);

    const first = await invoices.issueForOrder(order.id, {}, tx);
    const second = await invoices.issueForOrder(order.id, {}, tx);

    assert.equal(second.id, first.id);
    assert.equal(second.number, first.number);

    const count = await tx.invoice.count({
      where: { orderId: order.id, kind: InvoiceKind.ORDER },
    });
    assert.equal(count, 1, 'one purchase, one invoice');
  });
});

// ── The edit window (Q39) ─────────────────────────────────────────────────

dbTest('an order that can still be changed cannot be invoiced', async () => {
  await inRolledBackTx(async (tx) => {
    // Q39 — «نعم قبل التجهيز». A document issued now would be contradicted by
    // the order an hour later.
    const { order } = await makeBasket(tx, OrderStatus.CONFIRMED);

    await assert.rejects(
      invoices.issueForOrder(order.id, {}, tx),
      /can still be changed/,
    );
  });
});

dbTest('a partially shipped basket is invoiceable', async () => {
  await inRolledBackTx(async (tx) => {
    // One seller has shipped and another has not — still a real charge for
    // the part that moved.
    const { order } = await makeBasket(tx, OrderStatus.PARTIALLY_SHIPPED);
    const invoice = await invoices.issueForOrder(order.id, {}, tx);
    assert.ok(invoice.number.startsWith('INV-'));
  });
});

// ── Totals are frozen (Q39) ───────────────────────────────────────────────

dbTest('the invoice keeps its totals when the order later changes', async () => {
  await inRolledBackTx(async (tx) => {
    const { order } = await makeBasket(tx);
    const invoice = await invoices.issueForOrder(order.id, {}, tx);

    // Something restates the order afterwards — a partial cancellation, say.
    await tx.order.update({
      where: { id: order.id },
      data: { grandTotal: '400000', itemsSubtotal: '400000' },
    });

    const reread = await tx.invoice.findUniqueOrThrow({
      where: { id: invoice.id },
    });
    assert.equal(
      reread.grandTotal.toString(),
      '870000',
      'a document does not silently restate itself',
    );
  });
});

// ── Who may read what ─────────────────────────────────────────────────────

dbTest('a seller cannot read the customer’s copy of the basket', async () => {
  await inRolledBackTx(async (tx) => {
    const { order, sellerA } = await makeBasket(tx);
    await invoices.issueForOrder(order.id, {}, tx);
  });

  // `render` reads through the root client, so this runs on committed data:
  // build the basket, assert, then clean up what was created.
  const built = await prisma.$transaction(async (tx) => {
    const basket = await makeBasket(tx as Tx);
    const invoice = await invoices.issueForOrder(
      basket.order.id,
      {},
      tx as Tx,
    );
    return { ...basket, invoice };
  });

  try {
    // The customer's invoice names every seller in her basket — Q44's privacy
    // stance would not survive a competitor reading it.
    await assert.rejects(
      invoices.render(built.invoice.id, {
        id: built.sellerA.id,
        role: UserRole.SELLER,
      }),
      /not yours/,
    );

    // She can read her own.
    const rendered = await invoices.render(built.invoice.id, {
      id: built.customer.id,
      role: UserRole.CUSTOMER,
    });
    assert.equal(rendered.number, built.invoice.number);
    assert.equal(rendered.lines.length, 2, 'both sellers appear on her copy');
    assert.equal(rendered.billed_to.name, 'ريم الدالي');
  } finally {
    await prisma.order.delete({ where: { id: built.order.id } });
    await prisma.user.deleteMany({
      where: {
        id: {
          in: [built.customer.id, built.sellerA.id, built.sellerB.id],
        },
      },
    });
  }
});

// ── Who may raise what ────────────────────────────────────────────────────

/**
 * Issuing hands back the document, so it is a read as much as a write — and
 * the two POST routes took no viewer at all. A seller sees the parent order's
 * id on her own sub-order, which is all `issueForOrder` ever asked for: the
 * whole basket's totals, for any seller holding one line of it.
 */
dbTest('a seller cannot raise the customer’s copy of the basket', async () => {
  await inRolledBackTx(async (tx) => {
    const { order, sellerA } = await makeBasket(tx);

    await assert.rejects(
      invoices.issueForOrder(
        order.id,
        { viewer: { id: sellerA.id, role: UserRole.SELLER } },
        tx,
      ),
      /not yours/,
    );

    assert.equal(
      await tx.invoice.count({ where: { orderId: order.id } }),
      0,
      'a refused issue must not leave a numbered document behind',
    );
  });
});

dbTest('a seller cannot raise another seller’s copy', async () => {
  await inRolledBackTx(async (tx) => {
    const { subB, sellerA } = await makeBasket(tx);

    // `subB` carries B's commission and net — what the platform charges a
    // competitor is not A's business.
    await assert.rejects(
      invoices.issueForSellerOrder(
        subB.id,
        { viewer: { id: sellerA.id, role: UserRole.SELLER } },
        tx,
      ),
      /not yours/,
    );
  });
});

dbTest('an unrelated customer cannot raise a stranger’s invoice', async () => {
  await inRolledBackTx(async (tx) => {
    const { order } = await makeBasket(tx);

    await assert.rejects(
      invoices.issueForOrder(
        order.id,
        { viewer: { id: randomUUID(), role: UserRole.CUSTOMER } },
        tx,
      ),
      /not yours/,
    );
  });
});

dbTest('the people it belongs to may still raise it', async () => {
  await inRolledBackTx(async (tx) => {
    const { order, subA, customer, sellerA } = await makeBasket(tx);

    const hers = await invoices.issueForOrder(
      order.id,
      { viewer: { id: customer.id, role: UserRole.CUSTOMER } },
      tx,
    );
    assert.equal(hers.kind, InvoiceKind.ORDER);

    const his = await invoices.issueForSellerOrder(
      subA.id,
      { viewer: { id: sellerA.id, role: UserRole.SELLER } },
      tx,
    );
    assert.equal(his.kind, InvoiceKind.SELLER_ORDER);

    // And the customer may read the seller's copy of her own purchase.
    const alsoHers = await invoices.issueForSellerOrder(
      subA.id,
      { viewer: { id: customer.id, role: UserRole.CUSTOMER } },
      tx,
    );
    assert.equal(alsoHers.id, his.id);
  });
});

dbTest('finance may raise either, and the platform itself needs no viewer', async () => {
  await inRolledBackTx(async (tx) => {
    const { order, subA } = await makeBasket(tx);

    const byFinance = await invoices.issueForOrder(
      order.id,
      { viewer: { id: randomUUID(), role: UserRole.FINANCE_ADMIN } },
      tx,
    );
    assert.equal(byFinance.kind, InvoiceKind.ORDER);

    // No viewer: checkout and settlement issue inside their own transaction,
    // having already decided.
    const bySystem = await invoices.issueForSellerOrder(subA.id, {}, tx);
    assert.equal(bySystem.kind, InvoiceKind.SELLER_ORDER);
  });
});

test.after(async () => {
  await prisma.$disconnect();
});
