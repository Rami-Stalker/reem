import assert from 'node:assert/strict';
import test from 'node:test';
import { ConfigService } from '@nestjs/config';
import { MediaType, PrismaClient, VisualRegionDetector } from '@prisma/client';
import sharp from 'sharp';

import { CacheService } from '../../common/cache/cache.service';
import { PrismaService } from '../../prisma/prisma.service';
import { EmbeddingService } from './embedding/embedding.service';
import { PerceptualVisualEmbedder } from './embedding/perceptual-embedder';
import { ImageProcessingService } from './processing/image-processing.service';
import { VECTOR_INDEX, VectorRecord } from './vector/vector-index';
import { PostgresVectorIndex } from './vector/postgres-vector-index';
import { readingsToAttributes } from './understanding/visual-attributes';
import { rankVisualMatches } from './search/visual-ranker';
import { emptyBrief } from '../ai-stylist/understanding/style-brief';
import { PURCHASABLE_PRODUCT_WHERE, PRODUCT_CARD_INCLUDE } from '../../common/catalog/product-include';

/**
 * Ohara Visual Shopping against the real database.
 *
 * The unit tests prove the arithmetic on synthetic bitmaps. This proves the
 * claim the feature is actually sold on: that a photograph handed to the
 * pipeline comes back as **live listings from this shop**, ordered by a number
 * that means something, with no model configured anywhere.
 *
 * Two properties are asserted that nothing else can check:
 *
 *  1. **Recall against real photographs.** Three of the seeded shop's own
 *     product images are indexed, and then one of them is searched *with*.
 *     The product that owns it must come back first at a very high percentage —
 *     an identical image is the one case where the answer is not a matter of
 *     taste, and a pipeline that gets it wrong is broken however good its unit
 *     tests look.
 *  2. **Nothing unbuyable is ever returned.** Every path goes through
 *     `PURCHASABLE_PRODUCT_WHERE`, and this checks the result rather than the
 *     query.
 *
 * Every case runs inside a transaction that is rolled back, so the seeded shop
 * is unchanged afterwards. No vision provider, no try-on provider, no network:
 * the deterministic path has to work on its own, and it is the one that ships
 * when nothing is configured.
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

/** Nested transactions flattened onto the one the test rolls back. */
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
  processing: ImageProcessingService;
  embeddings: EmbeddingService;
  index: PostgresVectorIndex;
}

/** The compiled defaults, which is what an unconfigured deployment runs on. */
const config = new ConfigService({});

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const processing = new ImageProcessingService(config);
  const embedder = new PerceptualVisualEmbedder();
  // A fresh cache per case: a descriptor cached across a rolled-back
  // transaction would make the second run of this file pass for the wrong
  // reason.
  const embeddings = new EmbeddingService(embedder, processing, new CacheService());
  const index = new PostgresVectorIndex(db, embedder);
  return { db, processing, embeddings, index };
}

// ── Fixtures ────────────────────────────────────────────────────────────

/**
 * Photographs, generated rather than fetched.
 *
 * The seeded catalogue's image URLs point at a third-party host, and a test
 * that needs the internet is a test that fails on a plane. These are drawn
 * here — a coloured garment shape on a pale ground, which is what a boutique
 * listing photograph is — and written onto real product rows inside the
 * rolled-back transaction.
 */
async function photograph(options: {
  r: number;
  g: number;
  b: number;
  stripes?: boolean;
  width?: number;
}): Promise<Buffer> {
  const W = 600;
  const H = 800;
  const raw = Buffer.alloc(W * H * 3, 244);

  const halfWidth = Math.round(((options.width ?? 0.44) * W) / 2);
  for (let y = Math.round(H * 0.1); y < Math.round(H * 0.92); y += 1) {
    for (let x = W / 2 - halfWidth; x < W / 2 + halfWidth; x += 1) {
      const index = (y * W + Math.round(x)) * 3;
      const dark = options.stripes && Math.floor(y / 18) % 2 === 0;
      raw[index] = dark ? Math.max(0, options.r - 80) : options.r;
      raw[index + 1] = dark ? Math.max(0, options.g - 80) : options.g;
      raw[index + 2] = dark ? Math.max(0, options.b - 80) : options.b;
    }
  }

  return sharp(raw, { raw: { width: W, height: H, channels: 3 } })
    .jpeg({ quality: 92 })
    .toBuffer();
}

