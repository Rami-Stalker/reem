import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { ValueBenefitService } from './value-benefit.service';
import { ValueCollectorService } from './value-collector.service';
import { ValuePolicyService } from './value-policy.service';
import { ValueScoringService } from './value-scoring.service';
import { ValueAdminService } from './value.admin.service';
import { ValueService } from './value.service';
import {
  ClaimBenefitDto,
  DraftPolicyDto,
  FreezeProfileDto,
  GrantBenefitDto,
  SimulatePolicyDto,
  UpsertValueBenefitDto,
  UseGrantDto,
  ValueEventsDto,
} from './dto/value.dto';
import {
  serializeAdminBenefit,
  serializeBenefitOffer,
  serializeStanding,
  serializeValueEvent,
} from './value.serializer';
import { EARNING_RULES } from './value.constants';

/**
 * `/value` — her standing.
 *
 * Every route is authenticated and scoped to the caller, and there is no route
 * anywhere that increases a standing on request. Contributions are discovered
 * from evidence by `ValueCollectorService`; nothing a client can send moves a
 * number. That is not an oversight to be filled in later — a status that can be
 * asked for is a status that can be manufactured.
 */
@SelfScoped(
  "her standing, her badge, her event ledger and her benefit grants are every one read for the caller's own user id",
)
@Controller('value')
export class ValueController {
  constructor(
    private readonly value: ValueService,
    private readonly benefits: ValueBenefitService,
    private readonly policies: ValuePolicyService,
  ) {}

  /** Everything her standing screen needs, in one call. */
  @Get()
  async standing(@CurrentUser('id') userId: string) {
    return serializeStanding(await this.value.standing(userId));
  }

  /** The compact form, for badges and headers. */
  @Get('badge')
  async badge(@CurrentUser('id') userId: string) {
    return this.value.badge(userId);
  }

  /** The ledger behind the number, paged. */
  @Get('events')
  async events(@CurrentUser('id') userId: string, @Query() dto: ValueEventsDto) {
    const result = await this.value.events(userId, {
      limit: dto.limit,
      cursor: dto.cursor,
      pillar: dto.pillar,
    });
    return {
      events: result.events.map(serializeValueEvent),
      next_cursor: result.nextCursor,
    };
  }

  /**
   * How standing is earned, published.
   *
   * A programme whose rules are secret is a programme nobody can trust or
   * plan around. The whole earning table goes out — every rule, its pillar, and
   * what evidence it needs — because a woman who can read the rules is a woman
   * who can decide whether she cares about them.
   */
  @Get('rules')
  async rules() {
    const weights = await this.policies.active();
    const table = weights.eventWeights as Record<string, number>;
    return {
      rules: EARNING_RULES.map((rule) => ({
        code: rule.code,
        pillar: rule.pillar,
        label: rule.labelAr,
        evidence: rule.evidenceAr,
        weight: table[rule.code] ?? rule.weight,
      })),
    };
  }

  @Get('benefits')
  async catalogue(@CurrentUser('id') userId: string) {
    const offers = await this.benefits.catalogueFor(userId);
    return offers.map(serializeBenefitOffer);
  }

  /**
   * Take up a benefit her standing already opened.
   *
   * The only write a customer has in this module, and it costs her nothing —
   * see the note on `ValueBenefitGrant`. "Claim" rather than "redeem", and the
   * difference is not decoration: nothing is spent.
   */
  @Post('benefits/claim')
  @HttpCode(HttpStatus.CREATED)
  async claim(@CurrentUser('id') userId: string, @Body() dto: ClaimBenefitDto) {
    const grant = await this.benefits.grant(userId, dto.benefit_key);
    return { id: grant.id, status: grant.status, expires_at: grant.expiresAt };
  }

  @Post('benefits/grants/:id/use')
  async useGrant(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) grantId: string,
    @Body() dto: UseGrantDto,
  ) {
    const grant = await this.benefits.markUsed(userId, grantId, {
      type: dto.used_on_type,
      id: dto.used_on_id,
    });
    return { id: grant.id, status: grant.status };
  }
}

/**
 * `/admin/value` — running the programme.
 *
 * Split from the customer controller rather than guarded route by route, so
 * that adding an administrative capability cannot accidentally land on an
 * unguarded path.
 */
@Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
@Controller('admin/value')
export class ValueAdminController {
  constructor(
    private readonly admin: ValueAdminService,
    private readonly policies: ValuePolicyService,
    private readonly scoring: ValueScoringService,
    private readonly collector: ValueCollectorService,
    private readonly benefits: ValueBenefitService,
  ) {}

