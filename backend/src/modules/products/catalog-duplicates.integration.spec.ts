import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  DuplicateVerdict,
  OfferStatus,
  PrismaClient,
  ProductStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { CatalogDuplicatesService } from './catalog-duplicates.service';

/**
 * One garment, listed twice.
 *
 * Ohara's catalogue puts one `Product` row behind many `SellerOffer` rows so
 * that boutiques selling the same dress compete on one page. A second product
 * row for a garment that already exists splits those offers in half, and the
 * comparison the design exists to provide silently stops happening. Nothing
 * looked for it.
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

test.after(async () => {
  await prisma.$disconnect();
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

let seq = 0;
const uniq = () => `${Date.now()}${(seq += 1)}`;

interface Shelf {
  service: CatalogDuplicatesService;
  categoryId: string;
  ids: Record<string, string>;
  sellerIds: string[];
  destroy: () => Promise<void>;
}

/**
 * A category with the given listings. `sellerFor` decides which boutique
 * carries each, so "the same seller listed it twice" can be told apart from
 * "two boutiques listed it".
 */
async function openShelf(
  titles: Record<string, string>,
  sellerFor: Record<string, number> = {},
): Promise<Shelf> {
  const u = uniq();
  const sellers = await Promise.all(
    [0, 1].map((n) =>
      prisma.user.create({
        data: {
          name: `بوتيك ${n}`,
          username: `dup_${u}_${n}`,
          phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
          passwordHash: 'x',
          role: UserRole.SELLER,
        },
      }),
    ),
  );
  const category = await prisma.category.create({
    data: { slug: `dup-cat-${u}`, nameAr: 'فساتين', nameEn: 'Dresses' },
  });

  const ids: Record<string, string> = {};
  let n = 0;
  for (const [key, title] of Object.entries(titles)) {
    n += 1;
    const product = await prisma.product.create({
      data: {
        slug: `dup-prod-${u}-${n}`,
        title,
        description: 'قطعة من مجموعة الاختبار.',
        categoryId: category.id,
        status: ProductStatus.ACTIVE,
        offers: {
          create: {
            sellerId: sellers[sellerFor[key] ?? 0].id,
            currency: Currency.SYP,
            price: '100000',
            stock: 3,
            status: OfferStatus.ACTIVE,
            isActive: true,
          },
        },
      },
    });
    ids[key] = product.id;
  }

  return {
    service: new CatalogDuplicatesService(prisma as unknown as PrismaService),
    categoryId: category.id,
    ids,
    sellerIds: sellers.map((s) => s.id),
    destroy: async () => {
      await prisma.productDuplicateVerdict.deleteMany({
        where: { leftProductId: { in: Object.values(ids) } },
      });
      await prisma.product.deleteMany({
        where: { id: { in: Object.values(ids) } },
      });
      await prisma.category.delete({ where: { id: category.id } });
      await prisma.user.deleteMany({
        where: { id: { in: sellers.map((s) => s.id) } },
      });
    },
  };
}

const pairOf = (shelf: Shelf, a: string, b: string) =>
  [shelf.ids[a], shelf.ids[b]].sort().join('|');

dbTest('the same dress written two ways is surfaced as one pair', async () => {
  const shelf = await openShelf(
    {
      first: 'فستان سهرة أحمر طويل',
      second: 'فستان سهرة احمر طويل',
      other: 'حقيبة يد جلدية سوداء',
    },
    { first: 0, second: 1, other: 0 },
  );
  try {
    const found = await shelf.service.candidates({
      categoryId: shelf.categoryId,
      limit: 20,
      skip: 0,
    });

    const pairs = found.map((c) => [c.left.id, c.right.id].sort().join('|'));
    assert.ok(
      pairs.includes(pairOf(shelf, 'first', 'second')),
      'the two spellings of one dress are the same garment',
    );
    assert.ok(
      !pairs.includes(pairOf(shelf, 'first', 'other')),
      'a handbag is not a dress, however loose the threshold',
    );
  } finally {
    await shelf.destroy();
  }
});

dbTest('a pair is offered once, not once per direction', async () => {
  const shelf = await openShelf({
    first: 'فستان سهرة أحمر طويل',
    second: 'فستان سهرة احمر طويل',
  });
  try {
    const found = await shelf.service.candidates({
      categoryId: shelf.categoryId,
      limit: 20,
      skip: 0,
    });
    assert.equal(found.length, 1, 'A/B and B/A are the same pair');
  } finally {
    await shelf.destroy();
  }
});

