import assert from 'node:assert/strict';
import test from 'node:test';
import { AiStylistRole, ModestyLevel, OutfitSlot, PrismaClient } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { defaultOffer } from '../../common/catalog/product-include';
import { DisabledStylistLlm } from './llm/stylist-llm';
import { OutfitBuilderService } from './outfit/outfit-builder.service';
import { StylePreferenceService } from './preferences/style-preference.service';
import { ProductRetrievalService } from './retrieval/product-retrieval.service';
import { rankProducts } from './retrieval/stylist-ranker';
import { StylistConversationService } from './stylist-conversation.service';
import { BriefExtractorService } from './understanding/brief-extractor.service';
import { emptyBrief } from './understanding/style-brief';

/**
 * The stylist against the real catalogue.
 *
 * The unit tests prove the reading and the scoring in isolation; this proves
 * the claim the whole feature is built on — that the three sentences in the
 * brief return **actual rows a customer could buy**, out of the seeded shop,
 * with prices and stock that came from the database rather than from a model.
 *
 * Every case runs inside a transaction that is rolled back, so the shop is
 * unchanged afterwards. The language model is the disabled provider, which is
 * the point: this is the deterministic path, and it has to work on its own.
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

test.after(() => prisma.$disconnect());

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

/** Nested transactions flattened onto the one the test rolls back. */
function asPrisma(tx: Tx): PrismaService {
  return new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (fn: unknown) => {
          // The conversation service batches its recommendation writes as an
          // array of promises; both forms have to flatten onto this tx.
          if (Array.isArray(fn)) return Promise.all(fn);
          return (fn as (inner: Tx) => unknown)(tx);
        };
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
}

interface World {
  db: PrismaService;
  extractor: BriefExtractorService;
  retrieval: ProductRetrievalService;
  outfits: OutfitBuilderService;
  preferences: StylePreferenceService;
  stylist: StylistConversationService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const llm = new DisabledStylistLlm();
  const extractor = new BriefExtractorService(db, llm);
  const retrieval = new ProductRetrievalService(db);
  const outfits = new OutfitBuilderService(retrieval);
  const preferences = new StylePreferenceService(db);
  const stylist = new StylistConversationService(
    db,
    extractor,
    retrieval,
    outfits,
    preferences,
    llm,
  );
  return { db, extractor, retrieval, outfits, preferences, stylist };
}

/** Any customer will do; the pipeline is the subject, not the person. */
async function someCustomer(db: PrismaService): Promise<string> {
  const user = await db.user.findFirst({
    where: { role: 'CUSTOMER', disabledAt: null },
    select: { id: true },
  });
  assert.ok(user, 'the seeded shop has no customer to talk to');
  return user.id;
}

// ── The three sentences ─────────────────────────────────────────────────

dbTest('«مناسبة بعد أسبوع، فستان محتشم بـ٥٠٠ ألف» returns buyable dresses', async (world) => {
  const { brief } = await world.extractor.extract({
    message: 'عندي مناسبة بعد أسبوع وأريد فستانًا أنيقًا ومحتشمًا بميزانية 500 ألف',
    currentBrief: emptyBrief(),
    history: [],
  });

  assert.equal(brief.budgetMax, 500_000);
  assert.equal(brief.modesty, ModestyLevel.MODEST);
  assert.ok(brief.slots.includes(OutfitSlot.DRESS));

  const { candidates } = await world.retrieval.retrieve(brief);
  assert.ok(candidates.length > 0, 'the seeded catalogue returned nothing');

  const profile = await world.preferences.buildProfile(null);
  const ranked = rankProducts(
    candidates,
    { brief, profile, diversity: { perCategory: 3, perSeller: 2 } },
    6,
  );

  assert.ok(ranked.length > 0);
  for (const entry of ranked) {
    const offer = defaultOffer(entry.product);
    // The whole promise of the feature, asserted row by row: a real seller,
    // real stock, and a price that came out of the database.
    assert.ok(offer, `${entry.product.title} has no live offer`);
    assert.ok(offer.stock > 0, `${entry.product.title} is out of stock`);
    assert.ok(entry.product.minPriceSyp, `${entry.product.title} has no price`);
    assert.ok(entry.reasons.length > 0, 'a card with no reason to be there');
  }
});

dbTest('a budget ceiling is honoured against the real price columns', async (world) => {
  const brief = {
    ...emptyBrief(),
    slots: [OutfitSlot.DRESS],
    categorySlugs: ['dresses'],
    budgetMax: 900_000,
  };

  const { candidates, relaxations } = await world.retrieval.retrieve(brief);

  // Either everything came back inside the band, or the ladder said out loud
  // that it had to raise it. Silently exceeding a stated budget is the one
  // outcome that is not allowed.
  const raised = relaxations.some((entry) => entry.code === 'BUDGET_RAISED');
  if (!raised) {
    for (const candidate of candidates) {
      assert.ok(
        Number(candidate.minPriceSyp) <= 900_000,
        `${candidate.title} is over budget with no relaxation reported`,
      );
    }
  }
});

