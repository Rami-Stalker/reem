import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { MediaType, ProductStatus } from '@prisma/client';
import { createHash } from 'node:crypto';
import { PrismaService } from '../../../prisma/prisma.service';
import { CatalogImageService } from '../processing/catalog-image.service';
import { ImageProcessingService } from '../processing/image-processing.service';
import { VECTOR_INDEX, VectorIndex, VectorRecord } from '../vector/vector-index';
import { EmbeddingService, paletteFrom } from './embedding.service';
import { readingsToAttributes } from '../understanding/visual-attributes';

export interface IndexRunSummary {
  productsVisited: number;
  imagesIndexed: number;
  imagesSkipped: number;
  productsFailed: number;
  durationMs: number;
}

/**
 * Keeps the catalogue's vectors in step with the catalogue.
 *
 * This is the half of visual search that costs anything, and the design is
 * entirely about it costing that once. A product's photographs are decoded and
 * described when the listing appears or its images change, and never again:
 * `sourceChecksum` on the row is the hash of the bytes the vector came from,
 * so an unchanged photograph is recognised and skipped without being fetched.
 *
 * ── Why a sweep rather than an event ─────────────────────────────────────
 *
 * A product's images change in half a dozen places — a seller edit, an admin
 * correction, a moderation action, a migration, the seed. Hooking all of them
 * means every one of them can be missed, and a missed hook is a listing that
 * silently never appears in visual search. A periodic sweep that reconciles
 * *state* is self-healing: whatever happened and whoever did it, the next pass
 * notices. `indexProduct` is exported so a write path can prompt it when it
 * wants the listing searchable immediately, but nothing depends on that call
 * being made.
 *
 * The sweep is bounded per pass and picks up where it left off, so the first
 * run over a large catalogue spreads across several nights instead of pinning
 * a core for an hour.
 */
