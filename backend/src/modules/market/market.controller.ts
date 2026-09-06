import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { BundlesService } from './bundles/bundles.service';
import { DropsService } from './drops/drops.service';
import { MissionsService } from './missions/missions.service';
import { LifecycleService } from './resale/lifecycle.service';
import {
  BundleListDto,
  CreateResaleListingDto,
  MarketListDto,
  ResaleMarketDto,
  ResaleStatusDto,
} from './dto/market.dto';
import {
  serializeBundle,
  serializeBundleAlternatives,
  serializeDrop,
  serializeMission,
  serializeResaleListing,
  serializeWardrobeRow,
} from './market.serializer';

/**
 * What a shopper can reach of Reem Market Evolution.
 *
 * Four surfaces that share one rule: none of them is a feed of things Reem
 * would like her to buy. A drop is addressed to her and says why; a bundle is
 * a solution with a reason per piece; her wardrobe reading is about what she
 * already owns; a mission asks for something worth doing. Nothing here ranks
 * the catalogue, because the catalogue already has a ranker.
 */
@Controller('market')
export class MarketController {
  constructor(
    private readonly drops: DropsService,
    private readonly bundles: BundlesService,
    private readonly lifecycle: LifecycleService,
    private readonly missions: MissionsService,
  ) {}

  // ── Drops ─────────────────────────────────────────────────────────────

  /**
   * The drops open to her right now.
   *
   * `@OptionalAuth` rather than `@Public`: a signed-out visitor sees the open
   * ones, and a signed-in woman additionally sees what she was invited to —
   * which is the whole feature, and would be silently lost under `@Public`.
   */
  @OptionalAuth()
  @Get('drops')
  async openDrops(@CurrentUser('id') userId: string | undefined) {
    const rows = await this.drops.visibleTo(userId ?? null);
    return {
      drops: rows.map((row) =>
        serializeDrop(row.drop, {
          earlyAccessOnly: row.isEarly,
          // Why she is seeing it, carried from the graph all the way to the
          // card. An invitation that cannot explain itself is a blast.
          invite: row.invite
            ? {
                affinity: row.invite.affinity,
                reasons: row.invite.reason,
                openedAt: row.invite.openedAt,
              }
            : null,
        }),
      ),
    };
  }

  /** Recorded once per invitation, which is what makes precision a real rate. */
  @Post('drops/:dropId/opened')
  async openDrop(
    @CurrentUser('id') userId: string,
    @Param('dropId', ParseUUIDPipe) dropId: string,
  ) {
    await this.drops.markOpened(dropId, userId);
    return { ok: true };
  }

  // ── Bundles ───────────────────────────────────────────────────────────

  @OptionalAuth()
  @Get('bundles')
  async listBundles(@Query() query: BundleListDto) {
    const bundles = await this.bundles.list({
      occasion: query.occasion,
      limit: query.limit,
    });
    return { bundles: bundles.map(serializeBundle) };
  }

  @OptionalAuth()
  @Get('bundles/:bundleId')
  async bundle(@Param('bundleId', ParseUUIDPipe) bundleId: string) {
    const bundle = await this.bundles.detail(bundleId);
    return { bundle: serializeBundle(bundle) };
  }

  /** Cheaper ways to fill the same slots, from the graph's substitutes. */
  @OptionalAuth()
  @Get('bundles/:bundleId/alternatives')
  async bundleAlternatives(@Param('bundleId', ParseUUIDPipe) bundleId: string) {
    const alternatives = await this.bundles.alternativesFor(bundleId);
    return { alternatives: serializeBundleAlternatives(alternatives) };
  }

  /**
   * The lines this bundle would put through checkout.
   *
   * Returned rather than ordered: buying is the orders module's job, and this
   * hands it the same shape a room's purchase plan does.
   */
  @Get('bundles/:bundleId/checkout-lines')
  async bundleLines(@Param('bundleId', ParseUUIDPipe) bundleId: string) {
    const { lines, unavailable } = await this.bundles.purchasableLines(bundleId);
    return {
      lines: lines.map((line) => ({
        offer_id: line.offerId,
        offer_variant_id: line.offerVariantId,
        quantity: line.quantity,
      })),
      unavailable_product_ids: unavailable,
    };
  }