dbTest('«فستان أسود مع حقيبة وحذاء» assembles a real, coherent look', async (world) => {
  const { brief } = await world.extractor.extract({
    message: 'أريد فستانًا أسود مع حقيبة وحذاء مناسبين',
    currentBrief: emptyBrief(),
    history: [],
  });

  assert.equal(brief.intent, 'BUILD_OUTFIT');

  const profile = await world.preferences.buildProfile(null);
  const outfit = await world.outfits.build(brief, profile);

  assert.ok(outfit, 'no outfit could be assembled from the seeded shop');
  assert.ok(outfit.pieces.length >= 2, 'a look needs more than one piece');

  const slots = outfit.pieces.map((piece) => piece.slot);
  assert.equal(new Set(slots).size, slots.length, 'the same slot filled twice');

  for (const piece of outfit.pieces) {
    const offer = defaultOffer(piece.product);
    assert.ok(offer, `${piece.slot} piece has no live offer`);
    assert.ok(offer.stock > 0, `${piece.slot} piece is out of stock`);
    assert.ok(piece.reason.length > 0, `${piece.slot} piece has no reason`);
  }

  // The total is the sum of what the pieces actually cost, not an estimate.
  if (outfit.totalSyp !== null) {
    const summed = outfit.pieces.reduce(
      (sum, piece) => sum + (piece.priceSyp ?? 0),
      0,
    );
    assert.equal(outfit.totalSyp, summed);
  }
});

dbTest('a gift brief reaches the gift categories, not the wardrobe', async (world) => {
  const { brief } = await world.extractor.extract({
    message: 'أريد هدية لصديقتي عمرها 25 سنة وتحب الأشياء الناعمة',
    currentBrief: emptyBrief(),
    history: [],
  });

  assert.equal(brief.intent, 'FIND_GIFT');
  assert.equal(brief.forSelf, false);
  assert.equal(brief.recipientAge, 25);

  const { candidates } = await world.retrieval.retrieve(brief);
  assert.ok(candidates.length > 0, 'no gift is purchasable in the seeded shop');
});

// ── A whole turn ────────────────────────────────────────────────────────

dbTest('one turn writes a transcript, real cards, and a reason for each', async (world) => {
  const userId = await someCustomer(world.db);

  const turn = await world.stylist.sendMessage({
    userId,
    content: 'بدي فستان سهرة أسود بميزانية 900 ألف',
  });

  assert.equal(turn.userMessage.role, AiStylistRole.USER);
  assert.equal(turn.assistantMessage.role, AiStylistRole.ASSISTANT);
  assert.ok(turn.assistantMessage.content.length > 0, 'the assistant said nothing');
  // The deterministic path answered, and the row says so rather than claiming
  // a model was involved.
  assert.equal(turn.assistantMessage.engine, 'reem-stylist-rules-v1');

  assert.ok(turn.recommendations.length > 0, 'a turn with no products');

  for (const { row, product } of turn.recommendations) {
    assert.equal(row.productId, product.id);
    assert.ok(row.reason.length > 0);
    assert.ok(row.reasonCodes.length > 0, 'prose with no scoring behind it');
    // Frozen at recommendation time, so a later price change cannot rewrite
    // what she was shown.
    assert.ok(row.quotedPriceSyp !== null);
  }

  // The thread remembers the brief, so a follow-up does not restate it.
  const stored = await world.db.aiStylistConversation.findUnique({
    where: { id: turn.conversation.id },
  });
  assert.ok(stored?.brief, 'the conversation kept no brief');
  assert.equal((stored.brief as { budget_max?: number }).budget_max, 900_000);
});

dbTest('a follow-up inherits the budget established a turn earlier', async (world) => {
  const userId = await someCustomer(world.db);

  const first = await world.stylist.sendMessage({
    userId,
    content: 'بدي فستان سهرة بميزانية 800 ألف',
  });

  // "والحقيبة؟" — no budget, no occasion, no colour restated. The merged
  // brief has to carry all three forward or the answer is a different shop.
  const second = await world.stylist.sendMessage({
    userId,
    conversationId: first.conversation.id,
    content: 'وحقيبة كمان',
  });

  assert.equal(second.brief.budgetMax, 800_000);
  assert.ok(second.brief.slots.includes(OutfitSlot.BAG));
});

dbTest('a dismissal removes a product from her later answers', async (world) => {
  const userId = await someCustomer(world.db);

  const turn = await world.stylist.sendMessage({
    userId,
    content: 'بدي فستان سهرة',
  });
  assert.ok(turn.recommendations.length > 0);

  const rejected = turn.recommendations[0];
  await world.stylist.recordFeedback({
    userId,
    recommendationId: rejected.row.id,
    feedback: 'DISMISSED',
  });

  const profile = await world.preferences.buildProfile(userId);
  assert.ok(
    profile.dismissedProductIds.has(rejected.product.id),
    'the dismissal did not reach her profile',
  );

  const { candidates } = await world.retrieval.retrieve(turn.brief);
  const ranked = rankProducts(
    candidates,
    { brief: turn.brief, profile, diversity: null },
    20,
  );

  assert.equal(
    ranked.some((entry) => entry.product.id === rejected.product.id),
    false,
    'a product she pushed away came back',
  );
});

dbTest('an over-constrained brief relaxes rather than returning nothing', async (world) => {
  // Deliberately impossible: a colour, a size, a tiny budget and a deadline.
  const brief = {
    ...emptyBrief(),
    slots: [OutfitSlot.DRESS],
    categorySlugs: ['dresses'],
    colours: ['purple'],
    sizes: { clothing: 'XL' },
    budgetMax: 120_000,
    keywords: ['مطرز', 'دانتيل'],
  };

  const { candidates, relaxations } = await world.retrieval.retrieve(brief);

  assert.ok(candidates.length > 0, 'the ladder bottomed out with nothing');
  assert.ok(relaxations.length > 0, 'it relaxed constraints without saying so');
  for (const relaxation of relaxations) {
    assert.ok(relaxation.message.length > 0, 'a silent relaxation');
  }
});