@Injectable()
export class ProductIndexerService {
  private readonly logger = new Logger(ProductIndexerService.name);
  /** Guards against a slow pass overlapping the next tick. */
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly embeddings: EmbeddingService,
    private readonly processing: ImageProcessingService,
    private readonly images: CatalogImageService,
    @Inject(VECTOR_INDEX) private readonly index: VectorIndex,
  ) {}

  private get enabled(): boolean {
    return this.config.get<boolean>('visualSearch.indexerEnabled') ?? false;
  }

  private get batchSize(): number {
    return this.config.get<number>('visualSearch.indexerBatch') ?? 120;
  }

  private get imagesPerProduct(): number {
    return this.config.get<number>('visualSearch.imagesPerProduct') ?? 3;
  }

  /**
   * Hourly rather than nightly.
   *
   * A seller who lists a dress at nine in the morning expects it to be findable
   * that day, and the pass is cheap when there is nothing to do: one indexed
   * query returning no rows.
   */
  @Cron(CronExpression.EVERY_HOUR)
  async scheduled(): Promise<void> {
    if (!this.enabled) return;
    await this.sweep();
  }

  /**
   * One bounded pass over products that have no current vectors.
   *
   * "Current" means: indexed under the embedder in use now. Switching
   * embedders therefore re-indexes the catalogue by itself, a batch at a time,
   * while the old vectors keep answering searches until the new ones are
   * ready — which is the whole reason `embedder` is a column.
   */
  async sweep(options: { limit?: number } = {}): Promise<IndexRunSummary> {
    if (this.running) {
      this.logger.warn('A visual indexing pass is already running; skipping this tick.');
      return empty();
    }
    this.running = true;
    const startedAt = Date.now();

    const summary = empty();
    try {
      const products = await this.prisma.product.findMany({
        where: {
          status: ProductStatus.ACTIVE,
          media: { some: { type: MediaType.image } },
          imageEmbeddings: { none: { embedder: this.embeddings.name } },
        },
        select: { id: true },
        take: options.limit ?? this.batchSize,
        orderBy: { updatedAt: 'desc' },
      });

      for (const product of products) {
        summary.productsVisited += 1;
        try {
          const result = await this.indexProduct(product.id);
          summary.imagesIndexed += result.indexed;
          summary.imagesSkipped += result.skipped;
        } catch (error) {
          summary.productsFailed += 1;
          this.logger.warn(`Could not index product ${product.id}: ${String(error)}`);
        }
      }
    } finally {
      this.running = false;
    }

    summary.durationMs = Date.now() - startedAt;
    if (summary.imagesIndexed) {
      this.logger.log(
        `Indexed ${summary.imagesIndexed} image(s) across ${summary.productsVisited} product(s) in ${summary.durationMs}ms.`,
      );
    }
    return summary;
  }

  /**
   * Describe one product's photographs.
   *
   * Only the first few, ordered as the seller ordered them. A listing with
   * twelve images is eleven detail shots of a sleeve after the first two, and
   * a detail shot matches every other detail shot in the shop — indexing them
   * all costs time and *loses* precision.
   */
  async indexProduct(productId: string): Promise<{ indexed: number; skipped: number }> {
    const media = await this.prisma.productMedia.findMany({
      where: { productId, type: MediaType.image },
      orderBy: { sortOrder: 'asc' },
      take: this.imagesPerProduct,
    });

    if (!media.length) {
      await this.index.remove(productId);
      return { indexed: 0, skipped: 0 };
    }

    const existing = await this.prisma.productImageEmbedding.findMany({
      where: { productId, embedder: this.embeddings.name },
      select: { mediaUrl: true, sourceChecksum: true, vector: true, position: true, paletteKeys: true, pattern: true },
    });
    const byUrl = new Map(existing.map((row) => [row.mediaUrl, row]));

    const records: VectorRecord[] = [];
    let indexed = 0;
    let skipped = 0;

    for (const [position, image] of media.entries()) {
      const bytes = await this.images.read(image.url);
      if (!bytes) {
        // Unreachable image. Keep whatever vector it already had rather than
        // dropping the product out of search over a transient network failure.
        const previous = byUrl.get(image.url);
        if (previous) records.push({ ...previous, productId, mediaUrl: image.url, position });
        skipped += 1;
        continue;
      }

      const checksum = createHash('sha256').update(bytes).digest('hex');
      const previous = byUrl.get(image.url);
      if (previous && previous.sourceChecksum === checksum) {
        records.push({ ...previous, productId, mediaUrl: image.url, position });
        skipped += 1;
        continue;
      }

      const prepared = await this.processing.prepareQuietly(bytes);
      if (!prepared) {
        skipped += 1;
        continue;
      }

      const embedding = await this.embeddings.embed(prepared);
      records.push({
        productId,
        mediaUrl: image.url,
        position,
        vector: embedding.vector,
        paletteKeys: embedding.readings ? paletteFrom(embedding.readings) : [],
        pattern: embedding.readings
          ? readingsToAttributes(embedding.readings).pattern
          : null,
        // The hash of the *source* bytes, not of the re-encoded copy: it has
        // to answer "did the seller change this photograph", and the re-encode
        // is our own deterministic step on top of that.
        sourceChecksum: checksum,
      });
      indexed += 1;
    }

    await this.index.upsert(productId, records);
    return { indexed, skipped };
  }

  /** Drops a product's vectors — a delisting, or a forced re-index. */
  async forget(productId: string): Promise<number> {
    return this.index.remove(productId);
  }

  /** What the search surface reports as its readiness. */
  async coverage(): Promise<{ indexedProducts: number; activeProducts: number }> {
    const [indexedProducts, activeProducts] = await Promise.all([
      this.prisma.product
        .count({
          where: {
            status: ProductStatus.ACTIVE,
            imageEmbeddings: { some: { embedder: this.embeddings.name } },
          },
        })
        .catch(() => 0),
      this.prisma.product.count({ where: { status: ProductStatus.ACTIVE } }),
    ]);
    return { indexedProducts, activeProducts };
  }
}

function empty(): IndexRunSummary {
  return {
    productsVisited: 0,
    imagesIndexed: 0,
    imagesSkipped: 0,
    productsFailed: 0,
    durationMs: 0,
  };
}
