import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  AiStylistFeedback,
  MediaType,
  MediaVisibility,
  OutfitSlot,
  Prisma,
  VisualRegionDetector,
  VisualSearchSource,
  VisualSearchStatus,
} from '@prisma/client';
import {
  PRODUCT_CARD_INCLUDE,
  PURCHASABLE_PRODUCT_WHERE,
  defaultOffer,
} from '../../../common/catalog/product-include';
import { PrismaService } from '../../../prisma/prisma.service';
import { MediaService } from '../../media/media.service';
import { BriefExtractorService } from '../../ai-stylist/understanding/brief-extractor.service';
import {
  StyleBrief,
  briefFromJson,
  briefToJson,
} from '../../ai-stylist/understanding/style-brief';
import { categorySlugsForSlots } from '../../ai-stylist/understanding/stylist-lexicon';
import { EmbeddingService } from '../embedding/embedding.service';
import { weightsForQuery } from '../embedding/visual-descriptor';
import { ImageProcessingService } from '../processing/image-processing.service';
import { DetectedRegion } from '../regions/region-segmenter';
import {
  VisualAttributes,
  withNeighbourCategories,
} from '../understanding/visual-attributes';
import { VisualUnderstandingService } from '../understanding/visual-understanding.service';
import { VECTOR_INDEX, VectorIndex, VectorMatch } from '../vector/vector-index';
import {
  MIN_DISPLAYED_SIMILARITY,
  ScoredVisualMatch,
  VisualCandidate,
  rankVisualMatches,
} from './visual-ranker';

export interface VisualSearchResultView {
  region: {
    id: string;
    detector: VisualRegionDetector;
    slot: string | null;
    label: string;
    box: { x: number; y: number; w: number; h: number };
    confidence: number;
  };
  matches: Array<{ id: string; scored: ScoredVisualMatch }>;
}

export interface VisualSearchView {
  session: Prisma.VisualSearchSessionGetPayload<{ include: { regions: true } }>;
  attributes: VisualAttributes;
  brief: StyleBrief;
  results: VisualSearchResultView[];
  /** Present when the catalogue simply has nothing indexed yet. */
  notice: string | null;
}

/**
 * Ohara Visual Shopping — the orchestrator.
 *
 * It owns the sequence and nothing else. Every step below belongs to a service
 * that can be tested, replaced or switched off on its own:
 *
 *   bytes → ImageProcessingService  (sniff, bound, re-encode, normalise)
 *         → EmbeddingService        (descriptor, cached by content hash)
 *         → VisualUnderstandingService (attributes, brief, regions)
 *         → VectorIndex             (nearest neighbours, per region)
 *         → rankVisualMatches       (calibrated similarity, reasons)
 *         → rows
 *
 * Two properties of that chain are worth stating because everything else
 * follows from them.
 *
 * **The photograph is not the search.** The descriptor is computed once and
 * stored on the session; the image itself is on a retention clock and is
 * deleted while the session lives on. Every refinement afterwards — "بس
 * بالأسود", "وتحت ٤٠٠ ألف" — re-runs against the stored vector. She is never
 * asked to upload again, and the platform is never holding her screenshot
 * longer than the search needed it.
 *
 * **Nothing is invented.** Every card is a live `SellerOffer` on an ACTIVE
 * product, pulled through the same `PURCHASABLE_PRODUCT_WHERE` the catalogue,
 * search and stylist use. Every percentage is a calibrated cosine between two
 * vectors this system computed. When there is no good match the answer is an
 * empty list and a sentence saying so, which is a better answer than a page of
 * things that merely exist.
 */
@Injectable()
export class VisualSearchService {
  private readonly logger = new Logger(VisualSearchService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly processing: ImageProcessingService,
    private readonly embeddings: EmbeddingService,
    private readonly understanding: VisualUnderstandingService,
    private readonly briefs: BriefExtractorService,
    private readonly media: MediaService,
    @Inject(VECTOR_INDEX) private readonly index: VectorIndex,
  ) {}

  private get resultsPerRegion(): number {
    return this.config.get<number>('visualSearch.resultsPerRegion') ?? 12;
  }

  private get candidateLimit(): number {
    return this.config.get<number>('visualSearch.candidateLimit') ?? 4000;
  }

  private get retentionHours(): number {
    return this.config.get<number>('visualSearch.imageRetentionHours') ?? 24;
  }

  // ── Search ────────────────────────────────────────────────────────────