  /**
   * The ladder, the population on it, and whether money can climb it.
   *
   * The guarantee ships with the distribution deliberately: nobody should be
   * able to look at the tier spread without also seeing what a pure spender can
   * reach.
   */
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  @Get('distribution')
  distribution() {
    return this.admin.distribution();
  }

  @Get('cost')
  cost() {
    return this.admin.projectedCost();
  }

  @Get('grants')
  grants() {
    return this.admin.grantSummary();
  }

  /** Unusual shapes, for a person to look at. Never an automatic penalty. */
  @Get('suspects')
  suspects() {
    return this.admin.suspects();
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  @Get('profiles/:userId')
  inspect(@Param('userId', ParseUUIDPipe) userId: string) {
    return this.admin.inspect(userId);
  }

  @Post('profiles/:userId/freeze')
  freeze(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() dto: FreezeProfileDto,
  ) {
    return this.admin.freeze(userId, dto.reason);
  }

  @Post('profiles/:userId/unfreeze')
  unfreeze(@Param('userId', ParseUUIDPipe) userId: string) {
    return this.admin.unfreeze(userId);
  }

  // ── Policy ────────────────────────────────────────────────────────────

  @Get('policies')
  policies_() {
    return this.policies.list();
  }

  /** A draft is never active. Activation is a separate, deliberate act. */
  @Post('policies')
  @HttpCode(HttpStatus.CREATED)
  draft(@CurrentUser('id') adminId: string, @Body() dto: DraftPolicyDto) {
    return this.policies.draft(
      {
        pillarWeights: dto.pillar_weights,
        pillarScales: dto.pillar_scales,
        eventWeights: dto.event_weights,
        dailyPillarCaps: dto.daily_pillar_caps,
        halfLifeDays: dto.half_life_days,
        horizonDays: dto.horizon_days,
        commerceCeilingBps: dto.commerce_ceiling_bps,
        reliabilityBaseline: dto.reliability_baseline,
        minEvidencePerPillar: dto.min_evidence_per_pillar,
        note: dto.note,
      },
      adminId,
    );
  }

  /**
   * What a draft would do to the live population, without touching anyone.
   *
   * The reason policies are versioned rather than edited. An administrator
   * raising a weight sees how many women change rung *before* it happens.
   */
  @Post('policies/:id/simulate')
  simulate(
    @Param('id', ParseUUIDPipe) policyId: string,
    @Body() dto: SimulatePolicyDto,
  ) {
    return this.scoring.simulate(policyId, { sample: dto.sample });
  }

  @Post('policies/:id/activate')
  async activate(@Param('id', ParseUUIDPipe) policyId: string) {
    const policy = await this.policies.activate(policyId);
    // Everybody is rescored against the new rules straight away. Leaving the
    // population on yesterday's policy until the nightly sweep would mean the
    // ladder and the profiles disagreeing for a day.
    const recomputed = await this.scoring.recomputeAll();
    return { policy, recomputed, guarantee: await this.policies.guarantee(policy) };
  }

  // ── Benefits ──────────────────────────────────────────────────────────

  @Get('benefits')
  async listBenefits() {
    const rows = await this.admin.listBenefits();
    return rows.map(serializeAdminBenefit);
  }

  @Post('benefits')
  @HttpCode(HttpStatus.CREATED)
  async upsertBenefit(@Body() dto: UpsertValueBenefitDto) {
    const benefit = await this.admin.upsertBenefit({
      key: dto.key,
      kind: dto.kind,
      title: dto.title,
      titleAr: dto.title_ar,
      descriptionAr: dto.description_ar,
      minTierKey: dto.min_tier_key ?? null,
      config: dto.config,
      perUserQuota: dto.per_user_quota ?? null,
      quotaPeriodDays: dto.quota_period_days ?? null,
      totalBudget: dto.total_budget ?? null,
      unitCostSyp: dto.unit_cost_syp,
      grantTtlDays: dto.grant_ttl_days ?? null,
      isActive: dto.is_active,
    });
    return serializeAdminBenefit(benefit);
  }

  /** Hand a benefit to one woman directly — a goodwill gesture, with a record. */
  @Post('benefits/grant')
  @HttpCode(HttpStatus.CREATED)
  grantDirect(@Body() dto: GrantBenefitDto) {
    return this.benefits.grant(dto.user_id, dto.benefit_key, {
      dedupeKey: `admin:${dto.benefit_key}:${Date.now()}`,
      // A hand grant is discretionary by definition — see `grant`.
      overrideStanding: true,
    });
  }

  // ── Operations ────────────────────────────────────────────────────────

  /** Run the collector now, rather than waiting for the schedule. */
  @Post('sweep')
  sweep() {
    return this.collector.sweep();
  }

  @Post('recompute')
  async recompute() {
    return { recomputed: await this.scoring.recomputeAll() };
  }
}
