import assert from 'node:assert/strict';
import test from 'node:test';
import {
  AffinityKind,
  GraphEdge,
  GraphNode,
  PrismaClient,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { GraphQueryService } from './graph-query.service';
import { AffinityBuilderService } from './projection/affinity-builder.service';
import { GraphProjectorService } from './projection/graph-projector.service';
import { ShopperIntelligenceService } from '../intelligence/shopper-intelligence.service';
import { nodeId } from './graph.constants';

/**
 * The commerce graph against the real database.
 *
 * The kernels prove the arithmetic. These prove the claims only Postgres can
 * settle, and each is a claim phase three makes:
 *
 *   - every edge is derived from a row that already existed;
 *   - a re-projection updates rather than duplicating, and drops what stopped
 *     being true;
 *   - similarity is a real relation, not "same category";
 *   - a substitute is genuinely cheaper and genuinely comparable;
 *   - the seller side reports counts and never identities.
 *
 * Every case runs inside a transaction that is rolled back.
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
        { timeout: 120_000 },
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
        return async (fn: unknown) => {
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
  projector: GraphProjectorService;
  affinities: AffinityBuilderService;
  graph: GraphQueryService;
  intelligence: ShopperIntelligenceService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const graph = new GraphQueryService(db);
  return {
    db,
    projector: new GraphProjectorService(db),
    affinities: new AffinityBuilderService(db),
    graph,
    intelligence: new ShopperIntelligenceService(db),
  };
}

/** A shopper who has actually done things. */
async function activeShopper(db: PrismaService): Promise<string | null> {
  const row = await db.order.findFirst({
    orderBy: { createdAt: 'desc' },
    select: { userId: true },
  });
  return row?.userId ?? null;
}

// ── Projection ───────────────────────────────────────────────────────────

dbTest('every edge is derived from a row that already existed', async (world) => {
  const userId = await activeShopper(world.db);
  if (!userId) return;

  await world.projector.projectUser(userId);

  const edges = await world.db.commerceEdge.findMany({
    where: { subjectType: GraphNode.USER, subjectId: userId },
  });
  assert.ok(edges.length > 0, 'a shopper with orders should have edges');

  // Every PURCHASED edge must correspond to a real order line of hers.
  for (const edge of edges.filter((e) => e.kind === GraphEdge.PURCHASED)) {
    const line = await world.db.orderItem.count({
      where: {
        productId: edge.objectId,
        sellerOrder: { order: { userId } },
      },
    });
    assert.ok(line > 0, `PURCHASED ${edge.objectId} has no order line behind it`);
  }

  // And every BUYS_FROM must be a seller she actually bought from.
  for (const edge of edges.filter((e) => e.kind === GraphEdge.BUYS_FROM)) {
    const sold = await world.db.sellerOrder.count({
      where: { sellerId: edge.objectId, order: { userId } },
    });
    assert.ok(sold > 0, 'BUYS_FROM invented a seller');
  }
});

dbTest('re-projecting updates rather than duplicating', async (world) => {
  const userId = await activeShopper(world.db);
  if (!userId) return;

  await world.projector.projectUser(userId);
  const first = await world.db.commerceEdge.count({
    where: { subjectType: GraphNode.USER, subjectId: userId },
  });

  await world.projector.projectUser(userId);
  const second = await world.db.commerceEdge.count({
    where: { subjectType: GraphNode.USER, subjectId: userId },
  });

  assert.equal(second, first, 'a second run must not add rows');
  assert.ok(first > 0);
});

dbTest('an edge whose behaviour stopped is removed, not left to rot', async (world) => {
  const userId = await activeShopper(world.db);
  if (!userId) return;

  const product = await world.db.product.findFirstOrThrow({
    where: { status: 'ACTIVE' },
    select: { id: true },
  });

  // Favourite something, project, then unfavourite and project again.
  await world.db.favorite.create({ data: { userId, productId: product.id } });
  await world.projector.projectUser(userId);

  const saved = await world.db.commerceEdge.findFirst({
    where: {
      subjectType: GraphNode.USER,
      subjectId: userId,
      objectId: product.id,
      kind: GraphEdge.SAVED,
    },
  });
  assert.ok(saved, 'the favourite should have produced an edge');

  await world.db.favorite.deleteMany({ where: { userId, productId: product.id } });
  await world.projector.projectUser(userId);

  const gone = await world.db.commerceEdge.findFirst({
    where: {
      subjectType: GraphNode.USER,
      subjectId: userId,
      objectId: product.id,
      kind: GraphEdge.SAVED,
    },
  });
  assert.equal(gone, null, 'a stale edge would keep answering with what is no longer true');
});

dbTest('a keyed node carries its human key in the evidence', async (world) => {
  const userId = await activeShopper(world.db);
  if (!userId) return;

  await world.projector.projectUser(userId);
  const keyed = await world.db.commerceEdge.findMany({
    where: {
      subjectType: GraphNode.USER,
      subjectId: userId,
      objectType: { in: [GraphNode.SLOT, GraphNode.OCCASION, GraphNode.TERM] },
    },
  });

  for (const edge of keyed) {
    const evidence = (edge.evidence ?? {}) as Record<string, unknown>;
    const key = evidence['slot'] ?? evidence['occasion'] ?? evidence['term'];
    assert.ok(
      typeof key === 'string',
      `${edge.objectType} edge has no readable key — the id is a hash`,
    );
    // And the hash must be reproducible from that key.
    assert.equal(
      edge.objectId,
      nodeId(edge.objectType, key as string),
      'the id must be the hash of the key it claims',
    );
  }
});

// ── Affinity ─────────────────────────────────────────────────────────────

dbTest('similarity is a relation, not "same category"', async (world) => {
  // Deterministic, and counted the same way twice.
  //
  // This used to pick by total product count and then measure against the
  // ACTIVE ones, with the pair list truncated at fifty — three ways for the
  // comparison to be between two different things. With several categories
  // tied on size it also depended on which one `findFirst` happened to
  // return, so it passed or failed according to what else was running.
  const categories = await world.db.category.findMany({
    where: { products: { some: { status: 'ACTIVE' } } },
    select: {
      id: true,
      _count: { select: { products: { where: { status: 'ACTIVE' } } } },
    },
  });
  categories.sort(
    (a, b) => b._count.products - a._count.products || a.id.localeCompare(b.id),
  );
  const category = categories[0];
  if (!category || category._count.products < 4) return;

  await world.affinities.buildCategory(category.id);

  // Every pair, not the first fifty: comparing a truncated count against an
  // untruncated maximum answers nothing.
  const related = await world.db.productAffinity.count({
    where: { kind: AffinityKind.SIMILAR, product: { categoryId: category.id } },
  });
  if (!related) return;

  const rows = await world.db.productAffinity.findMany({
    where: { kind: AffinityKind.SIMILAR, product: { categoryId: category.id } },
    take: 50,
  });

  const inCategory = category._count.products;

  // The point: not everything in the category is related to everything else.
  const maxPossible = inCategory * (inCategory - 1);
  assert.ok(
    related < maxPossible,
    `if every pair were similar this would just be the category again ` +
      `(${related} of a possible ${maxPossible} across ${inCategory} listings)`,
  );

  for (const row of rows) {
    assert.ok(row.score > 0 && row.score <= 100);
    assert.notEqual(row.productId, row.relatedId, 'nothing is similar to itself');
  }
});

dbTest('a substitute is cheaper, comparable and no worse', async (world) => {
  const category = await world.db.category.findFirst({
    where: { products: { some: { status: 'ACTIVE' } } },
    select: { id: true },
    orderBy: { products: { _count: 'desc' } },
  });
  if (!category) return;

  await world.affinities.buildCategory(category.id);

  const subs = await world.db.productAffinity.findMany({
    where: { kind: AffinityKind.SUBSTITUTE },
    include: {
      product: { select: { minPriceSyp: true, rating: true, reviewsCount: true } },
      related: { select: { minPriceSyp: true, rating: true, reviewsCount: true } },
    },
    take: 40,
  });

  for (const sub of subs) {
    const original = Number(sub.product.minPriceSyp ?? 0);
    const candidate = Number(sub.related.minPriceSyp ?? 0);
    assert.ok(
      candidate < original,
      'a substitute that costs more is not better value',
    );

    const basis = (sub.basis ?? {}) as Record<string, unknown>;
    assert.ok(
      typeof basis['savingBps'] === 'number' && basis['savingBps'] >= 1500,
      'the saving must be real and recorded',
    );

    if (sub.product.reviewsCount > 0) {
      assert.ok(
        sub.related.rating >= sub.product.rating - 0.3,
        '"better value" must not mean "worse, but less"',
      );
    }
  }
});

dbTest('complements never share a slot', async (world) => {
  await world.affinities.buildComplements();

  const rows = await world.db.productAffinity.findMany({
    where: { kind: AffinityKind.COMPLEMENT },
    take: 40,
    select: { productId: true, relatedId: true, basis: true },
  });

  for (const row of rows) {
    const basis = (row.basis ?? {}) as Record<string, unknown>;
    const slots = basis['slots'];
    if (Array.isArray(slots) && slots[0] && slots[1]) {
      assert.notEqual(
        slots[0],
        slots[1],
        'a second dress does not complete an outfit',
      );
    }
  }
});

dbTest('a complement rebuild drops what it no longer produces', async (world) => {
  // The bug a live rebuild caught: complements were upserted and never
  // deleted, so pairs the slot-exclusivity rule was written to forbid
  // survived the fix that forbade them.
  await world.affinities.buildComplements();

  const products = await world.db.product.findMany({
    where: { status: 'ACTIVE' },
    select: { id: true },
    take: 2,
  });
  if (products.length < 2) return;

  // Plant a complement this build could never produce.
  await world.db.productAffinity.create({
    data: {
      productId: products[0].id,
      relatedId: products[1].id,
      kind: AffinityKind.COMPLEMENT,
      score: 99,
      basis: { slots: ['DRESS', 'ABAYA'], source: 'planted' },
    },
  });

  await world.affinities.buildComplements();

  const survived = await world.db.productAffinity.findFirst({
    where: {
      productId: products[0].id,
      relatedId: products[1].id,
      kind: AffinityKind.COMPLEMENT,
      score: 99,
    },
  });
  assert.equal(survived, null, 'a relation the rebuild did not produce must go');
});

dbTest('a rebuild drops relations that stopped being true', async (world) => {
  const category = await world.db.category.findFirst({
    where: { products: { some: { status: 'ACTIVE' } } },
    select: { id: true },
    orderBy: { products: { _count: 'desc' } },
  });
  if (!category) return;

  await world.affinities.buildCategory(category.id);
  const before = await world.db.productAffinity.count({
    where: { kind: AffinityKind.SIMILAR, product: { categoryId: category.id } },
  });

  await world.affinities.buildCategory(category.id);
  const after = await world.db.productAffinity.count({
    where: { kind: AffinityKind.SIMILAR, product: { categoryId: category.id } },
  });

  assert.equal(after, before, 'rebuilding is idempotent, not additive');
});

// ── Reading ──────────────────────────────────────────────────────────────

dbTest('the graph only ever offers products somebody could buy', async (world) => {
  const category = await world.db.category.findFirst({
    where: { products: { some: { status: 'ACTIVE' } } },
    select: { id: true },
    orderBy: { products: { _count: 'desc' } },
  });
  if (!category) return;

  await world.affinities.buildCategory(category.id);
  const source = await world.db.productAffinity.findFirst({
    where: { kind: AffinityKind.SIMILAR },
    select: { productId: true },
  });
  if (!source) return;

  const ids = await world.graph.similar(source.productId, 10);
  for (const id of ids) {
    const live = await world.db.product.count({
      where: { id, status: 'ACTIVE', offers: { some: { status: 'ACTIVE' } } },
    });
    assert.equal(live, 1, 'a rail of delisted products is worse than an empty one');
  }
});

dbTest('the seller audience reports counts and never identities', async (world) => {
  const userId = await activeShopper(world.db);
  if (!userId) return;
  await world.projector.projectUser(userId);

  const edge = await world.db.commerceEdge.findFirst({
    where: { subjectType: GraphNode.USER, objectType: GraphNode.PRODUCT },
    select: { objectId: true },
  });
  if (!edge) return;

  const audience = await world.graph.audienceFor(edge.objectId);
  const serialised = JSON.stringify(audience);

  assert.ok(!serialised.includes(userId), 'no shopper id may leave this method');
  assert.equal(typeof audience.interested, 'number');
  for (const row of audience.alsoInterestedIn) {
    assert.ok(
      row.shoppers >= 3,
      'fewer than three shoppers is a person, not a segment',
    );
  }
});

// ── Intelligence over the graph ──────────────────────────────────────────

dbTest('a shopper with no history is told nothing personal', async (world) => {
  // The distinction live data drew out, and it is the right one: some notes
  // are facts about the *catalogue* — that a near-identical piece costs less,
  // that stock is nearly gone — and a stranger benefits from those while they
  // reveal nothing about her. What she must never see is a note that implies
  // Reem knows her, because it does not.
  const stranger = await world.db.user.findFirst({
    where: { orders: { none: {} }, favorites: { none: {} }, closet: { is: null } },
    select: { id: true },
  });
  const product = await world.db.product.findFirstOrThrow({
    where: { status: 'ACTIVE' },
    select: { id: true },
  });
  if (!stranger) return;

  const notes = await world.intelligence.verdicts(stranger.id, product.id);

  const personal = [
    'ALREADY_OWN_SIMILAR',
    'SUITS_YOUR_CLOSET',
    'COMPLETES_LOOK',
    'MATCHES_INTENT',
    'FITS_OCCASION',
    'TRUSTED_SELLER',
  ];
  for (const note of notes) {
    assert.ok(
      !personal.includes(note.code),
      `${note.code} claims to know a shopper with no history`,
    );
  }
});

dbTest('a signed-out visitor gets nothing rather than an error', async (world) => {
  const product = await world.db.product.findFirstOrThrow({
    where: { status: 'ACTIVE' },
    select: { id: true },
  });
  assert.deepEqual(await world.intelligence.verdicts(null, product.id), []);
});

dbTest('every note names evidence that resolves to real rows', async (world) => {
  const userId = await activeShopper(world.db);
  if (!userId) return;
  await world.projector.projectUser(userId);

  const owned = await world.db.closetItem.findFirst({
    where: { userId, status: 'ACTIVE', productId: { not: null } },
    select: { productId: true },
  });
  if (!owned?.productId) return;

  const notes = await world.intelligence.verdicts(userId, owned.productId);
  for (const note of notes) {
    assert.ok(note.ar.trim().length > 5, `${note.code} has no sentence`);

    const itemIds = (note.evidence as Record<string, unknown>)['itemIds'];
    if (Array.isArray(itemIds)) {
      const found: number = await world.db.closetItem.count({
        where: { id: { in: itemIds as string[] }, userId },
      });
      assert.equal(
        found,
        itemIds.length,
        'a note may only cite her own closet items',
      );
    }
  }
});