  /**
   * A photograph in, a session out.
   *
   * The session row is written *before* the search runs and left `PENDING`
   * until it succeeds. That ordering costs one extra write and buys the thing
   * that matters most in a privacy-sensitive path: an image whose search
   * crashed still has a row pointing at it, so the retention sweeper can find
   * it and delete it. Storing the image after a successful search would leak
   * every failure.
   */
  async search(input: {
    userId: string;
    bytes: Buffer;
    source: VisualSearchSource;
    originalName?: string;
  }): Promise<VisualSearchView> {
    const startedAt = Date.now();

    const prepared = await this.processing.prepare(input.bytes, { withFrame: true });
    const embedding = await this.embeddings.embed(prepared);

    // The re-encoded copy is what is stored, never the file she sent: EXIF is
    // already gone, the format is already ours, and the size is already
    // bounded.
    const asset = await this.media.upload(input.userId, {
      buffer: prepared.buffer,
      originalName: input.originalName,
      visibility: MediaVisibility.PRIVATE,
      purpose: 'visual_search',
      allowedKinds: [MediaType.image],
    });
    // Claimed straight away so the *orphan* sweeper leaves it alone — its life
    // is governed by the retention clock below instead, which is a different
    // rule with a much shorter hand. Addressed by its private URL because that
    // is the form `markAttached` recognises.
    await this.media.markAttached(input.userId, [`/media/${asset.id}/file`]);

    const session = await this.prisma.visualSearchSession.create({
      data: {
        userId: input.userId,
        status: VisualSearchStatus.PENDING,
        source: input.source,
        queryAssetId: asset.id,
        checksum: prepared.checksum,
        embedder: this.embeddings.name,
        dimensions: this.embeddings.dimensions,
        vector: embedding.vector,
        imageExpiresAt: new Date(Date.now() + this.retentionHours * 3600_000),
      },
    });

    const read = await this.understanding.understand(prepared, embedding);

    try {
      const view = await this.runSearch({
        sessionId: session.id,
        userId: input.userId,
        vector: embedding.vector,
        paletteKeys: embedding.paletteKeys,
        attributes: read.attributes,
        brief: read.brief,
        regions: read.regions,
        sourceBytes: prepared.buffer,
      });

      await this.prisma.visualSearchSession.update({
        where: { id: session.id },
        data: {
          status: VisualSearchStatus.READY,
          engine: read.engine,
          latencyMs: Date.now() - startedAt,
          understanding: view.attributes as unknown as Prisma.InputJsonValue,
          brief: briefToJson(view.brief),
        },
      });

      return this.load(input.userId, session.id);
    } catch (error) {
      await this.prisma.visualSearchSession
        .update({
          where: { id: session.id },
          data: { status: VisualSearchStatus.FAILED, engine: read.engine },
        })
        .catch(() => undefined);
      throw error;
    }
  }

  /**
   * One typed sentence, folded onto an existing search.
   *
   * The stylist's extractor reads the sentence; `mergeBriefs` decides what
   * replaces and what accumulates; `weightsForQuery` decides what the vector
   * comparison should still care about. Then the same search runs again over
   * the same stored descriptor.
   *
   * The image is not re-read and, by design, may no longer exist — everything
   * here needs the vector and the brief, both of which are on the row.
   */
  async refine(input: {
    userId: string;
    sessionId: string;
    text: string;
  }): Promise<VisualSearchView> {
    const message = input.text.trim();
    if (!message) throw new BadRequestException('EMPTY_REFINEMENT');

    const session = await this.requireSession(input.userId, input.sessionId);
    if (!session.vector.length) throw new BadRequestException('SESSION_HAS_NO_DESCRIPTOR');

    const current = briefFromJson(session.brief);
    const history = refinementHistory(session.refinements).map((entry) => ({
      role: 'user' as const,
      content: entry.text,
    }));

    const extraction = await this.briefs.extract({
      message,
      currentBrief: current,
      history,
    });

    const attributes = attributesFromJson(session.understanding);
    const regions = await this.prisma.visualSearchRegion.findMany({
      where: { sessionId: session.id },
      orderBy: { position: 'asc' },
    });

    const view = await this.runSearch({
      sessionId: session.id,
      userId: input.userId,
      vector: session.vector,
      paletteKeys: attributes.colours.map((colour) => colour.key),
      attributes,
      brief: extraction.brief,
      // Reuse the regions the photograph produced. Re-segmenting would need
      // the image, which the retention clock may already have removed — and
      // the regions are a fact about the picture, not about the sentence.
      regions: regions.map((region) => ({
        detector: region.detector,
        slot: region.slot,
        label: region.label,
        box: region.boundingBox as unknown as DetectedRegion['box'],
        confidence: region.confidence,
      })),
      regionVectors: new Map(regions.map((region) => [region.position, region.vector])),
    });

    await this.prisma.visualSearchSession.update({
      where: { id: session.id },
      data: {
        brief: briefToJson(view.brief),
        refinementsCount: { increment: 1 },
        refinements: [
          ...refinementHistory(session.refinements),
          { text: message.slice(0, 400), at: new Date().toISOString() },
        ].slice(-10) as unknown as Prisma.InputJsonValue,
      },
    });

    return this.load(input.userId, session.id);
  }

