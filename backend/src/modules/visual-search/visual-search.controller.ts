import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  ServiceUnavailableException,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import { VisualSearchSource, VisualTryOnStatus } from '@prisma/client';
import type { Request } from 'express';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { EmbeddingService } from './embedding/embedding.service';
import { ProductIndexerService } from './embedding/product-indexer.service';
import { VisualRecommendationService } from './recommendation/visual-recommendation.service';
import { VisualSearchService } from './search/visual-search.service';
import { VisualTryOnService } from './try-on/visual-try-on.service';
import {
  RefineVisualSearchDto,
  SimilarProductsDto,
  TryOnRequestDto,
  VisualFeedbackDto,
  VisualSessionListDto,
} from './dto/visual-search.dto';
import {
  serializeTryOn,
  serializeTryOnCapability,
  serializeVisualMatch,
  serializeVisualSession,
} from './visual-search.serializer';

/** The `multer` shape, declared locally — same reasoning as `MediaController`. */
interface UploadedFileLike {
  buffer: Buffer;
  originalname?: string;
  size: number;
}

/**
 * `/visual-search` — Reem Visual Shopping.
 *
 * Every route is authenticated. A visual search is a photograph from her
 * camera roll and, in the try-on case, a photograph of her body; neither is a
 * thing to hang off an anonymous session token. The same reasoning the stylist
 * controller states, one step more strongly.
 *
 * The throttles are the tightest in the API, and deliberately: a search
 * decodes a full-size image, resamples it twice and scores a few thousand
 * vectors. That is a request a stuck client retrying can turn into an outage,
 * and one worth stopping early.
 *
 * The image arrives as multipart on *this* endpoint rather than through
 * `/media/uploads` first. That is not a shortcut — it is what keeps the
 * retention promise enforceable: the server decides in one place that the
 * bytes are private, re-encodes them, stamps an expiry on them and writes the
 * session that owns them. A two-step flow would leave an uploaded photograph
 * with no session, no expiry and nobody responsible for it whenever she backed
 * out between the two calls.
 */
@SelfScoped(
  'a search session, its regions and its results belong to the caller who opened it',
)
@Controller('visual-search')
export class VisualSearchController {
  constructor(
    private readonly search: VisualSearchService,
    private readonly recommendations: VisualRecommendationService,
    private readonly tryOn: VisualTryOnService,
    private readonly indexer: ProductIndexerService,
    private readonly embeddings: EmbeddingService,
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  // ── Discovery surface ─────────────────────────────────────────────────

  /**
   * Everything an empty "search by image" screen needs before she has picked
   * anything: whether the feature can answer at all, what it will accept, and
   * what she searched for last.
   */
  @Get('bootstrap')
  async bootstrap(@CurrentUser('id') userId: string) {
    const [coverage, indexedVectors, sessions] = await Promise.all([
      this.indexer.coverage(),
      this.search.indexedVectors(),
      this.search.list(userId, 5),
    ]);

    return {
      /// False until the indexer has described something. The client shows an
      /// honest "لسا عم نفهرس" rather than an empty result page.
      ready: indexedVectors > 0,
      engine: this.embeddings.name,
      coverage: {
        indexed_products: coverage.indexedProducts,
        active_products: coverage.activeProducts,
        indexed_images: indexedVectors,
      },
      limits: {
        max_image_bytes:
          this.config.get<number>('visualSearch.maxImageBytes') ?? 8 * 1024 * 1024,
        /// What the client should resample to before uploading. Advertised by
        /// the server so a policy change does not need an app release.
        upload_max_edge: this.config.get<number>('visualSearch.storedWidth') ?? 1024,
        accepted: ['image/jpeg', 'image/png', 'image/webp'],
      },
      privacy: {
        image_retention_hours:
          this.config.get<number>('visualSearch.imageRetentionHours') ?? 24,
        note: 'تُحفظ صورتكِ بشكل خاص وتُمسح تلقائياً بعد انتهاء البحث، وتبقى النتائج دون الصورة.',
      },
      try_on: serializeTryOnCapability(this.tryOn.capability()),
      recent: sessions.map((session) => serializeVisualSession(session)),
      prompts: [
        'نفس هالفستان بس بالأسود',
        'شي مشابه وأقل من 400 ألف',
        'شي أكتر احتشامًا من هيك',
        'نفس الستايل بس بقماش أخف',
      ],
    };
  }

  // ── Search ────────────────────────────────────────────────────────────

  @Throttle({ default: { limit: 12, ttl: 60_000 } })
  @Post('searches')
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(
    FileInterceptor('image', {
      limits: {
        fileSize: Number(process.env.VISUAL_SEARCH_MAX_IMAGE_BYTES ?? 8_388_608),
        files: 1,
      },
    }),
  )
  async startSearch(
    @CurrentUser('id') userId: string,
    @UploadedFile() file: UploadedFileLike | undefined,
    @Req() req: Request,
  ) {
    if (!file) throw new BadRequestException('IMAGE_REQUIRED');

    const source = parseSource(req.body?.source);
    const view = await this.search.search({
      userId,
      bytes: file.buffer,
      source,
      originalName: file.originalname,
    });

    // A sentence typed with the upload runs through the same refinement path a
    // later one does, so there is one behaviour rather than two.
    const note = typeof req.body?.note === 'string' ? req.body.note.trim() : '';
    const finalView = note
      ? await this.search.refine({ userId, sessionId: view.session.id, text: note })
      : view;

    return this.render(userId, finalView);
  }

  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @Post('sessions/:id/refine')
  async refine(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) sessionId: string,
    @Body() dto: RefineVisualSearchDto,
  ) {
    const view = await this.search.refine({ userId, sessionId, text: dto.text });
    return this.render(userId, view);
  }

