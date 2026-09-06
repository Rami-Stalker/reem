import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ClosetService } from './closet.service';
import { ClosetIntakeService } from './closet-intake.service';
import { ClosetGapService } from './gaps/closet-gap.service';
import { ClosetItemService } from './items/closet-item.service';
import { ClosetLookService } from './looks/closet-look.service';
import { ClosetSuggestionService } from './suggestions/closet-suggestion.service';
import { ClosetTodayService } from './today/today.service';
import {
  AddCatalogItemDto,
  AddPersonalItemDto,
  BackfillDto,
  ClosetItemStatusDto,
  ClosetSettingsDto,
  CreateLookDto,
  GapSuggestionsDto,
  ListClosetItemsDto,
  ListLooksDto,
  LogLookWearDto,
  LogWearDto,
  SetLookItemsDto,
  TodayDto,
  UpdateClosetItemDto,
  UpdateLookDto,
} from './dto/closet.dto';
import {
  serializeCloset,
  serializeClosetItem,
  serializeGap,
  serializeLook,
  serializeOverview,
  serializeSuggestion,
  serializeTodayOutfit,
} from './closet.serializer';
import { OCCASIONS, SLOTS } from '../ai-stylist/understanding/stylist-lexicon';
import { ClosetSeason } from '@prisma/client';
import { seasonLabel } from './closet.serializer';

/**
 * `/closet` — her wardrobe.
 *
 * Every route is authenticated and scoped to the caller. There is no public
 * closet, no shared closet and no seller view of one: a list of the clothes a
 * woman owns, with photographs of them in her home, is the most personal thing
 * this platform stores. Sharing a *look* may one day be worth building; sharing
 * an inventory is not, and the absence of a route is the clearest way to say so.
 *
 * Gaps recompute after every write that could move them rather than on a
 * schedule — see `ClosetGapService.recompute` for why that is affordable.
 */
@Controller('closet')
export class ClosetController {
  constructor(
    private readonly closet: ClosetService,
    private readonly items: ClosetItemService,
    private readonly looks: ClosetLookService,
    private readonly gaps: ClosetGapService,
    private readonly suggestions: ClosetSuggestionService,
    private readonly todayService: ClosetTodayService,
    private readonly intake: ClosetIntakeService,
  ) {}

  // ── Overview ──────────────────────────────────────────────────────────

  /**
   * Everything the closet's front page needs, in one call.
   *
   * A cold open of this tab used to be four round trips on a Syrian mobile
   * connection; the vocabulary in particular never changes between them and has
   * no business being fetched separately.
   */
  @Get()
  async overview(@CurrentUser('id') userId: string) {
    const [overview, gaps] = await Promise.all([
      this.closet.overview(userId),
      this.gaps.list(userId, 4),
    ]);

    return {
      ...serializeOverview(overview),
      gaps: gaps.map(serializeGap),
      // The closed vocabulary the client builds its pickers from, so the app
      // and the engine can never offer different slots or occasions.
      vocabulary: {
        slots: SLOTS.map((entry) => ({ key: entry.slot, label: entry.labelAr })),
        occasions: OCCASIONS.map((entry) => ({ key: entry.key, label: entry.labelAr })),
        seasons: Object.values(ClosetSeason).map((season) => ({
          key: season,
          label: seasonLabel(season),
        })),
      },
    };
  }

  @Patch('settings')
  async updateSettings(
    @CurrentUser('id') userId: string,
    @Body() dto: ClosetSettingsDto,
  ) {
    const closet = await this.closet.updateSettings(userId, {
      autoAddPurchases: dto.auto_add_purchases,
      suggestionsEnabled: dto.suggestions_enabled,
    });
    // Turning suggestions off has to clear what is on screen, not just hide it.
    if (dto.suggestions_enabled !== undefined) await this.gaps.recompute(userId);
    return serializeCloset(closet);
  }