  // ── The pass itself ───────────────────────────────────────────────────

  private async runSearch(input: {
    sessionId: string;
    userId: string;
    vector: number[];
    paletteKeys: string[];
    attributes: VisualAttributes;
    brief: StyleBrief;
    regions: DetectedRegion[];
    /** Present on the first pass; used to embed each region separately. */
    sourceBytes?: Buffer;
    /** Present on a refinement; the region descriptors already computed. */
    regionVectors?: Map<number, number[]>;
  }): Promise<{ attributes: VisualAttributes; brief: StyleBrief }> {
    // A refinement replaces the previous answer wholesale. Keeping both would
    // mean a page that mixes "before you said black" with "after", and there
    // is no order in which that reads as one result list.
    await this.prisma.visualSearchResult.deleteMany({
      where: { sessionId: input.sessionId },
    });
    await this.prisma.visualSearchRegion.deleteMany({
      where: { sessionId: input.sessionId },
    });

    const weights = weightsForQuery({
      imageColours: input.attributes.colours.map((colour) => colour.key),
      requestedColours: input.brief.colours,
    });

    const answered = new Set<string>();
    let attributes = input.attributes;

    for (const [position, region] of input.regions.entries()) {
      const vector = await this.vectorForRegion({
        region,
        position,
        wholeVector: input.vector,
        sourceBytes: input.sourceBytes,
        cached: input.regionVectors,
      });
      if (!vector) continue;

      const row = await this.prisma.visualSearchRegion.create({
        data: {
          sessionId: input.sessionId,
          detector: region.detector,
          slot: region.slot,
          label: region.label,
          boundingBox: region.box as unknown as Prisma.InputJsonValue,
          confidence: region.confidence,
          vector,
          paletteKeys: input.paletteKeys,
          position,
        },
      });

      const matches = await this.index.search(vector, {
        productWhere: this.productWhere(input.brief, region),
        paletteKeys: input.brief.colours.length ? input.brief.colours : input.paletteKeys,
        weights,
        candidateLimit: this.candidateLimit,
        limit: this.resultsPerRegion * 3,
        // The floor is applied on the *calibrated* score in the ranker; here
        // it is deliberately loose, so a slightly odd raw cosine still reaches
        // the attribute half that might rescue it.
        minSimilarity: this.embeddings.anchors.floor * 0.92,
        excludeProductIds: [...answered],
      });
      if (!matches.length) continue;

      const products = await this.loadProducts(matches);

      // The first region's neighbours are what name the category, so the
      // attribute half of *its own* scoring cannot depend on them — that would
      // be circular. They are folded in before the next region and before the
      // answer is returned.
      const ranked = rankVisualMatches(
        {
          matches,
          products,
          attributes,
          brief: input.brief,
          anchors: this.embeddings.anchors,
        },
        this.resultsPerRegion,
      );

      if (position === 0) {
        attributes = withNeighbourCategories(
          attributes,
          ranked.map((entry) => ({
            categorySlug: entry.product.category.slug,
            // The Arabic name travels with the vote, so the chip the client
            // draws never has to render a slug.
            categoryLabel: entry.product.category.nameAr,
            similarity: entry.similarity,
          })),
        );
      }

      await this.persistResults(input.sessionId, row.id, ranked);
      for (const entry of ranked) answered.add(entry.product.id);
    }

    return { attributes, brief: input.brief };
  }