  // ── Wardrobe life cycle ───────────────────────────────────────────────

  /** Three numbers about her wardrobe. Not a dashboard. */
  @Get('wardrobe/summary')
  async wardrobeSummary(@CurrentUser('id') userId: string) {
    const summary = await this.lifecycle.summary(userId);
    return {
      items: summary.items,
      in_rotation: summary.inRotation,
      needs_attention: summary.needsAttention,
      worn_share: summary.wornShare,
      median_cost_per_wear_syp: summary.medianCostPerWear,
    };
  }

  /** The short list of pieces that need something. */
  @Get('wardrobe/attention')
  async wardrobeAttention(
    @CurrentUser('id') userId: string,
    @Query() query: MarketListDto,
  ) {
    const rows = await this.lifecycle.attention(userId, query.limit ?? 6);
    return { items: rows.map(serializeWardrobeRow) };
  }

  /** One piece, read on its own. */
  @Get('wardrobe/items/:closetItemId')
  async wardrobeItem(
    @CurrentUser('id') userId: string,
    @Param('closetItemId', ParseUUIDPipe) closetItemId: string,
  ) {
    const row = await this.lifecycle.readItem(userId, closetItemId);
    return { item: serializeWardrobeRow(row) };
  }

  // ── Resale ────────────────────────────────────────────────────────────

  /**
   * Draft a listing for a wardrobe piece.
   *
   * A draft, deliberately: seeing what a dress is worth and offering it to
   * strangers are two decisions, and collapsing them would make the first one
   * dangerous.
   */
  @Post('wardrobe/items/:closetItemId/resale')
  async draftListing(
    @CurrentUser('id') userId: string,
    @Param('closetItemId', ParseUUIDPipe) closetItemId: string,
    @Body() body: CreateResaleListingDto,
  ) {
    const listing = await this.lifecycle.list(userId, closetItemId, {
      condition: body.condition,
      priceSyp: body.price_syp,
      title: body.title,
      note: body.note,
    });
    return { listing: serializeResaleListing(listing) };
  }

  @Patch('resale/:listingId/status')
  async setListingStatus(
    @CurrentUser('id') userId: string,
    @Param('listingId', ParseUUIDPipe) listingId: string,
    @Body() body: ResaleStatusDto,
  ) {
    const listing = await this.lifecycle.setStatus(userId, listingId, body.status);
    return { listing: serializeResaleListing(listing) };
  }

  @Get('resale/mine')
  async myListings(@CurrentUser('id') userId: string) {
    const listings = await this.lifecycle.mine(userId);
    return { listings: listings.map((listing) => serializeResaleListing(listing)) };
  }

  /**
   * The resale market.
   *
   * Its own read path. Nothing here touches product search, which is what
   * keeps the marketplace experience intact.
   */
  @OptionalAuth()
  @Get('resale')
  async resaleMarket(
    @CurrentUser('id') userId: string | undefined,
    @Query() query: ResaleMarketDto,
  ) {
    const rows = await this.lifecycle.market({
      slot: query.slot,
      limit: query.limit,
      viewerId: userId,
    });
    return {
      listings: rows.map((row) =>
        serializeResaleListing(row.listing, row.savingBps),
      ),
    };
  }

  @OptionalAuth()
  @Get('resale/:listingId')
  async resaleDetail(@Param('listingId', ParseUUIDPipe) listingId: string) {
    const listing = await this.lifecycle.detail(listingId);
    return { listing: serializeResaleListing(listing) };
  }

  // ── Missions ──────────────────────────────────────────────────────────

  /** Hers, recomputed from evidence on every read. */
  @Get('missions')
  async myMissions(@CurrentUser('id') userId: string) {
    const rows = await this.missions.mine(userId);
    return { missions: rows.map(serializeMission) };
  }

  /** She can say no, and be believed for sixty days. */
  @Post('missions/:key/decline')
  async declineMission(
    @CurrentUser('id') userId: string,
    @Param('key') key: string,
  ) {
    await this.missions.decline(userId, key);
    return { ok: true };
  }
}
