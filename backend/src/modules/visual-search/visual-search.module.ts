import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AiStylistModule } from '../ai-stylist/ai-stylist.module';
import { MediaModule } from '../media/media.module';
import { EmbeddingService } from './embedding/embedding.service';
import { PerceptualVisualEmbedder } from './embedding/perceptual-embedder';
import { ProductIndexerService } from './embedding/product-indexer.service';
import { VISUAL_EMBEDDER, VisualEmbedder } from './embedding/visual-embedder';
import { VisualRetentionService } from './privacy/visual-retention.service';
import { CatalogImageService } from './processing/catalog-image.service';
import { ImageProcessingService } from './processing/image-processing.service';
import { VisualRecommendationService } from './recommendation/visual-recommendation.service';
import { VisualSearchService } from './search/visual-search.service';
import { VisualTryOnService } from './try-on/visual-try-on.service';
import {
  DisabledTryOnProvider,
  TRY_ON_PROVIDER,
  TryOnProvider,
} from './try-on/try-on-provider';
import { VisualUnderstandingService } from './understanding/visual-understanding.service';
import { AnthropicVisionAnalyzer } from './understanding/vision/anthropic-vision-analyzer';
import {
  DisabledVisionAnalyzer,
  VISION_ANALYZER,
  VisionAnalyzer,
} from './understanding/vision/vision-analyzer';
import { PostgresVectorIndex } from './vector/postgres-vector-index';
import { VECTOR_INDEX } from './vector/vector-index';
import { VisualSearchController } from './visual-search.controller';

/**
 * Reem Visual Shopping.
 *
 * Sits beside `AiStylistModule` rather than inside it, and imports it: the
 * stylist owns the *vocabulary* — the colour lexicon, `StyleBrief`,
 * `sanitiseBrief`, the text extractor — and this module owns the *pixels*.
 * Both produce the same brief type and query the same catalogue helpers, so a
 * dress found by photograph and a dress found by sentence are the same card
 * with the same reasons attached.
 *
 * ── The three provider bindings are the whole configuration story ─────────
 *
 * Each one defaults to a complete, deterministic implementation, and each
 * upgrade is one class plus one environment variable.
 *
 *  - `VISUAL_EMBEDDER` — the hand-built perceptual descriptor, always. A
 *    learned model (CLIP, SigLIP, a hosted embedding API) binds here; rows
 *    already written keep their own `embedder` name, both generations coexist,
 *    and the indexer re-describes the catalogue in the background while the
 *    old vectors keep answering searches.
 *  - `VECTOR_INDEX` — exact cosine over a bounded candidate pull in Postgres.
 *    pgvector, Qdrant or anything else binds here; see the note in
 *    `postgres-vector-index.ts` for why the exact re-rank survives that change
 *    rather than being replaced by it.
 *  - `VISION_ANALYZER` — off. With `VISUAL_VISION_PROVIDER=anthropic` and a
 *    key, Claude proposes a garment category, an occasion and item boxes,
 *    every one of which is sanitised against the closed vocabularies before it
 *    can reach a query.
 *  - `TRY_ON_PROVIDER` — off, and honestly so. There is no mock: with nothing
 *    configured the API answers 503 and never invents an image. See
 *    `try-on-provider.ts`.
 *
 * With none of them configured the feature is complete: she uploads a
 * photograph, the descriptor finds the closest live listings, the percentage
 * on each card is a calibrated cosine, and a typed sentence refines it through
 * the stylist's own extractor. That is the mode the tests run in.
 */
@Module({
  imports: [
    // The query image is stored, read back and eventually deleted through
    // `MediaService`; the indexer reads catalogue bytes through it too.
    MediaModule,
    // For `BriefExtractorService` — natural-language refinement is the
    // stylist's parser, not a second one.
    AiStylistModule,
  ],
  controllers: [VisualSearchController],
  providers: [
    ImageProcessingService,
    CatalogImageService,
    EmbeddingService,
    ProductIndexerService,
    VisualUnderstandingService,
    VisualSearchService,
    VisualRecommendationService,
    VisualTryOnService,
    VisualRetentionService,
    {
      provide: VISUAL_EMBEDDER,
      useFactory: (): VisualEmbedder => new PerceptualVisualEmbedder(),
    },
    {
      provide: VECTOR_INDEX,
      useClass: PostgresVectorIndex,
    },
    {
      provide: VISION_ANALYZER,
      inject: [ConfigService],
      useFactory: (config: ConfigService): VisionAnalyzer => {
        const provider = config.get<string>('visualSearch.visionProvider') ?? 'none';
        const apiKey = config.get<string>('visualSearch.visionApiKey') ?? '';

        // A provider named without a key is a misconfiguration, not a request
        // to fail: the measured path is a complete implementation, so visual
        // search stays up and the operator sees an unconfigured provider.
        if (provider !== 'anthropic' || !apiKey) return new DisabledVisionAnalyzer();

        return new AnthropicVisionAnalyzer({
          apiKey,
          baseUrl:
            config.get<string>('visualSearch.visionBaseUrl') ??
            'https://api.anthropic.com',
          model: config.get<string>('visualSearch.visionModel') ?? 'claude-sonnet-5',
          timeoutMs: config.get<number>('visualSearch.visionTimeoutMs') ?? 9000,
          maxOutputTokens: config.get<number>('visualSearch.visionMaxTokens') ?? 900,
          detectItems: config.get<boolean>('visualSearch.visionDetectItems') ?? true,
        });
      },
    },
    {
      provide: TRY_ON_PROVIDER,
      useFactory: (): TryOnProvider => new DisabledTryOnProvider(),
    },
  ],
  // Exported for the two features this one was built to feed. `AiStylistModule`
  // can ask for the cheaper twin of a dress she liked; the Trend Engine can ask
  // which listings look like the one that is climbing.
  exports: [VisualRecommendationService, ProductIndexerService],
})
export class VisualSearchModule {}