  /**
   * The descriptor a region is searched with.
   *
   * The whole frame reuses the session's vector — it is the same picture. A
   * band or a detection is cropped out of the source and described on its own,
   * which is what makes a handbag in the corner compete against handbags
   * rather than against full-length looks.
   */
  private async vectorForRegion(input: {
    region: DetectedRegion;
    position: number;
    wholeVector: number[];
    sourceBytes?: Buffer;
    cached?: Map<number, number[]>;
  }): Promise<number[] | null> {
    if (input.region.detector === VisualRegionDetector.WHOLE) return input.wholeVector;

    const cached = input.cached?.get(input.position);
    if (cached?.length) return cached;

    if (!input.sourceBytes) return null;

    try {
      const prepared = await this.processing.prepareRegion(
        input.sourceBytes,
        input.region.box,
      );
      const embedding = await this.embeddings.embed(prepared);
      return embedding.vector;
    } catch (error) {
      // One unreadable crop out of four. The other regions still answer.
      this.logger.debug(`Could not embed a region: ${String(error)}`);
      return null;
    }
  }

  /**
   * The hard constraints on a visual search.
   *
   * Short on purpose. The vector is what decides *what* she is shown; a `WHERE`
   * is only there to keep the result buyable and to honour the things she said
   * in words. Filtering on the colour the pixels measured would be a
   * measurement promoted to a rule — and the descriptor already scores colour
   * far more subtly than an `IN` clause can.
   */
  private productWhere(
    brief: StyleBrief,
    region: DetectedRegion,
  ): Prisma.ProductWhereInput {
    const and: Prisma.ProductWhereInput[] = [PURCHASABLE_PRODUCT_WHERE];

    if (brief.categorySlugs.length) {
      and.push({ category: { slug: { in: brief.categorySlugs } } });
    }
    if (brief.budgetMax !== null) {
      and.push({ minPriceSyp: { lte: new Prisma.Decimal(brief.budgetMax) } });
    }
    if (brief.budgetMin !== null) {
      and.push({ maxPriceSyp: { gte: new Prisma.Decimal(brief.budgetMin) } });
    }
    // A colour she ruled out in words is a refusal, not a preference — the
    // same rule the stylist's retrieval applies, and the only colour clause
    // here.
    for (const colour of brief.avoidColours) {
      and.push({ NOT: { imageEmbeddings: { some: { paletteKeys: { has: colour } } } } });
    }
    // A `VISION` detection knows what it found; a `LAYOUT` band only guesses,
    // so its slot narrows nothing.
    if (region.detector === VisualRegionDetector.VISION && region.slot) {
      const slugs = categorySlugsForSlots([region.slot as OutfitSlot]);
      if (slugs.length) and.push({ category: { slug: { in: slugs } } });
    }

    return { AND: and };
  }

  private async loadProducts(matches: VectorMatch[]): Promise<Map<string, VisualCandidate>> {
    const ids = [...new Set(matches.map((match) => match.productId))];
    if (!ids.length) return new Map();

    const rows = await this.prisma.product.findMany({
      where: { id: { in: ids }, ...PURCHASABLE_PRODUCT_WHERE },
      include: PRODUCT_CARD_INCLUDE,
    });
    return new Map(rows.map((row) => [row.id, row]));
  }

  private async persistResults(
    sessionId: string,
    regionId: string,
    ranked: ScoredVisualMatch[],
  ): Promise<void> {
    if (!ranked.length) return;

    await this.prisma.visualSearchResult.createMany({
      data: ranked.map((entry, position) => {
        const offer = defaultOffer(entry.product);
        return {
          sessionId,
          regionId,
          productId: entry.product.id,
          offerId: offer?.id ?? null,
          matchedMediaUrl: entry.match.mediaUrl,
          similarity: round(entry.similarity),
          visualScore: round(entry.visualScore),
          attributeScore: round(entry.attributeScore),
          position,
          reason: entry.reason,
          reasonCodes: entry.reasons,
          quotedPriceSyp: entry.product.minPriceSyp,
        };
      }),
    });
  }

  // ── Reads ─────────────────────────────────────────────────────────────

