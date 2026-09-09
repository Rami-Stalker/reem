import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  OfferStatus,
  PrismaClient,
  ProductStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { ProductMatcher } from './product-matcher.service';
import { SynonymsService } from './synonyms.service';

/**
 * What a woman typing Arabic into the search box actually gets back.
 *
 * The unit tests beside this one prove the key folds correctly. This one
 * proves the folding reaches the catalogue: real rows, the real matcher, the
 * real indexes. Every query below is a spelling that returned nothing at all
 * before — the shop had the garment, and said it did not.
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

let seq = 0;
const uniq = () => `${Date.now()}${(seq += 1)}`;

interface Shop {
  matcher: ProductMatcher;
  ids: Record<string, string>;
  destroy: () => Promise<void>;
}

/** A small catalogue, committed, with one listing per title. */
async function openShop(titles: Record<string, string>): Promise<Shop> {
  const u = uniq();
  const seller = await prisma.user.create({
    data: {
      name: 'بوتيك الاختبار',
      username: `search_${u}`,
      phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role: UserRole.SELLER,
    },
  });
  const category = await prisma.category.create({
    data: { slug: `search-cat-${u}`, nameAr: 'فساتين', nameEn: 'Dresses' },
  });

  const ids: Record<string, string> = {};
  let n = 0;
  for (const [key, title] of Object.entries(titles)) {
    n += 1;
    const product = await prisma.product.create({
      data: {
        slug: `search-prod-${u}-${n}`,
        title,
        description: 'قطعة أنيقة من مجموعة الاختبار.',
        categoryId: category.id,
        status: ProductStatus.ACTIVE,
        offers: {
          create: {
            sellerId: seller.id,
            currency: Currency.SYP,
            price: '100000',
            stock: 5,
            status: OfferStatus.ACTIVE,
            isActive: true,
          },
        },
      },
    });
    ids[key] = product.id;
  }

  return {
    matcher: new ProductMatcher(
      prisma as unknown as PrismaService,
      new SynonymsService(prisma as unknown as PrismaService),
    ),
    ids,
    destroy: async () => {
      await prisma.product.deleteMany({
        where: { id: { in: Object.values(ids) } },
      });
      await prisma.category.delete({ where: { id: category.id } });
      await prisma.user.delete({ where: { id: seller.id } });
    },
  };
}

function dbTest(name: string, body: () => Promise<void>): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    await body();
  });
}

dbTest('an abaya is found however the customer spells it', async () => {
  const shop = await openShop({ abaya: 'عباية سوداء مطرزة' });
  try {
    for (const spelling of ['عباية', 'عبايه', 'عَبَايَة', 'عــبــايــة']) {
      const hits = await shop.matcher.match(spelling);
      assert.ok(hits, `${spelling} is a phrase, not a blank search`);
      assert.ok(
        hits.some((hit) => hit.id === shop.ids.abaya),
        `«${spelling}» did not reach the abaya`,
      );
    }
  } finally {
    await shop.destroy();
  }
});

dbTest('a missing hamza does not hide the product', async () => {
  const shop = await openShop({ red: 'فستان أحمر طويل' });
  try {
    for (const spelling of ['أحمر', 'احمر', 'فستان احمر']) {
      const hits = await shop.matcher.match(spelling);
      assert.ok(
        hits?.some((hit) => hit.id === shop.ids.red),
        `«${spelling}» did not reach the red dress`,
      );
    }
  } finally {
    await shop.destroy();
  }
});

