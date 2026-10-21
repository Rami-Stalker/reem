import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  OrderStatus,
  PrismaClient,
  ReturnReason,
  ReturnStatus,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { SizeFitService } from './size-fit.service';

/**
 * Size fit against real Postgres, inside a transaction that is rolled back.
 *
 * The kernel is tested on its own; what this pins is the query — which
 * orders count as having reached her, which returns count as a size problem,
 * and that a size is read off the variant whatever else the variant is.
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

test.after(async () => {
  await prisma.$disconnect();
});

let counter = 0;
const uniq = (tag: string) =>
  `${tag}${Date.now().toString(36)}${(counter++).toString(36)}`;

async function makeUser(tx: Tx, tag: string, role: UserRole) {
  return tx.user.create({
    data: {
      name: `fit-${tag}`,
      username: `fit_${uniq(tag)}`,
      phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role,
    },
  });
}

test('a size is kept or not by the women it reached', async (t) => {
  if (!reachable) {
    t.skip('no database reachable');
    return;
  }

  let failure: unknown;
  try {
    await prisma.$transaction(
      async (tx) => {
        try {
          await scenario(tx);
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

async function scenario(tx: Tx) {
  const seller = await makeUser(tx, 'sel', UserRole.SELLER);
  const customer = await makeUser(tx, 'cus', UserRole.CUSTOMER);

  const category = await tx.category.create({
    data: { slug: `cat-${uniq('c')}`, nameAr: 'فساتين', nameEn: 'Dresses' },
  });
  const product = await tx.product.create({
    data: {
      slug: `prod-${uniq('p')}`,
      title: 'فستان خوخي',
      description: 'للاختبار',
      categoryId: category.id,
    },
  });
  const offer = await tx.sellerOffer.create({
    data: {
      productId: product.id,
      sellerId: seller.id,
      currency: Currency.SYP,
      price: '52000',
      stock: 100,
    },
  });

  const variant = (name: string, attributes: Record<string, string>) =>
    tx.productVariant.create({
      data: { productId: product.id, name, attributes },
    });
  // One M in two colours, spelled two ways; an L; and a variant with no size.
  const mRed = await variant('M أحمر', { size: 'M', color: 'أحمر' });
  const mNavy = await variant('M كحلي', { size: ' m ', color: 'كحلي' });
  const large = await variant('L', { size: 'L' });
  const noSize = await variant('عطر', { scent: 'ياسمين' });

  /** One parcel of [quantity] units of [variantId], in [status]. */
  async function deliver(
    variantId: string,
    quantity: number,
    status: SellerOrderStatus = SellerOrderStatus.DELIVERED,
  ) {
    const order = await tx.order.create({
      data: {
        number: `ORD-${uniq('o').slice(-12)}`,
        userId: customer.id,
        status: OrderStatus.DELIVERED,
        currency: Currency.SYP,
        fxRate: '13000',
        itemsSubtotal: '0',
        discountTotal: '0',
        shippingTotal: '0',
        grandTotal: '0',
        recipientName: 'ريم',
        recipientPhone: '+963900000000',
        governorate: 'دمشق',
        city: 'دمشق',
        addressLine: 'المزة',
      },
    });
    const sellerOrder = await tx.sellerOrder.create({
      data: {
        orderId: order.id,
        number: `SUB-${uniq('s').slice(-12)}`,
        sellerId: seller.id,
        status,
        currency: Currency.SYP,
        itemsSubtotal: '0',
        discountTotal: '0',
        shippingCost: '0',
        commissionBase: '0',
        commissionAmount: '0',
        sellerNet: '0',
        items: {
          create: {
            offerId: offer.id,
            productId: product.id,
            variantId,
            titleSnapshot: product.title,
            sellerSnapshot: 'بائعة',
            currency: Currency.SYP,
            unitPrice: '52000',
            quantity,
            lineTotal: '0',
          },
        },
      },
      include: { items: true },
    });
    return { sellerOrder, item: sellerOrder.items[0] };
  }

  async function returned(
    parcel: Awaited<ReturnType<typeof deliver>>,
    quantity: number,
    reason: ReturnReason,
    status: ReturnStatus,
  ) {
    await tx.returnRequest.create({
      data: {
        number: `RET-${uniq('r').slice(-12)}`,
        sellerOrderId: parcel.sellerOrder.id,
        requestedById: customer.id,
        reason,
        status,
        currency: Currency.SYP,
        windowClosesAt: new Date(Date.now() + 86_400_000),
        items: { create: { orderItemId: parcel.item.id, quantity } },
      },
    });
  }

  // M: 7 red + 5 navy reached her, so 12.
  const red = await deliver(mRed.id, 7);
  const navy = await deliver(mNavy.id, 5, SellerOrderStatus.RETURN_REQUESTED);
  // One M came back for the size, and was taken back.
  await returned(red, 1, ReturnReason.SIZE_ISSUE, ReturnStatus.APPROVED);
  // These are not evidence about the size: a request the seller turned down,
  // and a return for a fault.
  await returned(navy, 1, ReturnReason.SIZE_ISSUE, ReturnStatus.REJECTED);
  await returned(red, 1, ReturnReason.DEFECTIVE, ReturnStatus.REFUNDED);
  // Never reached anyone: says nothing about fit.
  await deliver(mRed.id, 5, SellerOrderStatus.CANCELLED_BY_CUSTOMER);

  // L: too few to say anything.
  await deliver(large.id, 4);
  // No size at all.
  await deliver(noSize.id, 30);

  const fits = await new SizeFitService(
    tx as unknown as PrismaService,
  ).forProduct(product.id);

  assert.deepEqual(fits, [
    { size: 'M', keptRate: 0.92 },
    { size: 'L', keptRate: null },
  ]);
}
