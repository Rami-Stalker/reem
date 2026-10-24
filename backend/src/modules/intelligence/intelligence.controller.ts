import {
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { GraphQueryService } from '../graph/graph-query.service';
import { SellerOpportunityService } from './seller-opportunity.service';
import { ShopperIntelligenceService } from './shopper-intelligence.service';
import { SizeFitService } from './size-fit.service';

/**
 * The intelligence a screen can ask for.
 *
 * Deliberately small. Most of phase three does not surface through routes of
 * its own — it makes the endpoints that already exist better, which is the
 * difference between intelligence *in* the product and an AI screen bolted
 * beside it.
 *
 * What is here is what has no existing home: the notes about a product for a
 * given shopper, and the two questions a seller could not previously ask.
 */
@Controller('intelligence')
export class IntelligenceController {
  constructor(
    private readonly shopper: ShopperIntelligenceService,
    private readonly seller: SellerOpportunityService,
    private readonly graph: GraphQueryService,
    private readonly fit: SizeFitService,
  ) {}

  /**
   * What Ohara has to say about this product, to whoever is asking.
   *
   * `@OptionalAuth`, not `@Public`. The difference is the whole endpoint: a
   * public route skips authentication altogether, so `req.user` is never
   * resolved even when the caller *did* send a token — which meant every
   * signed-in shopper silently got the signed-out answer, an empty list. The
   * page still works without a token; it just gets nothing personal, which is
   * correct.
   */
  @OptionalAuth()
  @Get('products/:productId/notes')
  async notes(
    @CurrentUser('id') userId: string | undefined,
    @Param('productId', ParseUUIDPipe) productId: string,
  ) {
    const verdicts = await this.shopper.verdicts(userId ?? null, productId);
    return {
      notes: verdicts.map((verdict) => ({
        code: verdict.code,
        tone: verdict.tone,
        ar: verdict.ar,
        evidence: verdict.evidence,
      })),
    };
  }

  /**
   * How often each size of this product was kept.
   *
   * The same for everyone, so it needs no token — but `@OptionalAuth` like
   * its neighbours, so a signed-in caller is not treated differently by
   * accident if this ever becomes personal ("in your size"). Only rates leave
   * here, never unit counts, and a size with too few sales reports `null`.
   */
  @OptionalAuth()
  @Get('products/:productId/fit')
  async sizeFit(@Param('productId', ParseUUIDPipe) productId: string) {
    const sizes = await this.fit.forProduct(productId);
    return {
      sizes: sizes.map((fit) => ({ size: fit.size, kept_rate: fit.keptRate })),
    };
  }

  /** What goes with this, and what is like it. */
  @OptionalAuth()
  @Get('products/:productId/related')
  async related(
    @Param('productId', ParseUUIDPipe) productId: string,
    @Query('limit') limit?: string,
  ) {
    const take = Math.min(20, Math.max(1, Number(limit) || 10));
    const [similar, complements, substitutes] = await Promise.all([
      this.graph.similar(productId, take),
      this.graph.complements(productId, take),
      this.graph.substitutes(productId, 5),
    ]);
    return {
      similar_ids: similar,
      complement_ids: complements,
      substitute_ids: substitutes,
    };
  }

  // ── Seller ─────────────────────────────────────────────────────────────

  /** Who would want this listing. Counts only, never identities. */
  @Roles(UserRole.SELLER)
  @Get('seller/products/:productId/audience')
  async audience(
    @CurrentUser('id') sellerId: string,
    @Param('productId', ParseUUIDPipe) productId: string,
  ) {
    const audience = await this.seller.audience(sellerId, productId);
    if (!audience) return { audience: null };
    return { audience };
  }

  /** Pairs from her catalogue that already sell together. */
  @Roles(UserRole.SELLER)
  @Get('seller/bundles')
  async bundles(@CurrentUser('id') sellerId: string) {
    return { bundles: await this.seller.bundles(sellerId) };
  }

  /** Demand next to her catalogue that nobody is serving. */
  @Roles(UserRole.SELLER)
  @Get('seller/unserved')
  async unserved(@CurrentUser('id') sellerId: string) {
    return { needs: await this.seller.unservedNeeds(sellerId) };
  }
}