/** Live, buyable products from the seeded shop. */
async function liveProducts(db: PrismaService, count: number) {
  const rows = await db.product.findMany({
    where: PURCHASABLE_PRODUCT_WHERE,
    select: { id: true, title: true, category: { select: { slug: true } } },
    take: count,
    orderBy: { createdAt: 'asc' },
  });
  assert.ok(
    rows.length >= count,
    `the seeded shop needs at least ${count} live products; found ${rows.length}`,
  );
  return rows;
}

/** Indexes one generated photograph against one real product. */
async function indexPhotograph(
  world: World,
  productId: string,
  bytes: Buffer,
): Promise<VectorRecord> {
  const mediaUrl = `https://fixture.test/${productId}.jpg`;
  await world.db.productMedia.create({
    data: { productId, url: mediaUrl, type: MediaType.image, sortOrder: 0 },
  });

  const prepared = await world.processing.prepare(bytes);
  const embedding = await world.embeddings.embed(prepared);
  const record: VectorRecord = {
    productId,
    mediaUrl,
    position: 0,
    vector: embedding.vector,
    paletteKeys: embedding.paletteKeys,
    pattern: embedding.pattern,
    sourceChecksum: prepared.checksum,
  };

  await world.index.upsert(productId, [record]);
  return record;
}

// ── The claims ──────────────────────────────────────────────────────────

dbTest('the photograph a product was indexed with finds that product first', async (world) => {
  const products = await liveProducts(world.db, 3);

  const black = await photograph({ r: 24, g: 24, b: 28 });
  const cream = await photograph({ r: 238, g: 228, b: 208 });
  const red = await photograph({ r: 198, g: 40, b: 48 });

  await indexPhotograph(world, products[0].id, black);
  await indexPhotograph(world, products[1].id, cream);
  await indexPhotograph(world, products[2].id, red);

  // Re-encoded on the way in, so this is not a byte-identical comparison —
  // it goes through JPEG, the salience crop and the descriptor exactly as a
  // screenshot from her phone would.
  const query = await world.processing.prepare(black);
  const embedding = await world.embeddings.embed(query);

  const matches = await world.index.search(embedding.vector, {
    productWhere: { id: { in: products.map((product) => product.id) } },
    paletteKeys: embedding.paletteKeys,
    candidateLimit: 500,
    limit: 5,
    minSimilarity: 0,
  });

  assert.ok(matches.length >= 3, 'all three indexed photographs should be scored');
  assert.equal(matches[0].productId, products[0].id, 'the black dress should win');
  assert.ok(
    matches[0].similarity > 0.98,
    `an identical photograph should be near-perfect, got ${matches[0].similarity}`,
  );
  // And the others are genuinely behind it rather than tied.
  assert.ok(matches[1].similarity < matches[0].similarity - 0.02);
});

dbTest('the percentage on the card is the calibrated score, and it separates', async (world) => {
  const products = await liveProducts(world.db, 2);

  const black = await photograph({ r: 24, g: 24, b: 28 });
  const cream = await photograph({ r: 238, g: 228, b: 208 });
  await indexPhotograph(world, products[0].id, black);
  await indexPhotograph(world, products[1].id, cream);

  const query = await world.processing.prepare(black);
  const embedding = await world.embeddings.embed(query);
  const attributes = readingsToAttributes(embedding.readings!);

  const matches = await world.index.search(embedding.vector, {
    productWhere: { id: { in: products.map((product) => product.id) } },
    candidateLimit: 500,
    limit: 5,
    minSimilarity: 0,
  });

  const rows = await world.db.product.findMany({
    where: { id: { in: products.map((product) => product.id) } },
    include: PRODUCT_CARD_INCLUDE,
  });

  const ranked = rankVisualMatches(
    {
      matches,
      products: new Map(rows.map((row) => [row.id, row])),
      attributes,
      brief: emptyBrief(),
      anchors: world.embeddings.anchors,
      diversity: null,
    },
    5,
  );

  assert.ok(ranked.length >= 1);
  assert.equal(ranked[0].product.id, products[0].id);
  assert.ok(
    ranked[0].similarity >= 0.95,
    `its own photograph should read as near-identical, got ${ranked[0].similarity}`,
  );
  // The reason is rendered from codes that actually fired.
  assert.ok(ranked[0].reasons.includes('NEAR_IDENTICAL'));
  assert.ok(ranked[0].reason.length > 0);

  // The cream dress is either well behind or dropped for being under the
  // display floor. Both are correct; what must not happen is a near-tie.
  const cream_ = ranked.find((entry) => entry.product.id === products[1].id);
  if (cream_) {
    assert.ok(
      cream_.similarity < ranked[0].similarity - 0.15,
      `a different colour should not be a near-tie: ${cream_.similarity}`,
    );
  }
});