  /**
   * Pull her delivered orders in.
   *
   * Throttled hard: it is a bulk write she can only usefully run once, and it
   * walks her order history to do it.
   */
  @Throttle({ default: { limit: 3, ttl: 3600_000 } })
  @Post('backfill')
  async backfill(@CurrentUser('id') userId: string, @Body() dto: BackfillDto) {
    const added = await this.intake.backfill(userId, dto.limit ?? 40);
    if (added) await this.gaps.recompute(userId);
    return { added };
  }

  // ── Items ─────────────────────────────────────────────────────────────

  @Get('items')
  async listItems(
    @CurrentUser('id') userId: string,
    @Query() dto: ListClosetItemsDto,
  ) {
    const result = await this.items.list(userId, {
      slot: dto.slot,
      status: dto.status,
      season: dto.season,
      occasion: dto.occasion,
      colour: dto.colour,
      favouritesOnly: dto.favourites_only,
      search: dto.search,
      limit: dto.limit,
      cursor: dto.cursor,
    });
    return {
      items: result.items.map(serializeClosetItem),
      next_cursor: result.nextCursor,
    };
  }

  @Get('items/:id')
  async item(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) itemId: string,
  ) {
    const item = await this.items.detail(userId, itemId);
    return item ? serializeClosetItem(item) : null;
  }

  @Post('items/catalog')
  async addCatalogItem(
    @CurrentUser('id') userId: string,
    @Body() dto: AddCatalogItemDto,
  ) {
    const item = await this.items.addFromCatalog(userId, {
      productId: dto.product_id,
      offerId: dto.offer_id,
      variantId: dto.variant_id,
      note: dto.note,
      acquiredAt: dto.acquired_at ? new Date(dto.acquired_at) : null,
      overrides: fromDescriptorDto(dto.descriptor),
    });
    await this.gaps.markFilledBy(item);
    await this.gaps.recompute(userId);
    return serializeClosetItem(item);
  }

  @Post('items/personal')
  async addPersonalItem(
    @CurrentUser('id') userId: string,
    @Body() dto: AddPersonalItemDto,
  ) {
    const item = await this.items.addPersonal(userId, {
      title: dto.title,
      slot: dto.slot,
      imageUrl: dto.image_url,
      brandName: dto.brand_name,
      note: dto.note,
      acquiredAt: dto.acquired_at ? new Date(dto.acquired_at) : null,
      purchasePriceSyp: dto.purchase_price_syp,
      overrides: fromDescriptorDto(dto.descriptor),
    });
    await this.gaps.markFilledBy(item);
    await this.gaps.recompute(userId);
    return serializeClosetItem(item);
  }

  @Patch('items/:id')
  async updateItem(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) itemId: string,
    @Body() dto: UpdateClosetItemDto,
  ) {
    const item = await this.items.update(userId, itemId, {
      title: dto.title,
      imageUrl: dto.image_url,
      brandName: dto.brand_name,
      note: dto.note,
      isFavourite: dto.is_favourite,
      acquiredAt: dto.acquired_at ? new Date(dto.acquired_at) : undefined,
      purchasePriceSyp: dto.purchase_price_syp,
      overrides: fromDescriptorDto(dto.descriptor),
    });
    // A slot or season correction changes what the closet is short of.
    if (dto.descriptor) await this.gaps.recompute(userId);
    return serializeClosetItem(item);
  }

  @Patch('items/:id/status')
  async setItemStatus(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) itemId: string,
    @Body() dto: ClosetItemStatusDto,
  ) {
    const item = await this.items.setStatus(userId, itemId, dto.status);
    await this.gaps.recompute(userId);
    return serializeClosetItem(item);
  }

  @Delete('items/:id')
  async removeItem(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) itemId: string,
  ) {
    await this.items.remove(userId, itemId);
    await this.gaps.recompute(userId);
    return { deleted: true };
  }

  @Post('items/:id/wear')
  async wearItem(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) itemId: string,
    @Body() dto: LogWearDto,
  ) {
    const item = await this.items.logWear(
      userId,
      itemId,
      dto.worn_on ? new Date(dto.worn_on) : undefined,
    );
    return serializeClosetItem(item);
  }

  /**
   * Un-log a wearing.
   *
   * The date arrives in the body rather than the query string. A DELETE with a
   * body is unusual, but the alternative was a bespoke query-carrying delete
   * helper in the shared Flutter datasource base, and a date is data about
   * *what* to delete rather than a filter on a collection.
   */
  @Delete('items/:id/wear')
  async unwearItem(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) itemId: string,
    @Body() dto: LogWearDto,
  ) {
    const item = await this.items.removeWear(
      userId,
      itemId,
      dto.worn_on ? new Date(dto.worn_on) : new Date(),
    );
    return serializeClosetItem(item);
  }

  // ── Looks ─────────────────────────────────────────────────────────────

  @Get('looks')
  async listLooks(@CurrentUser('id') userId: string, @Query() dto: ListLooksDto) {
    const looks = await this.looks.list(userId, {
      occasion: dto.occasion,
      includeArchived: dto.include_archived,
      limit: dto.limit,
    });
    return looks.map(serializeLook);
  }

  @Get('looks/:id')
  async look(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) lookId: string,
  ) {
    return serializeLook(await this.looks.require(userId, lookId));
  }

  @Post('looks')
  async createLook(@CurrentUser('id') userId: string, @Body() dto: CreateLookDto) {
    const look = await this.looks.create(userId, {
      title: dto.title,
      occasion: dto.occasion,
      note: dto.note,
      seasons: dto.seasons,
      items: dto.items?.map(fromLookSlotDto),
    });
    await this.gaps.recompute(userId);
    return serializeLook(look);
  }

  @Patch('looks/:id')
  async updateLook(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) lookId: string,
    @Body() dto: UpdateLookDto,
  ) {
    const look = await this.looks.update(userId, lookId, {
      title: dto.title,
      occasion: dto.occasion,
      note: dto.note,
      seasons: dto.seasons,
      isFavourite: dto.is_favourite,
      isArchived: dto.is_archived,
    });
    await this.gaps.recompute(userId);
    return serializeLook(look);
  }

  @Patch('looks/:id/items')
  async setLookItems(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) lookId: string,
    @Body() dto: SetLookItemsDto,
  ) {
    const look = await this.looks.setItems(userId, lookId, dto.items.map(fromLookSlotDto));
    await this.gaps.recompute(userId);
    return serializeLook(look);
  }

  @Delete('looks/:id')
  async removeLook(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) lookId: string,
  ) {
    await this.looks.remove(userId, lookId);
    await this.gaps.recompute(userId);
    return { deleted: true };
  }

  @Post('looks/:id/wear')
  async wearLook(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) lookId: string,
    @Body() dto: LogLookWearDto,
  ) {
    const look = await this.looks.logWear(userId, lookId, {
      wornOn: dto.worn_on ? new Date(dto.worn_on) : undefined,
      occasionNote: dto.occasion_note,
    });
    return serializeLook(look);
  }

  /** Save a stylist suggestion into her own wardrobe. */
  @Post('looks/from-stylist/:outfitId')
  async promoteOutfit(
    @CurrentUser('id') userId: string,
    @Param('outfitId', ParseUUIDPipe) outfitId: string,
  ) {
    const look = await this.looks.promoteStylistOutfit(userId, outfitId);
    await this.gaps.recompute(userId);
    return serializeLook(look);
  }

  // ── Gaps and suggestions ──────────────────────────────────────────────

  @Get('gaps')
  async listGaps(@CurrentUser('id') userId: string) {
    const gaps = await this.gaps.list(userId);
    return gaps.map(serializeGap);
  }

  /**
   * Recompute now.
   *
   * Wraps the list in an object where `GET /closet/gaps` returns a bare array.
   * The difference is deliberate: this is an action with a result, and the
   * client's shared POST helper decodes an object. A bare array from a POST
   * would need a second helper in the datasource base for one caller.
   */
  @Post('gaps/refresh')
  async refreshGaps(@CurrentUser('id') userId: string) {
    const gaps = await this.gaps.recompute(userId);
    return { gaps: gaps.map(serializeGap) };
  }

  /**
   * What to buy for one gap.
   *
   * The only route in the closet that reaches the catalog, and it does so
   * through the stylist's retrieval and ranker rather than a query of its own —
   * see `ClosetSuggestionService`.
   */
  @Get('gaps/:id/suggestions')
  async gapSuggestions(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) gapId: string,
    @Query() dto: GapSuggestionsDto,
  ) {
    const gap = await this.gaps.require(userId, gapId);
    const suggestions = await this.suggestions.forGap(userId, gap, {
      limit: dto.limit ?? 8,
    });
    return {
      gap: serializeGap(gap),
      suggestions: suggestions.map(serializeSuggestion),
    };
  }

  @Post('gaps/:id/dismiss')
  async dismissGap(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) gapId: string,
  ) {
    return serializeGap(await this.gaps.dismiss(userId, gapId));
  }

  @Post('gaps/:id/restore')
  async restoreGap(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) gapId: string,
  ) {
    return serializeGap(await this.gaps.restore(userId, gapId));
  }

  /**
   * "هل بتناسب خزانتي؟" — asked from a product page.
   *
   * The inverse of a gap: the garment is given and the wardrobe is the unknown.
   * Returns the pieces she owns it would go with and the looks it would finish,
   * which is what turns a listing into a fitting room.
   */
  @Get('pairing/:productId')
  async pairing(
    @CurrentUser('id') userId: string,
    @Param('productId', ParseUUIDPipe) productId: string,
  ) {
    const result = await this.suggestions.pairingFor(userId, productId);
    // A withdrawn product is a 404 rather than a null body: every client here
    // decodes an object, and "no such product" is not a pairing score of zero.
    if (!result) throw new NotFoundException('Product not found');
    return {
      slot: result.slot,
      score: result.score,
      already_owned: result.alreadyOwned,
      completes_look_ids: result.completesLookIds,
      reasons: result.reasons,
      pairs_with_item_ids: result.pairsWith.map((item) => item.id),
    };
  }

  // ── Today ─────────────────────────────────────────────────────────────

  /**
   * "شو بقدر ألبس اليوم؟"
   *
   * Answers from her own clothes first and only mentions the shop when an
   * outfit is genuinely one piece short. A wardrobe assistant that opens with
   * something to buy is an advert wearing a wardrobe's clothes.
   */
  @Get('today')
  async today(@CurrentUser('id') userId: string, @Query() dto: TodayDto) {
    const result = await this.todayService.today(userId, {
      occasion: dto.occasion,
      limit: dto.limit,
    });
    return {
      season: result.season,
      outfits: result.outfits.map(serializeTodayOutfit),
    };
  }
}

// ── Wire → domain ───────────────────────────────────────────────────────

function fromDescriptorDto(dto?: {
  slot?: import('@prisma/client').OutfitSlot;
  colours?: string[];
  materials?: string[];
  modesty?: import('@prisma/client').ModestyLevel;
  seasons?: ClosetSeason[];
  occasions?: string[];
  size?: string;
}) {
  if (!dto) return undefined;
  return {
    slot: dto.slot,
    colours: dto.colours,
    materials: dto.materials,
    modesty: dto.modesty,
    seasons: dto.seasons,
    occasions: dto.occasions,
    size: dto.size,
  };
}

function fromLookSlotDto(dto: {
  slot: import('@prisma/client').OutfitSlot;
  closet_item_id?: string;
  product_id?: string;
  offer_id?: string;
  variant_id?: string;
  note?: string;
}) {
  return {
    slot: dto.slot,
    closetItemId: dto.closet_item_id ?? null,
    productId: dto.product_id ?? null,
    offerId: dto.offer_id ?? null,
    variantId: dto.variant_id ?? null,
    note: dto.note ?? null,
  };
}
