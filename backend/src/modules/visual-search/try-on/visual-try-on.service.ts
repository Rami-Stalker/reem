import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  MediaType,
  MediaVisibility,
  VisualTryOnStatus,
} from '@prisma/client';
import {
  PRODUCT_CARD_INCLUDE,
  PURCHASABLE_PRODUCT_WHERE,
  defaultOffer,
} from '../../../common/catalog/product-include';
import { PrismaService } from '../../../prisma/prisma.service';
import { MediaService } from '../../media/media.service';
import { CatalogImageService } from '../processing/catalog-image.service';
import { ImageProcessingService } from '../processing/image-processing.service';
import { TRY_ON_PROVIDER, TryOnProvider } from './try-on-provider';

export interface TryOnCapability {
  available: boolean;
  provider: string;
  /** Why not, in Arabic, when it is off. */
  message: string | null;
  retentionHours: number;
}

/**
 * Virtual try-on: the whole feature except the renderer.
 *
 * Read `try-on-provider.ts` for why the renderer is absent. What this service
 * does is make the absence *safe and complete* rather than a gap:
 *
 *  - A request is a **row**, always, including when it cannot be fulfilled.
 *    That is what makes "how many women asked for this" answerable before
 *    anyone spends money on a provider, and what makes the retention clock
 *    apply to the photograph she uploaded even though nothing rendered.
 *  - **Consent is per request** and is recorded with a timestamp. There is no
 *    profile switch that quietly authorises the next one.
 *  - The photograph is stored `PRIVATE` under purpose `try_on`, which
 *    `MediaService.mayRead` refuses to *everyone* but its owner — no support,
 *    no moderation, no administrator.
 *  - The retention clock is the shortest in the schema and is enforced by a
 *    sweeper that deletes bytes, not by a flag that hides them.
 *
 * With a provider configured the same method runs the render and stores the
 * result the same way. Nothing about the shape changes.
 */
@Injectable()
export class VisualTryOnService {
  private readonly logger = new Logger(VisualTryOnService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly processing: ImageProcessingService,
    private readonly media: MediaService,
    private readonly catalogImages: CatalogImageService,
    @Inject(TRY_ON_PROVIDER) private readonly provider: TryOnProvider,
  ) {}

  private get retentionHours(): number {
    return this.config.get<number>('visualSearch.tryOnRetentionHours') ?? 2;
  }

  capability(): TryOnCapability {
    return {
      available: this.provider.enabled,
      provider: this.provider.name,
      message: this.provider.enabled
        ? null
        : 'التجربة الافتراضية لسا مو متوفرة. لما تتوفر، رح نطلب إذنك قبل ما نستخدم صورتك.',
      retentionHours: this.retentionHours,
    };
  }

  /**
   * Ask to see a garment on her own photograph.
   *
   * Consent is checked before the bytes are even decoded: an unconsented
   * request must not cause a photograph of a person to be written to disk,
   * even briefly.
   */
  async request(input: {
    userId: string;
    productId: string;
    variantId?: string | null;
    offerId?: string | null;
    sessionId?: string | null;
    consent: boolean;
    photo: Buffer;
    originalName?: string;
  }) {
    if (!input.consent) throw new BadRequestException('TRY_ON_CONSENT_REQUIRED');

    const product = await this.prisma.product.findFirst({
      where: { id: input.productId, ...PURCHASABLE_PRODUCT_WHERE },
      include: PRODUCT_CARD_INCLUDE,
    });
    if (!product) throw new NotFoundException('PRODUCT_NOT_FOUND');

    const prepared = await this.processing.prepare(input.photo);
    const asset = await this.media.upload(input.userId, {
      buffer: prepared.buffer,
      originalName: input.originalName,
      visibility: MediaVisibility.PRIVATE,
      purpose: 'try_on',
      allowedKinds: [MediaType.image],
    });
    await this.media.markAttached(input.userId, [`/media/${asset.id}/file`]);

    const expiresAt = new Date(Date.now() + this.retentionHours * 3600_000);
    const row = await this.prisma.visualTryOnRequest.create({
      data: {
        userId: input.userId,
        sessionId: input.sessionId ?? null,
        productId: product.id,
        variantId: input.variantId ?? null,
        offerId: input.offerId ?? defaultOffer(product)?.id ?? null,
        sourceAssetId: asset.id,
        provider: this.provider.name,
        status: VisualTryOnStatus.UNAVAILABLE,
        failureCode: 'NO_PROVIDER',
        consentAt: new Date(),
        expiresAt,
      },
    });

    if (!this.provider.enabled) {
      // The honest terminal state. Her photograph is on the shortest clock in
      // the schema and will be deleted whether or not she ever comes back.
      return row;
    }

    return this.render(row.id, product, prepared.buffer);
  }