dbTest('a colour named in words re-weights the comparison rather than filtering', async (world) => {
  const products = await liveProducts(world.db, 2);

  // Two garments of the same cut, different colours. Searching with the black
  // one while asking for cream must promote the cream one — which is exactly
  // what `weightsForQuery` exists to do.
  const black = await photograph({ r: 24, g: 24, b: 28 });
  const cream = await photograph({ r: 238, g: 228, b: 208 });
  await indexPhotograph(world, products[0].id, black);
  await indexPhotograph(world, products[1].id, cream);

  const query = await world.processing.prepare(black);
  const embedding = await world.embeddings.embed(query);
  const where = { id: { in: products.map((product) => product.id) } };

  const plain = await world.index.search(embedding.vector, {
    productWhere: where,
    candidateLimit: 500,
    limit: 5,
    minSimilarity: 0,
  });
  const creamFirst = await world.index.search(embedding.vector, {
    productWhere: where,
    // What `weightsForQuery` produces when she asks for a colour the
    // photograph does not contain.
    weights: { colour: 0.08, shape: 0.432, texture: 0.268 },
    candidateLimit: 500,
    limit: 5,
    minSimilarity: 0,
  });

  const gapBefore =
    score(plain, products[0].id) - score(plain, products[1].id);
  const gapAfter =
    score(creamFirst, products[0].id) - score(creamFirst, products[1].id);

  assert.ok(gapBefore > 0, 'the black dress leads on the unweighted search');
  assert.ok(
    gapAfter < gapBefore,
    `dropping colour should close the gap: ${gapAfter} vs ${gapBefore}`,
  );
});

dbTest('a delisted product loses its vectors and stops being findable', async (world) => {
  const [product] = await liveProducts(world.db, 1);
  const black = await photograph({ r: 24, g: 24, b: 28 });
  await indexPhotograph(world, product.id, black);

  const query = await world.processing.prepare(black);
  const embedding = await world.embeddings.embed(query);

  const before = await world.index.search(embedding.vector, {
    productWhere: { id: product.id },
    candidateLimit: 100,
    limit: 5,
    minSimilarity: 0,
  });
  assert.equal(before.length, 1);

  const removed = await world.index.remove(product.id);
  assert.equal(removed, 1);

  const after = await world.index.search(embedding.vector, {
    productWhere: { id: product.id },
    candidateLimit: 100,
    limit: 5,
    minSimilarity: 0,
  });
  assert.deepEqual(after, []);
});

dbTest('re-indexing an unchanged photograph replaces rather than duplicates', async (world) => {
  const [product] = await liveProducts(world.db, 1);
  const black = await photograph({ r: 24, g: 24, b: 28 });

  const record = await indexPhotograph(world, product.id, black);
  await world.index.upsert(product.id, [record]);
  await world.index.upsert(product.id, [record]);

  const count = await world.db.productImageEmbedding.count({
    where: { productId: product.id, embedder: world.embeddings.name },
  });
  assert.equal(count, 1);
});

dbTest('a search never returns something nobody can buy', async (world) => {
  const products = await liveProducts(world.db, 2);
  const black = await photograph({ r: 24, g: 24, b: 28 });

  await indexPhotograph(world, products[0].id, black);
  await indexPhotograph(world, products[1].id, black);

  // Pull the second product out of the catalogue entirely.
  await world.db.product.update({
    where: { id: products[1].id },
    data: { status: 'ARCHIVED' },
  });

  const query = await world.processing.prepare(black);
  const embedding = await world.embeddings.embed(query);

  const matches = await world.index.search(embedding.vector, {
    // The predicate every caller in the module uses.
    productWhere: {
      AND: [PURCHASABLE_PRODUCT_WHERE, { id: { in: products.map((p) => p.id) } }],
    },
    candidateLimit: 500,
    limit: 10,
    minSimilarity: 0,
  });

  assert.ok(matches.some((match) => match.productId === products[0].id));
  assert.ok(
    !matches.some((match) => match.productId === products[1].id),
    'an archived product must not appear in a visual search',
  );
});

