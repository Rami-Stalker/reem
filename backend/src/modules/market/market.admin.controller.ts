import { Controller, Get, Post, Query } from '@nestjs/common';
import { MarketFinding, MarketSubject, UserRole } from '@prisma/client';
import { Roles } from '../../common/decorators/roles.decorator';
import { MarketEconomicsService } from './economics/market-economics.service';
import { MarketIntelligenceService } from './intelligence/market-intelligence.service';
import { BundlesService } from './bundles/bundles.service';
import { MissionsService } from './missions/missions.service';
import { MarketListDto } from './dto/market.dto';
import { serializeOpportunity } from './market.serializer';

/**
 * The platform's view of its own market.
 *
 * Deliberately narrow: `trends/admin/*` already answers what is rising, what
 * is searched for and not found, how prices are moving and how sellers are
 * performing. What was missing — and all that is here — is supply read against
 * demand, and the recruiting decisions that follow from it.
 */
@Roles(UserRole.ADMIN)
@Controller('admin/market')
export class MarketAdminController {
  constructor(
    private readonly economics: MarketEconomicsService,
    private readonly intelligence: MarketIntelligenceService,
    private readonly bundles: BundlesService,
    private readonly missions: MissionsService,
  ) {}

  /** Where the market is short of supply, and where it is not. */
  @Get('opportunities')
  async opportunities(@Query() query: MarketListDto) {
    const opportunities = await this.intelligence.platform(query.limit ?? 12);
    return { opportunities: opportunities.map(serializeOpportunity) };
  }

  /**
   * The raw readings behind those sentences.
   *
   * Here so a claim on the opportunities screen can be checked against the
   * arithmetic that produced it rather than taken on trust.
   */
  @Get('signals')
  async signals(
    @Query('subject') subject?: string,
    @Query('finding') finding?: string,
    @Query('limit') limit?: string,
  ) {
    const subjectType =
      subject === 'PRODUCT' ? MarketSubject.PRODUCT : MarketSubject.CATEGORY;
    const code =
      finding && finding in MarketFinding
        ? (finding as MarketFinding)
        : MarketFinding.SUPPLY_GAP;

    const rows = await this.economics.withFinding(
      subjectType,
      code,
      Math.min(50, Math.max(1, Number(limit) || 20)),
    );

    return {
      signals: rows.map((row) => ({
        subject_type: row.signal.subjectType,
        subject_id: row.signal.subjectId,
        day: row.signal.day.toISOString().slice(0, 10),
        demand_score: row.signal.demandScore,
        supply_score: row.signal.supplyScore,
        conversion_score: row.signal.conversionScore,
        competition: row.signal.competition,
        tension: row.signal.tension,
        price_index_bps: row.signal.priceIndexBps,
        confidence: row.signal.confidence,
        finding: {
          code: row.finding.code,
          strength: row.finding.strength,
          evidence: row.finding.evidence,
        },
      })),
    };
  }

  /**
   * Re-run the sweep by hand.
   *
   * The scheduler runs it nightly; this exists because a change to the kernel
   * that cannot be seen until tomorrow is a change nobody will make.
   */
  @Post('sweep')
  async sweep() {
    const result = await this.economics.sweep();
    return {
      categories: result.categories,
      products: result.products,
      findings: result.findings,
    };
  }

  /** Rebuild the bundle catalogue on demand. */
  @Post('bundles/rebuild')
  async rebuildBundles() {
    return this.bundles.build();
  }

  /** Reinstall the mission catalogue. Idempotent. */
  @Post('missions/seed')
  async seedMissions() {
    return { missions: await this.missions.seed() };
  }
}