dbTest('a typo still finds the garment', async () => {
  const shop = await openShop({ dress: 'فستان سهرة' });
  try {
    const hits = await shop.matcher.match('فستاان');
    assert.ok(
      hits?.some((hit) => hit.id === shop.ids.dress),
      'a doubled letter is a typo, not a different word',
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('the closest answer is ranked first', async () => {
  const shop = await openShop({
    exact: 'حقيبة',
    prefix: 'حقيبة يد جلدية',
    buried: 'طقم سفر يشمل حقيبة صغيرة',
  });
  try {
    const hits = (await shop.matcher.match('حقيبة')) ?? [];
    const order = hits
      .map((hit) => hit.id)
      .filter((id) => Object.values(shop.ids).includes(id));

    assert.equal(order[0], shop.ids.exact, 'the exact title wins');
    assert.equal(order[1], shop.ids.prefix, 'then the one that opens with it');
    assert.ok(
      order.indexOf(shop.ids.buried) > order.indexOf(shop.ids.prefix),
      'and the one that merely mentions it comes last',
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('a phrase that matches nothing returns nothing, not everything', async () => {
  const shop = await openShop({ dress: 'فستان سهرة' });
  try {
    const hits = await shop.matcher.match('دراجة نارية');
    assert.ok(hits, 'it is still a phrase');
    assert.ok(
      !hits.some((hit) => hit.id === shop.ids.dress),
      'a motorcycle is not an evening dress',
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('an empty box means browse, not a search for nothing', async () => {
  const shop = await openShop({ dress: 'فستان سهرة' });
  try {
    // null, never []: the caller reads the difference as "no filter" versus
    // "filter that excludes everything", and the shop empties if they are
    // confused for each other.
    assert.equal(await shop.matcher.match(''), null);
    assert.equal(await shop.matcher.match('   '), null);
    assert.equal(await shop.matcher.match(undefined), null);
  } finally {
    await shop.destroy();
  }
});

dbTest('suggestions offer the canonical spelling of what was typed', async () => {
  const shop = await openShop({ abaya: 'عباية سوداء مطرزة' });
  try {
    const suggestions = await shop.matcher.suggest('عبايه');
    assert.ok(
      suggestions.includes('عباية سوداء مطرزة'),
      `typing عبايه should offer the listing: got ${JSON.stringify(suggestions)}`,
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('the trigram index can answer the query the matcher asks', async () => {
  const shop = await openShop({ abaya: 'عباية سوداء مطرزة' });
  try {
    // A wiring assertion, not a performance one, and deliberately not a claim
    // about what the planner *will* do: on a catalogue this size a sequential
    // scan is the cheaper plan and choosing it is correct. What matters is
    // that the index is *available* — an expression index only serves a query
    // whose expression matches it character for character, so the moment the
    // SQL in `ProductMatcher` and the SQL in the migration drift apart, the
    // index silently stops being an option and every search goes back to
    // reading the whole catalogue. Forcing the planner's hand is how that
    // drift gets caught while the table is still small enough to hide it.
    const plan = await prisma.$transaction(async (tx) => {
      await tx.$executeRawUnsafe('SET LOCAL enable_seqscan = off');
      return tx.$queryRawUnsafe<{ 'QUERY PLAN': string }[]>(`
        EXPLAIN SELECT p.id FROM products p
        WHERE reem_search_key(p.title) LIKE '%' || reem_search_key('عبايه') || '%'
      `);
    });
    const text = plan.map((row) => row['QUERY PLAN']).join('\n');
    assert.ok(
      /products_title_search_key_idx/.test(text),
      `the folded-title index should be reachable, plan was:\n${text}`,
    );
  } finally {
    await shop.destroy();
  }
});

// ── Synonyms ─────────────────────────────────────────────────────────────────

dbTest('a shopper who says شنطة finds the حقيبة', async () => {
  const shop = await openShop({ bag: 'حقيبة يد جلدية' });
  try {
    const hits = await shop.matcher.match('شنطة');
    assert.ok(
      hits?.some((hit) => hit.id === shop.ids.bag),
      'folding can never connect these two — they share no letters — so this ' +
        'is the synonym table or nothing',
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('a synonym is worth less than the customer’s own word', async () => {
  const shop = await openShop({
    literal: 'شنطة سهرة صغيرة',
    synonym: 'حقيبة سهرة صغيرة',
  });
  try {
    const hits = (await shop.matcher.match('شنطة')) ?? [];
    const mine = hits.find((hit) => hit.id === shop.ids.literal);
    const other = hits.find((hit) => hit.id === shop.ids.synonym);

    assert.ok(mine && other, 'both listings answer the query');
    assert.ok(
      mine.score > other.score,
      `the listing that says شنطة outright must rank first (${mine.score} vs ${other.score})`,
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('a synonym inside a phrase still reaches the garment', async () => {
  const shop = await openShop({ shoe: 'حذاء كعب عالي' });
  try {
    // Word-level expansion: the phrase «جزمة كعب» is in no group, but جزمة is.
    const hits = await shop.matcher.match('جزمة كعب');
    assert.ok(
      hits?.some((hit) => hit.id === shop.ids.shoe),
      'a synonym in one word of a phrase should still find it',
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('synonyms do not drag in unrelated categories', async () => {
  const shop = await openShop({ bag: 'حقيبة يد جلدية', dress: 'فستان سهرة' });
  try {
    const hits = (await shop.matcher.match('شنطة')) ?? [];
    assert.ok(
      !hits.some((hit) => hit.id === shop.ids.dress),
      'expanding شنطة must not reach a dress',
    );
  } finally {
    await shop.destroy();
  }
});