  /**
   * Hands one request to the provider.
   *
   * Only reachable with a provider configured. Isolated from `request` so a
   * retry, or a worker draining a queue, uses the same code as the first
   * attempt.
   */
  private async render(
    requestId: string,
    product: Awaited<ReturnType<VisualTryOnService['loadProduct']>>,
    person: Buffer,
  ) {
    await this.prisma.visualTryOnRequest.update({
      where: { id: requestId },
      data: { status: VisualTryOnStatus.PROCESSING, failureCode: null },
    });

    const garmentUrl = product.media[0]?.url;
    const garment = garmentUrl ? await this.catalogImages.read(garmentUrl) : null;
    if (!garment) {
      return this.fail(requestId, 'GARMENT_IMAGE_UNAVAILABLE');
    }

    let result;
    try {
      result = await this.provider.render({
        person,
        personMimeType: 'image/webp',
        garment,
        garmentMimeType: 'image/webp',
        garment_hint: {
          categorySlug: product.category.slug,
          slot: null,
          title: product.title,
        },
      });
    } catch (error) {
      this.logger.warn(`Try-on provider threw: ${String(error)}`);
      return this.fail(requestId, 'PROVIDER_ERROR');
    }

    if (result.status === 'FAILED') return this.fail(requestId, result.code);
    if (result.status === 'PROCESSING') {
      return this.prisma.visualTryOnRequest.findUniqueOrThrow({ where: { id: requestId } });
    }

    const row = await this.prisma.visualTryOnRequest.findUniqueOrThrow({
      where: { id: requestId },
    });
    const asset = await this.media.upload(row.userId, {
      buffer: result.image,
      visibility: MediaVisibility.PRIVATE,
      purpose: 'try_on',
      allowedKinds: [MediaType.image],
    });
    await this.media.markAttached(row.userId, [`/media/${asset.id}/file`]);

    return this.prisma.visualTryOnRequest.update({
      where: { id: requestId },
      data: {
        status: VisualTryOnStatus.READY,
        resultAssetId: asset.id,
        failureCode: null,
      },
    });
  }

  private async fail(requestId: string, code: string) {
    return this.prisma.visualTryOnRequest.update({
      where: { id: requestId },
      data: { status: VisualTryOnStatus.FAILED, failureCode: code },
    });
  }

  private async loadProduct(productId: string) {
    return this.prisma.product.findFirstOrThrow({
      where: { id: productId },
      include: PRODUCT_CARD_INCLUDE,
    });
  }

  async list(userId: string, limit = 20) {
    return this.prisma.visualTryOnRequest.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: Math.min(50, Math.max(1, limit)),
      include: { product: { include: PRODUCT_CARD_INCLUDE } },
    });
  }

  async find(userId: string, id: string) {
    const row = await this.prisma.visualTryOnRequest.findFirst({
      where: { id, userId },
      include: { product: { include: PRODUCT_CARD_INCLUDE } },
    });
    if (!row) throw new NotFoundException('TRY_ON_NOT_FOUND');
    return row;
  }

  /**
   * She withdraws consent.
   *
   * Deletes both photographs immediately and marks the row `REVOKED` rather
   * than deleting it: the record that a request existed and was withdrawn is
   * the thing an audit needs, and it carries no image once this has run.
   */
  async revoke(userId: string, id: string) {
    const row = await this.find(userId, id);

    if (row.sourceAssetId) await this.media.purge(row.sourceAssetId);
    if (row.resultAssetId) await this.media.purge(row.resultAssetId);

    return this.prisma.visualTryOnRequest.update({
      where: { id: row.id },
      data: {
        status: VisualTryOnStatus.REVOKED,
        sourceAssetId: null,
        resultAssetId: null,
        expiresAt: new Date(),
      },
    });
  }
}