dbTest('the descriptor stored is the one the current embedder reads', async (world) => {
  const [product] = await liveProducts(world.db, 1);
  await indexPhotograph(world, product.id, await photograph({ r: 24, g: 24, b: 28 }));

  const row = await world.db.productImageEmbedding.findFirstOrThrow({
    where: { productId: product.id },
  });

  assert.equal(row.embedder, world.embeddings.name);
  assert.equal(row.dimensions, world.embeddings.dimensions);
  assert.equal(row.vector.length, world.embeddings.dimensions);
  // The palette is denormalised beside the vector so the candidate pull can
  // pre-filter on colour without decoding 184 floats per row.
  assert.ok(row.paletteKeys.includes('black'), row.paletteKeys.join(','));
  assert.equal(row.pattern, 'plain');
  assert.ok(row.sourceChecksum && row.sourceChecksum.length === 64);
});

dbTest('a region of a photograph is described on its own, not as the frame', async (world) => {
  const image = await photograph({ r: 24, g: 24, b: 28 });

  const whole = await world.processing.prepare(image, { withFrame: true });
  const corner = await world.processing.prepareRegion(image, {
    x: 0.0,
    y: 0.0,
    w: 0.3,
    h: 0.25,
  });

  const wholeVector = (await world.embeddings.embed(whole)).vector;
  const cornerVector = (await world.embeddings.embed(corner)).vector;

  const { total } = new PerceptualVisualEmbedder().similarity(
    wholeVector,
    cornerVector,
  );
  // The top-left corner of this fixture is background. Cropping to it must
  // produce a genuinely different descriptor, or region search is searching
  // the same picture four times.
  assert.ok(total < 0.95, `a crop should differ from the frame: ${total}`);

  // And the full-frame canvas is present only when asked for — it costs an
  // extra resample and only the segmenter needs it.
  assert.ok(whole.frame !== null);
  assert.equal(corner.frame, null);
});

dbTest('an undecodable upload is refused rather than searched around', async (world) => {
  await assert.rejects(
    () => world.processing.prepare(Buffer.from('this is not an image')),
    /UNSUPPORTED_MEDIA_TYPE/,
  );
  await assert.rejects(
    () => world.processing.prepare(Buffer.alloc(0)),
    /EMPTY_IMAGE/,
  );

  // A one-pixel PNG: decodable, and not a photograph of anything.
  const tiny = await sharp({
    create: { width: 8, height: 8, channels: 3, background: '#000' },
  })
    .png()
    .toBuffer();
  await assert.rejects(() => world.processing.prepare(tiny), /IMAGE_TOO_SMALL/);
});

dbTest('the stored copy is re-encoded, bounded and stripped of metadata', async (world) => {
  // A photograph with EXIF, of the size a phone actually produces.
  const withExif = await sharp({
    create: { width: 3000, height: 4000, channels: 3, background: '#402030' },
  })
    .withMetadata({ exif: { IFD0: { Copyright: 'her camera', Artist: 'her' } } })
    .jpeg()
    .toBuffer();

  const prepared = await world.processing.prepare(withExif);
  const meta = await sharp(prepared.buffer).metadata();

  assert.equal(meta.format, 'webp', 'the platform stores bytes it produced');
  assert.ok((meta.width ?? 0) <= 1024 && (meta.height ?? 0) <= 1024);
  assert.equal(meta.exif, undefined, 'EXIF must not survive the re-encode');
  assert.ok(
    prepared.byteSize < withExif.length,
    'the stored copy must be smaller than what she sent',
  );
});

dbTest('every region detector value round-trips through the database', async (world) => {
  // A cheap but real guard: the enum in the schema and the one the segmenter
  // produces are separate declarations, and a value that exists in TypeScript
  // and not in Postgres fails only at write time, on a customer.
  const [product] = await liveProducts(world.db, 1);
  const session = await world.db.visualSearchSession.create({
    data: {
      userId: (await world.db.user.findFirstOrThrow({ select: { id: true } })).id,
      checksum: 'x'.repeat(64),
      embedder: world.embeddings.name,
      dimensions: world.embeddings.dimensions,
      vector: new Array(world.embeddings.dimensions).fill(0),
    },
  });

  for (const [position, detector] of Object.values(VisualRegionDetector).entries()) {
    await world.db.visualSearchRegion.create({
      data: {
        sessionId: session.id,
        detector,
        label: 'قطعة',
        boundingBox: { x: 0, y: 0, w: 1, h: 1 },
        confidence: 0.5,
        vector: [],
        paletteKeys: [],
        position,
      },
    });
  }

  const stored = await world.db.visualSearchRegion.count({
    where: { sessionId: session.id },
  });
  assert.equal(stored, Object.values(VisualRegionDetector).length);
  assert.ok(product.id);
});

function score(
  matches: Array<{ productId: string; similarity: number }>,
  productId: string,
): number {
  return matches.find((match) => match.productId === productId)?.similarity ?? 0;
}
