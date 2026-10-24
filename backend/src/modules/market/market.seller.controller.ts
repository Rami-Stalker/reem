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
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { DropsService } from './drops/drops.service';
import { MarketIntelligenceService } from './intelligence/market-intelligence.service';
import {
  BuildAudienceDto,
  CreateDropDto,
  DropStatusDto,
  MarketListDto,
} from './dto/market.dto';
import {
  serializeDrop,
  serializeDropPerformance,
  serializeOpportunity,
} from './market.serializer';

/**
 * A seller's half of Ohara Market Evolution.
 *
 * Two things she could not do before: turn a listing into an event addressed
 * to the women who would want it, and see what the market around her own
 * catalogue is doing. Both read the graph and the economics layer — neither
 * has a data source of its own, which is what keeps a seller's numbers and the
 * platform's the same numbers.
 */
@Roles(UserRole.SELLER)
@Controller('seller/market')
export class MarketSellerController {
  constructor(
    private readonly drops: DropsService,
    private readonly intelligence: MarketIntelligenceService,
  ) {}

  // ── Drops ─────────────────────────────────────────────────────────────

  /**
   * Her products worth launching.
   *
   * Scored by the economics layer, not by recency: a product nobody wants does
   * not become worth an event by being new.
   */
  @Get('drops/candidates')
  async candidates(
    @CurrentUser('id') sellerId: string,
    @Query() query: MarketListDto,
  ) {
    const candidates = await this.drops.candidates({
      sellerId,
      limit: query.limit ?? 10,
    });
    return {
      candidates: candidates.map((candidate) => ({
        product_id: candidate.productId,
        title: candidate.title,
        potential: Math.round(candidate.potential),
        findings: candidate.findings,
        demand_score: candidate.demandScore,
        stock_units: candidate.stockUnits,
      })),
    };
  }

  @Get('drops')
  async myDrops(@CurrentUser('id') sellerId: string) {
    const drops = await this.drops.forSeller(sellerId);
    return { drops: drops.map((drop) => serializeDrop(drop)) };
  }

  @Post('drops')
  async create(@CurrentUser('id') sellerId: string, @Body() body: CreateDropDto) {
    const drop = await this.drops.create({
      sellerId,
      title: body.title,
      note: body.note ?? null,
      audience: body.audience,
      startsAt: new Date(body.starts_at),
      earlyAccessAt: body.early_access_at ? new Date(body.early_access_at) : null,
      endsAt: body.ends_at ? new Date(body.ends_at) : null,
      productIds: body.product_ids,
    });
    return { drop: serializeDrop(drop) };
  }

  /**
   * Work out who this is for.
   *
   * Separate from creating it on purpose: targeting is re-runnable, and a
   * seller should be able to see the size and shape of the audience before she
   * commits to sending anything.
   */
  @Post('drops/:dropId/audience')
  async buildAudience(
    @CurrentUser('id') sellerId: string,
    @Param('dropId', ParseUUIDPipe) dropId: string,
    @Body() body: BuildAudienceDto,
  ) {
    const result = await this.drops.buildAudience(dropId, {
      limit: body.limit,
      sellerId,
    });
    return {
      invited: result.invited,
      shape: {
        slots: result.shape.slots,
        occasions: result.shape.occasions,
        product_count: result.shape.productCount,
      },
    };
  }

  @Patch('drops/:dropId/status')
  async setStatus(
    @CurrentUser('id') sellerId: string,
    @Param('dropId', ParseUUIDPipe) dropId: string,
    @Body() body: DropStatusDto,
  ) {
    const drop = await this.drops.setStatus(dropId, body.status, sellerId);
    return { drop: serializeDrop(drop) };
  }

  /** How it did — including whether the targeting was the reason. */
  @Get('drops/:dropId/performance')
  async performance(
    @CurrentUser('id') sellerId: string,
    @Param('dropId', ParseUUIDPipe) dropId: string,
  ) {
    const performance = await this.drops.performance(dropId, sellerId);
    return { performance: serializeDropPerformance(performance) };
  }

  // ── Market intelligence ───────────────────────────────────────────────

  /**
   * What the market around her catalogue is doing.
   *
   * Restricted to categories she sells in and products she lists, because an
   * opportunity in a market she has never entered is a business plan and not
   * an opportunity.
   */
  @Get('opportunities')
  async opportunities(
    @CurrentUser('id') sellerId: string,
    @Query() query: MarketListDto,
  ) {
    const opportunities = await this.intelligence.forSeller(
      sellerId,
      query.limit ?? 8,
    );
    return { opportunities: opportunities.map(serializeOpportunity) };
  }
}