dbTest('a pair somebody has ruled on stops coming back', async () => {
  const shelf = await openShelf({
    first: 'فستان سهرة أحمر طويل',
    second: 'فستان سهرة احمر طويل',
  });
  try {
    const before = await shelf.service.candidates({
      categoryId: shelf.categoryId,
      limit: 20,
      skip: 0,
    });
    assert.equal(before.length, 1);

    // DISTINCT, deliberately: the verdict that matters most is the one that
    // says "these only read alike". Without it the queue re-serves the same
    // two dresses forever and stops being read.
    await shelf.service.record({
      productIdA: shelf.ids.second,
      productIdB: shelf.ids.first,
      verdict: DuplicateVerdict.DISTINCT,
      decidedById: shelf.sellerIds[0],
    });

    const after = await shelf.service.candidates({
      categoryId: shelf.categoryId,
      limit: 20,
      skip: 0,
    });
    assert.equal(after.length, 0, 'a decided pair is out of the queue');
  } finally {
    await shelf.destroy();
  }
});

dbTest('a verdict is one row however the pair was submitted', async () => {
  const shelf = await openShelf({
    first: 'فستان سهرة أحمر طويل',
    second: 'فستان سهرة احمر طويل',
  });
  try {
    await shelf.service.record({
      productIdA: shelf.ids.first,
      productIdB: shelf.ids.second,
      verdict: DuplicateVerdict.DUPLICATE,
      decidedById: shelf.sellerIds[0],
    });
    // The same pair, the other way round, and with the opposite ruling.
    await shelf.service.record({
      productIdA: shelf.ids.second,
      productIdB: shelf.ids.first,
      verdict: DuplicateVerdict.DISTINCT,
      note: 'مقاسان مختلفان',
      decidedById: shelf.sellerIds[0],
    });

    const rows = await prisma.productDuplicateVerdict.findMany({
      where: {
        leftProductId: { in: Object.values(shelf.ids) },
      },
    });
    assert.equal(rows.length, 1, 'the ids are sorted before they are stored');
    assert.equal(rows[0].verdict, DuplicateVerdict.DISTINCT, 'and re-ruling updates it');
    assert.equal(rows[0].note, 'مقاسان مختلفان');
  } finally {
    await shelf.destroy();
  }
});

dbTest('clearing a verdict returns the pair to the queue', async () => {
  const shelf = await openShelf({
    first: 'فستان سهرة أحمر طويل',
    second: 'فستان سهرة احمر طويل',
  });
  try {
    await shelf.service.record({
      productIdA: shelf.ids.first,
      productIdB: shelf.ids.second,
      verdict: DuplicateVerdict.DISTINCT,
      decidedById: shelf.sellerIds[0],
    });
    await shelf.service.clear(shelf.ids.second, shelf.ids.first);

    const found = await shelf.service.candidates({
      categoryId: shelf.categoryId,
      limit: 20,
      skip: 0,
    });
    assert.equal(found.length, 1, 'a title may have changed since the ruling');
  } finally {
    await shelf.destroy();
  }
});

dbTest('the queue says whether one boutique listed it twice', async () => {
  const shelf = await openShelf(
    {
      first: 'فستان سهرة أحمر طويل',
      second: 'فستان سهرة احمر طويل',
    },
    { first: 0, second: 0 },
  );
  try {
    const [candidate] = await shelf.service.candidates({
      categoryId: shelf.categoryId,
      limit: 20,
      skip: 0,
    });
    // Two boutiques listing one garment is a catalogue split. One boutique
    // listing it twice is her own duplicate, and a different conversation.
    assert.equal(candidate.sharesSeller, true);
  } finally {
    await shelf.destroy();
  }
});

dbTest('a delisted product is not offered for merging', async () => {
  const shelf = await openShelf({
    first: 'فستان سهرة أحمر طويل',
    second: 'فستان سهرة احمر طويل',
  });
  try {
    await prisma.product.update({
      where: { id: shelf.ids.second },
      data: { status: ProductStatus.ARCHIVED },
    });

    const found = await shelf.service.candidates({
      categoryId: shelf.categoryId,
      limit: 20,
      skip: 0,
    });
    assert.equal(found.length, 0, 'nothing to merge into a listing nobody can buy');
  } finally {
    await shelf.destroy();
  }
});
