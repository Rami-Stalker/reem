import { Inject, Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../../prisma/prisma.service';
import { VISUAL_EMBEDDER, VisualEmbedder } from '../embedding/visual-embedder';
import {
  VectorIndex,
  VectorMatch,
  VectorRecord,
  VectorSearchOptions,
} from './vector-index';

/**
 * The vector index, in the database the platform already runs.
 *
 * ── Why exact scoring in Node is the right call *today* ──────────────────
 *
 * Vectors live in a `double precision[]` column and the cosine is computed in
 * process over a bounded candidate pull. That sounds like the naive thing, and
 * for a catalogue of a hundred million it would be. For this one it is
 * straightforwardly better than the alternatives:
 *
 *  - It is **exact**. An approximate index trades recall for speed, and at a
 *    few tens of thousands of vectors there is no speed to buy: 4 000 × 184
 *    multiply-adds is under two milliseconds, which is a rounding error beside
 *    the round trip that fetched the rows.
 *  - It needs **no extension**. `pgvector` is not installed on the native
 *    PostgreSQL service this project provisions, and requiring an extension to
 *    ship a feature is how a feature does not ship.
 *  - It keeps the **re-weighting**, which is the thing that makes "نفس
 *    الفستان بس بالأسود" work. A pgvector index is built for one distance
 *    function; per-query block weights cannot be pushed into it, so even after
 *    the upgrade this path stays as the re-ranking stage.
 *
 * The upgrade path is therefore additive rather than a rewrite: pgvector does
 * the coarse k-NN with the default weights, this code re-ranks the top few
 * hundred with the query's weights, and `VectorIndex` does not change.
 *
 * ── The two-pass candidate pull ─────────────────────────────────────────
 *
 * The one place a cap could hurt recall is the pull itself: taking "some 4 000
 * rows" out of a large filtered set could miss the right dress. So the pull is
 * ordered by the thing that correlates most strongly with the answer — colour.
 * Pass one asks only for rows that share a dominant colour with the query,
 * which is both far more selective and far more likely to contain the match.
 * Pass two tops up from everything else, so a colour the palette reader got
 * wrong costs ranking rather than recall.
 */
@Injectable()
export class PostgresVectorIndex implements VectorIndex {
  private readonly logger = new Logger(PostgresVectorIndex.name);
  readonly name = 'postgres-array-exact';

  constructor(
    private readonly prisma: PrismaService,
    @Inject(VISUAL_EMBEDDER) private readonly embedder: VisualEmbedder,
  ) {}

  async upsert(productId: string, records: readonly VectorRecord[]): Promise<void> {
    if (!records.length) {
      await this.remove(productId);
      return;
    }

    const keep = new Set(records.map((record) => record.mediaUrl));

    await this.prisma.$transaction([
      // Images the seller removed from the listing must lose their vectors, or
      // a search keeps matching a photograph that is no longer on the card.
      this.prisma.productImageEmbedding.deleteMany({
        where: {
          productId,
          embedder: this.embedder.name,
          mediaUrl: { notIn: [...keep] },
        },
      }),
      ...records.map((record) =>
        this.prisma.productImageEmbedding.upsert({
          where: {
            productId_mediaUrl_embedder: {
              productId,
              mediaUrl: record.mediaUrl,
              embedder: this.embedder.name,
            },
          },
          create: {
            productId,
            mediaUrl: record.mediaUrl,
            position: record.position,
            embedder: this.embedder.name,
            dimensions: this.embedder.dimensions,
            vector: record.vector,
            paletteKeys: record.paletteKeys,
            pattern: record.pattern,
            sourceChecksum: record.sourceChecksum,
          },
          update: {
            position: record.position,
            dimensions: this.embedder.dimensions,
            vector: record.vector,
            paletteKeys: record.paletteKeys,
            pattern: record.pattern,
            sourceChecksum: record.sourceChecksum,
          },
        }),
      ),
    ]);
  }

  async remove(productId: string): Promise<number> {
    const { count } = await this.prisma.productImageEmbedding.deleteMany({
      where: { productId, embedder: this.embedder.name },
    });
    return count;
  }

  async size(): Promise<number> {
    return this.prisma.productImageEmbedding.count({
      where: { embedder: this.embedder.name },
    });
  }

  async search(
    vector: readonly number[],
    options: VectorSearchOptions,
  ): Promise<VectorMatch[]> {
    const rows = await this.pullCandidates(options);
    if (!rows.length) return [];

    const scored: VectorMatch[] = [];
    for (const row of rows) {
      // A row written by an older build under the same embedder name would
      // score nonsense. Skipping it is right: it will be rewritten by the next
      // indexer pass anyway.
      if (row.vector.length !== this.embedder.dimensions) continue;

      const { total, parts } = this.embedder.similarity(
        vector,
        row.vector,
        options.weights,
      );
      if (total < options.minSimilarity) continue;

      scored.push({
        productId: row.productId,
        mediaUrl: row.mediaUrl,
        position: row.position,
        similarity: total,
        parts,
        paletteKeys: row.paletteKeys,
        pattern: row.pattern,
      });
    }

    scored.sort((a, b) => b.similarity - a.similarity);

    // One row per product. A listing with six photographs would otherwise fill
    // the whole first page with itself, and the best of its six is the only
    // one that says anything.
    const best = new Map<string, VectorMatch>();
    for (const match of scored) {
      if (!best.has(match.productId)) best.set(match.productId, match);
    }

    return [...best.values()].slice(0, options.limit);
  }

  private async pullCandidates(options: VectorSearchOptions) {
    const select = {
      productId: true,
      mediaUrl: true,
      position: true,
      vector: true,
      paletteKeys: true,
      pattern: true,
    } as const;

    const base = {
      embedder: this.embedder.name,
      product: options.productWhere,
      ...(options.excludeProductIds?.length
        ? { productId: { notIn: [...options.excludeProductIds] } }
        : {}),
    };

    // The primary photograph first: it is the one shot on a plain ground, and
    // the one the card will show. A top-up that filled itself with sixth
    // detail shots would rank worse *and* look wrong.
    const orderBy = [{ position: 'asc' as const }, { updatedAt: 'desc' as const }];

    const palette = (options.paletteKeys ?? []).filter(Boolean);
    const first = palette.length
      ? await this.prisma.productImageEmbedding.findMany({
          where: { ...base, paletteKeys: { hasSome: [...palette] } },
          select,
          take: options.candidateLimit,
          orderBy,
        })
      : [];

    if (first.length >= options.candidateLimit) return first;

    const seen = new Set(first.map((row) => `${row.productId}:${row.mediaUrl}`));
    const rest = await this.prisma.productImageEmbedding.findMany({
      where: base,
      select,
      take: options.candidateLimit - first.length + seen.size,
      orderBy,
    });

    const topUp = rest.filter((row) => !seen.has(`${row.productId}:${row.mediaUrl}`));
    if (palette.length && topUp.length) {
      this.logger.debug(
        `Palette pass returned ${first.length}; topped up with ${topUp.length} rows.`,
      );
    }

    return [...first, ...topUp].slice(0, options.candidateLimit);
  }
}
