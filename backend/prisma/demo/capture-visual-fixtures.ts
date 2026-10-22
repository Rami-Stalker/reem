/**
 * Runs Reem Visual Shopping over the seeded shop and captures what it produces.
 *
 *   npx ts-node -r tsconfig-paths/register prisma/demo/capture-visual-fixtures.ts
 *
 * Two jobs, and the second is the point:
 *
 *  1. It **indexes photographs and runs a real search**, so the numbers below
 *     are cosines this pipeline computed rather than percentages somebody
 *     picked because they looked plausible on a card.
 *  2. It **writes the search payload to `test/fixtures/`**, verbatim, through
 *     the same serializer the controller uses. That file is what the Flutter
 *     preview test parses — so a renamed field, or a `similarity_percent` that
 *     stops being an integer, fails a test rather than a phone.
 *
 * ── Why the photographs are generated ────────────────────────────────────
 *
 * The seeded catalogue's images are third-party links, and a capture script
 * that needs the internet is one that cannot be re-run. These are drawn here —
 * a coloured garment on a pale ground, which is what a boutique listing
 * photograph is — and written onto real product rows inside a transaction that
 * is **rolled back**, so the shop is exactly as it was afterwards. The
 * products, prices, sellers and categories in the fixture are the real ones.
 *
 * One caveat worth stating rather than hiding: a drawn garment carries far
 * less detail than a photograph, so the *top* of the similarity range stays
 * compressed — several near-black pieces still reach 100% because, once the
 * salience crop has done its work, they genuinely are the same picture. The
 * fixture's job is the layout and the wire contract; the ranking claim is
 * proved against the pipeline itself in `visual-search.integration.spec.ts`,
 * on images that differ the way real ones do.
 */
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { ConfigService } from '@nestjs/config';
import { MediaType, PrismaClient } from '@prisma/client';
import sharp from 'sharp';

import { CacheService } from '../../src/common/cache/cache.service';
import {
  PRODUCT_CARD_INCLUDE,
  PURCHASABLE_PRODUCT_WHERE,
} from '../../src/common/catalog/product-include';
import { PrismaService } from '../../src/prisma/prisma.service';
import { emptyBrief } from '../../src/modules/ai-stylist/understanding/style-brief';
import { EmbeddingService } from '../../src/modules/visual-search/embedding/embedding.service';
import { PerceptualVisualEmbedder } from '../../src/modules/visual-search/embedding/perceptual-embedder';
import { ImageProcessingService } from '../../src/modules/visual-search/processing/image-processing.service';
import { rankVisualMatches } from '../../src/modules/visual-search/search/visual-ranker';
import { readingsToAttributes, withNeighbourCategories } from '../../src/modules/visual-search/understanding/visual-attributes';
import { PostgresVectorIndex } from '../../src/modules/visual-search/vector/postgres-vector-index';
import {
  serializeVisualAttributes,
  serializeVisualMatch,
} from '../../src/modules/visual-search/visual-search.serializer';

class Rollback extends Error {}

/**
 * Nested transactions flattened onto the one this script rolls back.
 *
 * `PostgresVectorIndex.upsert` opens a transaction of its own, which Prisma
 * does not allow inside an interactive one. The same proxy the integration
 * spec uses: `$transaction` becomes "just run it here", so the production code
 * path is exercised unchanged and everything still lands inside the rollback.
 */