  @Get('sessions')
  async sessions(
    @CurrentUser('id') userId: string,
    @Query() dto: VisualSessionListDto,
  ) {
    const rows = await this.search.list(userId, dto.limit ?? 20);
    return rows.map((row) => serializeVisualSession(row));
  }

  @Get('sessions/:id')
  async session(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) sessionId: string,
  ) {
    return this.render(userId, await this.search.load(userId, sessionId));
  }

  /** Her own delete: the photograph and the search, gone now. */
  @Delete('sessions/:id')
  async forget(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) sessionId: string,
  ) {
    await this.search.forget(userId, sessionId);
    return { deleted: true };
  }

  /** Every region of a look with its own matches — "تسوّقي الإطلالة". */
  @Get('sessions/:id/look')
  async look(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) sessionId: string,
  ) {
    const groups = await this.recommendations.shopTheLook(userId, sessionId);
    return groups.map((group) => ({
      region_id: group.regionId,
      label: group.label,
      matches: group.matches.map((scored, index) =>
        serializeVisualMatch({ id: `${group.regionId}:${index}`, scored }),
      ),
    }));
  }

  @Post('results/:id/feedback')
  async feedback(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) resultId: string,
    @Body() dto: VisualFeedbackDto,
  ) {
    const row = await this.search.recordFeedback({
      userId,
      resultId,
      feedback: dto.feedback,
    });
    return { id: row.id, feedback: row.feedback };
  }

  // ── Visual recommendation ─────────────────────────────────────────────

  /**
   * "قطع شبيهة" for a product page.
   *
   * Public in the sense that it is about a product rather than about her, but
   * still authenticated like every other route on this controller — the guard
   * is global and there is no reason to carve an exception.
   */
  @Get('products/:id/similar')
  async similar(
    @Param('id', ParseUUIDPipe) productId: string,
    @Query() dto: SimilarProductsDto,
  ) {
    const matches = await this.recommendations.similarTo(productId, {
      limit: dto.limit,
      maxPriceSyp: dto.max_price ?? null,
      sameCategory: dto.same_category ?? false,
    });
    return matches.map((scored, index) =>
      serializeVisualMatch({ id: `${productId}:${index}`, scored }),
    );
  }

  // ── Virtual try-on ────────────────────────────────────────────────────

  @Get('try-on/capability')
  capability() {
    return serializeTryOnCapability(this.tryOn.capability());
  }

  /**
   * Ask to see a garment on her own photograph.
   *
   * With no provider configured this answers 503 with `TRY_ON_UNAVAILABLE` and
   * — importantly — does not accept the photograph at all. Recording a request
   * that cannot be fulfilled would mean storing a picture of her body to
   * satisfy a counter, and no analytics figure is worth that.
   */
  @Throttle({ default: { limit: 6, ttl: 60_000 } })
  @Post('try-on')
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(
    FileInterceptor('image', {
      limits: {
        fileSize: Number(process.env.VISUAL_SEARCH_MAX_IMAGE_BYTES ?? 8_388_608),
        files: 1,
      },
    }),
  )
  async requestTryOn(
    @CurrentUser('id') userId: string,
    @UploadedFile() file: UploadedFileLike | undefined,
    @Body() dto: TryOnRequestDto,
  ) {
    const capability = this.tryOn.capability();
    if (!capability.available) {
      throw new ServiceUnavailableException('TRY_ON_UNAVAILABLE');
    }
    if (!file) throw new BadRequestException('IMAGE_REQUIRED');

    const row = await this.tryOn.request({
      userId,
      productId: dto.product_id,
      variantId: dto.variant_id ?? null,
      offerId: dto.offer_id ?? null,
      sessionId: dto.session_id ?? null,
      consent: dto.consent,
      photo: file.buffer,
      originalName: file.originalname,
    });
    return serializeTryOn(row, {
      resultImageUrl:
        row.status === VisualTryOnStatus.READY && row.resultAssetId
          ? `/media/${row.resultAssetId}/file`
          : null,
    });
  }

  @Get('try-on')
  async tryOns(@CurrentUser('id') userId: string, @Query() dto: VisualSessionListDto) {
    const rows = await this.tryOn.list(userId, dto.limit ?? 20);
    return rows.map((row) =>
      serializeTryOn(row, {
        resultImageUrl: row.resultAssetId ? `/media/${row.resultAssetId}/file` : null,
        sourceImageUrl: row.sourceAssetId ? `/media/${row.sourceAssetId}/file` : null,
      }),
    );
  }

  @Delete('try-on/:id')
  async revokeTryOn(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    const row = await this.tryOn.revoke(userId, id);
    return serializeTryOn(row);
  }

  // ── Rendering ─────────────────────────────────────────────────────────

  private async render(userId: string, view: Awaited<ReturnType<VisualSearchService['load']>>) {
    // The private URL, which only she can fetch — `MediaService.mayRead`
    // refuses `visual_search` to everybody else, including staff.
    const queryImageUrl = view.session.queryAssetId
      ? `/media/${view.session.queryAssetId}/file`
      : null;

    return serializeVisualSession(view.session, {
      attributes: view.attributes,
      brief: view.brief,
      results: view.results,
      notice: view.notice,
      queryImageUrl,
    });
  }
}

/** A source the client claimed, or the safe default. Analytics only. */
function parseSource(value: unknown): VisualSearchSource {
  const candidate = String(value ?? '').toUpperCase();
  return candidate in VisualSearchSource
    ? VisualSearchSource[candidate as keyof typeof VisualSearchSource]
    : VisualSearchSource.GALLERY;
}