  async load(userId: string, sessionId: string): Promise<VisualSearchView> {
    const session = await this.prisma.visualSearchSession.findFirst({
      where: { id: sessionId, userId },
      include: { regions: { orderBy: { position: 'asc' } } },
    });
    if (!session) throw new NotFoundException('VISUAL_SEARCH_NOT_FOUND');

    const results = await this.prisma.visualSearchResult.findMany({
      where: { sessionId },
      orderBy: [{ position: 'asc' }],
    });

    const products = await this.prisma.product.findMany({
      where: { id: { in: [...new Set(results.map((row) => row.productId))] } },
      include: PRODUCT_CARD_INCLUDE,
    });
    const byId = new Map(products.map((row) => [row.id, row]));

    const grouped: VisualSearchResultView[] = session.regions.map((region) => ({
      region: {
        id: region.id,
        detector: region.detector,
        slot: region.slot,
        label: region.label,
        box: region.boundingBox as unknown as { x: number; y: number; w: number; h: number },
        confidence: region.confidence,
      },
      matches: results
        .filter((row) => row.regionId === region.id)
        .flatMap((row) => {
          const product = byId.get(row.productId);
          if (!product) return [];
          return [
            {
              id: row.id,
              scored: {
                match: {
                  productId: row.productId,
                  mediaUrl: row.matchedMediaUrl ?? '',
                  position: row.position,
                  similarity: row.similarity,
                  parts: {},
                  paletteKeys: [],
                  pattern: null,
                },
                product,
                similarity: row.similarity,
                visualScore: row.visualScore,
                attributeScore: row.attributeScore,
                reasons: row.reasonCodes as ScoredVisualMatch['reasons'],
                reason: row.reason,
              } satisfies ScoredVisualMatch,
            },
          ];
        }),
    }));

    const total = grouped.reduce((sum, region) => sum + region.matches.length, 0);

    return {
      session,
      attributes: attributesFromJson(session.understanding),
      brief: briefFromJson(session.brief),
      results: grouped,
      notice: total ? null : await this.emptyNotice(),
    };
  }

  async list(userId: string, limit: number) {
    return this.prisma.visualSearchSession.findMany({
      where: { userId },
      include: { regions: { orderBy: { position: 'asc' } } },
      orderBy: { createdAt: 'desc' },
      take: Math.min(50, Math.max(1, limit)),
    });
  }

  /**
   * Deletes a search and the photograph behind it, now.
   *
   * The retention clock is the platform's promise; this is hers. It runs
   * immediately, removes the bytes and the row, and does not wait for a sweep.
   */
  async forget(userId: string, sessionId: string): Promise<void> {
    const session = await this.requireSession(userId, sessionId);
    if (session.queryAssetId) await this.media.purge(session.queryAssetId);
    await this.prisma.visualSearchSession.delete({ where: { id: session.id } });
  }

  async recordFeedback(input: {
    userId: string;
    resultId: string;
    feedback: AiStylistFeedback;
  }) {
    const row = await this.prisma.visualSearchResult.findFirst({
      where: { id: input.resultId, session: { userId: input.userId } },
    });
    if (!row) throw new NotFoundException('VISUAL_RESULT_NOT_FOUND');

    return this.prisma.visualSearchResult.update({
      where: { id: row.id },
      data: { feedback: input.feedback, feedbackAt: new Date() },
    });
  }

  async requireSession(userId: string, sessionId: string) {
    const session = await this.prisma.visualSearchSession.findFirst({
      where: { id: sessionId, userId },
    });
    if (!session) throw new NotFoundException('VISUAL_SEARCH_NOT_FOUND');
    return session;
  }

  /**
   * Why an empty result is empty.
   *
   * The two reasons are completely different and conflating them is how a
   * launch looks broken: "nothing in the shop looks like this" is an answer,
   * while "no photograph in the shop has been described yet" is an operational
   * state on the platform's side. She is told which.
   */
  private async emptyNotice(): Promise<string> {
    const indexed = await this.index.size();
    return indexed === 0
      ? 'ما زال البحث بالصورة يفهرس صور المنتجات. جرّبي بعد قليل.'
      : 'لم أجد شيئاً قريباً بما يكفي من هذه الصورة. جرّبي صورة أوضح، أو صفي لي ما تبحثين عنه.';
  }

  /** The readiness figure the bootstrap route reports. */
  async indexedVectors(): Promise<number> {
    return this.index.size();
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────

export function attributesFromJson(value: Prisma.JsonValue | null): VisualAttributes {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {
      colours: [],
      pattern: 'plain',
      tone: 'mid',
      framing: 'product',
      studioBackground: false,
      subjectFill: 0,
      categories: [],
      slots: [],
      provenance: {},
      confidence: 0,
    };
  }
  return value as unknown as VisualAttributes;
}

function refinementHistory(
  value: Prisma.JsonValue | null,
): Array<{ text: string; at: string }> {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry) => {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) return [];
    const record = entry as Record<string, unknown>;
    const text = typeof record['text'] === 'string' ? record['text'] : null;
    if (!text) return [];
    return [{ text, at: String(record['at'] ?? '') }];
  });
}

function round(value: number): number {
  return Math.round(value * 10000) / 10000;
}