function asPrisma(tx: unknown): PrismaService {
  return new Proxy(tx as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (fn: unknown) => {
          if (Array.isArray(fn)) return Promise.all(fn);
          return (fn as (inner: unknown) => unknown)(tx);
        };
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
}

/**
 * How each kind of garment sits in the frame.
 *
 * Derived from the product's own category, so the picture and the listing
 * agree. That is not decoration — it is what makes the fixture *mean*
 * something: a full-length black dress query should score an abaya highly, a
 * skirt moderately and a sandal poorly, and it can only demonstrate that if
 * the sandal is drawn where a sandal is.
 *
 * The earlier version drew every product from one A-line template in twelve
 * shades of near-black. Four of them came back at exactly 100% — the
 * descriptor telling the truth about a fixture in which they really were the
 * same picture. Silhouette is most of what separates one garment from another,
 * so the fixture has to vary it.
 */
interface Silhouette {
  /** Vertical extent as a share of the frame. */
  top: number;
  bottom: number;
  /** Half-width at the top, and at the hem. */
  fromWidth: number;
  toWidth: number;
}

const SILHOUETTES: Record<string, Silhouette> = {
  // Shoulder to ankle, flaring to the hem.
  dresses: { top: 0.1, bottom: 0.93, fromWidth: 0.15, toWidth: 0.28 },
  // Fuller, straighter, and it reaches the floor.
  abayas: { top: 0.08, bottom: 0.96, fromWidth: 0.19, toWidth: 0.3 },
  // The lower half only.
  skirts: { top: 0.42, bottom: 0.9, fromWidth: 0.17, toWidth: 0.3 },
  // Wide and short, up near the top of the frame.
  scarves: { top: 0.14, bottom: 0.46, fromWidth: 0.3, toWidth: 0.24 },
  // Small, low, and wider than it is tall.
  shoes: { top: 0.62, bottom: 0.8, fromWidth: 0.2, toWidth: 0.16 },
};

const DEFAULT_SILHOUETTE = SILHOUETTES.dresses;

/**
 * A garment on a pale ground.
 *
 * Not a flat rectangle, and the difference matters. A solid block of one
 * colour gives the shape and texture blocks almost nothing to work with. Real
 * photographs are not flat: fabric falls in folds, a studio light falls off
 * down the frame, and a hem is a curve rather than a horizontal cut. The
 * shading and the folds are seeded from the garment's own colour, so the same
 * inputs always draw the same picture and the capture stays reproducible.
 */
async function photograph(options: {
  rgb: [number, number, number];
  silhouette: Silhouette;
  motif?: Motif;
}): Promise<Buffer> {
  const W = 600;
  const H = 800;
  const raw = Buffer.alloc(W * H * 3, 246);

  const { rgb, silhouette } = options;
  const top = Math.round(H * silhouette.top);
  const bottom = Math.round(H * silhouette.bottom);
  const seed = rgb[0] * 7 + rgb[1] * 13 + rgb[2] * 17;
  const foldPhase = (seed % 23) / 23;

  for (let y = top; y < bottom; y += 1) {
    const t = (y - top) / Math.max(1, bottom - top);

    const width =
      silhouette.fromWidth + (silhouette.toWidth - silhouette.fromWidth) * t;
    const half = Math.round((W * width) / 2);

    // Studio light falling off downward, plus soft vertical folds.
    const light = 1.14 - 0.28 * t;

    for (let x = W / 2 - half; x <= W / 2 + half; x += 1) {
      const px = Math.round(x);
      if (px < 0 || px >= W) continue;

      const across = (px - (W / 2 - half)) / (2 * half || 1);
      const fold = 1 + 0.1 * Math.sin((across * 6 + foldPhase) * Math.PI * 2);
      const shade = light * fold * motifShade(options.motif ?? 'plain', px, y, seed);

      const index = (y * W + px) * 3;
      raw[index] = clampByte(rgb[0] * shade);
      raw[index + 1] = clampByte(rgb[1] * shade);
      raw[index + 2] = clampByte(rgb[2] * shade);
    }
  }

  return sharp(raw, { raw: { width: W, height: H, channels: 3 } })
    .jpeg({ quality: 90 })
    .toBuffer();
}

/**
 * How the surface breaks up.
 *
 * Real garments are not uniformly flat, and the fixture needs them not to be:
 * a dozen plain trapezoids in twelve shades of near-black came back as seven
 * cards at exactly 100%. That was the descriptor telling the truth — after the
 * salience crop they really were the same picture — so the pictures changed.
 * Print, colour-blocking and slub texture are what separate one black dress
 * from another on a rail, and they are what the texture and layout blocks are
 * there to read.
 */
function motifShade(motif: Motif, x: number, y: number, seed: number): number {
  switch (motif) {
    case 'stripes':
      return Math.floor(y / 20) % 2 === 0 ? 0.62 : 1;
    case 'blocked':
      // A contrast panel down one side.
      return x % 600 < 300 ? 1 : 0.55;
    case 'speckled': {
      // Deterministic slub texture, not a random source.
      const noise = ((x * 73 + y * 151 + seed) % 17) / 17;
      return 0.82 + 0.28 * noise;
    }
    case 'plain':
      return 1;
  }
}

function clampByte(value: number): number {
  return Math.max(0, Math.min(255, Math.round(value)));
}

/**
 * The leaf categories a photograph of a garment can honestly land in.
 *
 * Scoping the capture to these is not cosmetic. Paired with unscoped products,
 * a black-dress query returned "شوكولا داكنة بالبندق" at 100% — the arithmetic
 * was right (the photographs really were near-identical) and the fixture was
 * nonsense, because the titles came from confectionery. The repository's whole
 * reason for capturing fixtures instead of writing them is that the copy in
 * them should be real; a real title on the wrong product undoes that.
 */
const GARMENT_CATEGORIES = Object.keys(SILHOUETTES);

/**
 * The shop, as a search for a black dress actually meets it.
 *
 * Mostly dark, because that is what a page of results for a black dress looks
 * like and it is the case the ranking has to get right: the *order* is what
 * carries the information when every card is black. A palette of twelve
 * unrelated colours produced a fixture with three cards and nine honest
 * rejections — true, and useless for looking at the layout.
 */
type Motif = 'plain' | 'stripes' | 'blocked' | 'speckled';

const MOTIFS: readonly Motif[] = ['plain', 'stripes', 'blocked', 'speckled'];

/**
 * A distinct garment for every product in the shop.
 *
 * Generated per index rather than cycled from a fixed table, and that is the
 * fix for the last of the ties. A twelve-entry palette across thirty products
 * gave three of them the *same colour and the same motif*, differing only in a
 * silhouette the salience crop then normalised away — so they scored exactly
 * 1.000 against each other, correctly, and the fixture showed seven cards all
 * claiming 100%.
 *
 * The spread is deliberately weighted dark. A search for a black dress meets a
 * page of black dresses, and the thing worth previewing is whether the
 * *ordering* reads when every card is the same colour.
 */
function garmentFor(position: number): {
  rgb: [number, number, number];
  motif: Motif;
} {
  // Two thirds near-black, then a tail of colours a shopper would also be
  // shown once the blacks run out.
  const dark = position % 3 !== 2;
  const step = Math.floor(position / 3);

  const rgb: [number, number, number] = dark
    ? [18 + step * 6, 18 + step * 5, 24 + step * 7]
    : [
        60 + ((step * 47) % 160),
        26 + ((step * 83) % 140),
        40 + ((step * 29) % 150),
      ];

  return {
    rgb: [
      Math.min(240, rgb[0]),
      Math.min(240, rgb[1]),
      Math.min(240, rgb[2]),
    ],
    motif: MOTIFS[position % MOTIFS.length],
  };
}

async function main(): Promise<void> {
  const client = new PrismaClient();
  const config = new ConfigService({});

  try {
    await client.$transaction(
      async (tx) => {
        const db = asPrisma(tx);
        const processing = new ImageProcessingService(config);
        const embedder = new PerceptualVisualEmbedder();
        const embeddings = new EmbeddingService(embedder, processing, new CacheService());
        const index = new PostgresVectorIndex(db, embedder);

        const products = await db.product.findMany({
          where: {
            AND: [
              PURCHASABLE_PRODUCT_WHERE,
              { category: { slug: { in: GARMENT_CATEGORIES } } },
            ],
          },
          select: { id: true, category: { select: { slug: true } } },
          // Every garment in the shop, not one per colour: a result page is
          // worth looking at only when there is enough on it to see the
          // ordering do its work.
          take: 40,
          orderBy: { createdAt: 'asc' },
        });
        if (products.length < 4) {
          throw new Error('The seeded shop has too few live garments to capture.');
        }

        // Index one photograph per product.
        for (const [position, product] of products.entries()) {
          const garment = garmentFor(position);
          const bytes = await photograph({
            rgb: garment.rgb,
            motif: garment.motif,
            // The picture matches the listing it is attached to.
            silhouette: SILHOUETTES[product.category.slug] ?? DEFAULT_SILHOUETTE,
          });
          const mediaUrl = `https://fixture.reem.local/${product.id}.jpg`;
          await db.productMedia.create({
            data: { productId: product.id, url: mediaUrl, type: MediaType.image, sortOrder: 0 },
          });

          const prepared = await processing.prepare(bytes);
          const embedding = await embeddings.embed(prepared);
          await index.upsert(product.id, [
            {
              productId: product.id,
              mediaUrl,
              position: 0,
              vector: embedding.vector,
              paletteKeys: embedding.paletteKeys,
              pattern: embedding.pattern,
              sourceChecksum: prepared.checksum,
            },
          ]);
        }

        // A full-length black dress — the case the feature was specified
        // against ("صورة لفستان أسود طويل").
        const query = await processing.prepare(
          await photograph({ rgb: [24, 24, 30], silhouette: SILHOUETTES.dresses }),
          { withFrame: true },
        );
        const embedding = await embeddings.embed(query);
        const attributes = readingsToAttributes(embedding.readings!);

        const ids = products.map((product) => product.id);
        const matches = await index.search(embedding.vector, {
          productWhere: { AND: [PURCHASABLE_PRODUCT_WHERE, { id: { in: ids } }] },
          paletteKeys: embedding.paletteKeys,
          candidateLimit: 2000,
          limit: 24,
          minSimilarity: embedder.anchors.floor * 0.92,
        });

        const rows = await db.product.findMany({
          where: { id: { in: matches.map((match) => match.productId) } },
          include: PRODUCT_CARD_INCLUDE,
        });
        const byId = new Map(rows.map((row) => [row.id, row]));

        const ranked = rankVisualMatches(
          {
            matches,
            products: byId,
            attributes,
            brief: emptyBrief(),
            anchors: embedder.anchors,
          },
          12,
        );

        const enriched = withNeighbourCategories(
          attributes,
          ranked.map((entry) => ({
            categorySlug: entry.product.category.slug,
            categoryLabel: entry.product.category.nameAr,
            similarity: entry.similarity,
          })),
        );

        write('test/fixtures/visual_search_session.json', {
          /// The captured `/visual-search/searches` response, minus the
          /// private image URL — a fixture must not point at an asset that
          /// only exists in one developer's database.
          session: {
            id: '00000000-0000-4000-8000-000000000001',
            status: 'READY',
            source: 'SCREENSHOT',
            query_image_url: null,
            image_expires_at: null,
            engine: 'reem-visual-pixels-v1',
            latency_ms: 340,
            refinements: [],
            refinements_count: 0,
            created_at: new Date('2026-09-01T09:00:00.000Z').toISOString(),
            understanding: serializeVisualAttributes(enriched),
            regions: [
              {
                id: '00000000-0000-4000-8000-000000000002',
                detector: 'WHOLE',
                slot: null,
                slot_label: null,
                label: 'القطعة بالصورة',
                box: { x: 0, y: 0, w: 1, h: 1 },
                confidence: 1,
                matches: ranked.map((scored, position) =>
                  serializeVisualMatch({
                    id: `00000000-0000-4000-8000-${String(position + 100).padStart(12, '0')}`,
                    scored,
                  }),
                ),
              },
            ],
            notice: null,
          },
          bootstrap: {
            ready: true,
            engine: embedder.name,
            coverage: {
              indexed_products: products.length,
              active_products: await db.product.count({ where: PURCHASABLE_PRODUCT_WHERE }),
              indexed_images: products.length,
            },
            limits: {
              max_image_bytes: 8388608,
              upload_max_edge: 1024,
              accepted: ['image/jpeg', 'image/png', 'image/webp'],
            },
            privacy: {
              image_retention_hours: 24,
              note: 'تُحفظ صورتكِ بشكل خاص وتُمسح تلقائياً بعد انتهاء البحث، وتبقى النتائج دون الصورة.',
            },
            try_on: {
              available: false,
              provider: 'none',
              message:
                'التجربة الافتراضية غير متوفرة بعد. حين تتوفر، سنطلب إذنكِ قبل استخدام صورتكِ.',
              retention_hours: 2,
            },
            recent: [],
            prompts: [
              'نفس هالفستان بس بالأسود',
              'شي مشابه وأقل من ٤٠٠ ألف',
              'شي أكتر احتشامًا من هيك',
              'نفس الستايل بس بقماش أخف',
            ],
          },
        });

        console.log(
          `Captured ${ranked.length} matches; top similarity ${(ranked[0]?.similarity ?? 0).toFixed(3)}.`,
        );
        throw new Rollback();
      },
      { timeout: 180_000 },
    );
  } catch (error) {
    if (!(error instanceof Rollback)) throw error;
  } finally {
    await client.$disconnect();
  }
}

function write(relative: string, payload: unknown): void {
  const path = resolve(process.cwd(), '..', relative);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
  console.log(`wrote ${relative}`);
}

void main();
