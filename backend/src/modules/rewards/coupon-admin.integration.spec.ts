import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CouponType,
  Currency,
  PrismaClient,
  ProductStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { CouponsService } from './coupons.service';

/**
 * Whether an operator can actually reach the scope the checkout enforces.
 *
 * Phase 2 gave coupons `seller_id`, `category_id` and `product_id`, and taught
 * checkout to discount only the lines a code covers — closing the case where
 * one boutique paid for another's promotion. The control was left unreachable:
 * the admin DTO had no such fields, so the only way to scope a code was to
 * edit the row by hand. A rule nobody can set is a rule nobody uses.
 *
 * These also pin the validation, which matters more than it looks: a mistyped
 * id would create a code that covers no line in any basket. It would validate,
 * activate, and sit in the console looking live while refusing every customer
 * who typed it.
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
            await body({ tx, coupons: new CouponsService(asPrisma(tx)) });
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
  coupons: CouponsService;
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;
const phone = () =>
  `+9639${Math.floor(10_000_000 + Math.random() * 89_999_999)}`;

async function makeUser(tx: Tx, role: UserRole) {
  const u = uniq('u');
  return tx.user.create({
    data: {
      name: 'cp',
      username: `cp_${u}`,
      phone: phone(),
      passwordHash: 'x',
      role,
    },
  });
}

async function makeCategory(tx: Tx) {
  const u = uniq('c');
  return tx.category.create({
    data: { slug: `cp-cat-${u}`, nameAr: 'فئة', nameEn: 'Cat' },
  });
}

async function makeProduct(tx: Tx, categoryId: string) {
  const u = uniq('p');
  return tx.product.create({
    data: {
      slug: `cp-prod-${u}`,
      title: 'فستان',
      description: 'اختبار',
      categoryId,
      status: ProductStatus.ACTIVE,
    },
  });
}

const base = () => ({
  code: `CP${uniq('x').slice(-10)}`,
  title: 'خصم',
  type: CouponType.PERCENTAGE,
  discount_percent: 10,
  expires_at: new Date(Date.now() + 7 * 86_400_000).toISOString(),
});

// ── Setting a scope ─────────────────────────────────────────────────────

dbTest('an operator can scope a code to one boutique', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);

  const created = (await world.coupons.create({
    ...base(),
    seller_id: seller.id,
  } as never)) as { seller_id: string | null; id: string };

  assert.equal(created.seller_id, seller.id);

  const row = await world.tx.coupon.findUniqueOrThrow({
    where: { id: created.id },
  });
  assert.equal(row.sellerId, seller.id);
});

dbTest('a code can be scoped to a category and a product', async (world) => {
  const category = await makeCategory(world.tx);
  const product = await makeProduct(world.tx, category.id);

  const created = (await world.coupons.create({
    ...base(),
    category_id: category.id,
    product_id: product.id,
  } as never)) as { category_id: string | null; product_id: string | null };

  assert.equal(created.category_id, category.id);
  assert.equal(created.product_id, product.id);
});

dbTest('an unscoped code still covers the whole basket', async (world) => {
  const created = (await world.coupons.create(base() as never)) as {
    seller_id: string | null;
    category_id: string | null;
    product_id: string | null;
  };

  assert.equal(created.seller_id, null);
  assert.equal(created.category_id, null);
  assert.equal(created.product_id, null);
});

// ── Refusing a scope that names nothing ─────────────────────────────────

dbTest('a scope naming a shopper is refused', async (world) => {
  const shopper = await makeUser(world.tx, UserRole.CUSTOMER);

  await assert.rejects(
    world.coupons.create({ ...base(), seller_id: shopper.id } as never),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'COUPON_SCOPE_NOT_A_SELLER',
    'a discount scoped to a shopper is a code nobody can ever spend',
  );
});

dbTest('a scope naming nothing at all is refused', async (world) => {
  const ghost = '00000000-0000-4000-8000-000000000000';

  await assert.rejects(
    world.coupons.create({ ...base(), category_id: ghost } as never),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'COUPON_SCOPE_CATEGORY_NOT_FOUND',
  );
  await assert.rejects(
    world.coupons.create({ ...base(), product_id: ghost } as never),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'COUPON_SCOPE_PRODUCT_NOT_FOUND',
  );
});

// ── Narrowing and widening after issue ──────────────────────────────────

dbTest('a scope can be corrected after the code is live', async (world) => {
  const wrong = await makeUser(world.tx, UserRole.SELLER);
  const right = await makeUser(world.tx, UserRole.SELLER);

  const created = (await world.coupons.create({
    ...base(),
    seller_id: wrong.id,
  } as never)) as { id: string };

  const fixed = (await world.coupons.update(created.id, {
    seller_id: right.id,
  } as never)) as { seller_id: string | null };

  assert.equal(fixed.seller_id, right.id);
});

dbTest('a scope can be cleared back to the whole basket', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const created = (await world.coupons.create({
    ...base(),
    seller_id: seller.id,
  } as never)) as { id: string };

  // `null` is meaningful and distinct from absent. Without this an operator
  // who scoped a code to the wrong boutique could only fix it by deleting a
  // code customers may already be holding.
  const widened = (await world.coupons.update(created.id, {
    seller_id: null,
  } as never)) as { seller_id: string | null };

  assert.equal(widened.seller_id, null);
});

dbTest('an update that mentions no scope leaves it alone', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const created = (await world.coupons.create({
    ...base(),
    seller_id: seller.id,
  } as never)) as { id: string };

  const renamed = (await world.coupons.update(created.id, {
    title: 'اسم جديد',
  } as never)) as { seller_id: string | null; title: string };

  assert.equal(renamed.title, 'اسم جديد');
  assert.equal(
    renamed.seller_id,
    seller.id,
    'absent is not the same as null — editing the title must not widen the code',
  );
});

dbTest('a correction is validated too', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const shopper = await makeUser(world.tx, UserRole.CUSTOMER);
  const created = (await world.coupons.create({
    ...base(),
    seller_id: seller.id,
  } as never)) as { id: string };

  await assert.rejects(
    world.coupons.update(created.id, { seller_id: shopper.id } as never),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'COUPON_SCOPE_NOT_A_SELLER',
  );
});

// ── What the console reads back ─────────────────────────────────────────

dbTest('the scope is visible to whoever has to administer it', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  await world.coupons.create({
    ...base(),
    seller_id: seller.id,
  } as never);

  const listed = (await world.coupons.listAll({
    page: 1,
    limit: 20,
    skip: 0,
  } as never)) as { data: Array<{ seller_id: string | null }> };

  assert.ok(
    listed.data.some((row) => row.seller_id === seller.id),
    'a scope the operator cannot see is a scope she cannot correct',
  );
});
