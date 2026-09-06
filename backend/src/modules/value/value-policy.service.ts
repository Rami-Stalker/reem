import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, ValuePillar, ValuePolicy, ValueTier } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { TierRung, ValuePolicyView } from './kernel/value-facts';
import { spendingAloneCeiling } from './kernel/value-kernel';
import {
  DEFAULT_BENEFITS,
  DEFAULT_COMMERCE_CEILING_BPS,
  DEFAULT_DAILY_PILLAR_CAPS,
  DEFAULT_EVENT_WEIGHTS,
  DEFAULT_HALF_LIFE_DAYS,
  DEFAULT_HORIZON_DAYS,
  DEFAULT_MIN_EVIDENCE_PER_PILLAR,
  DEFAULT_PILLAR_SCALES,
  DEFAULT_PILLAR_WEIGHTS,
  DEFAULT_RELIABILITY_BASELINE,
  DEFAULT_TIERS,
} from './value.constants';

/**
 * The programme's economics, as rows.
 *
 * A policy is versioned and only one is active, for the same reason the COD
 * engine freezes its factors onto an assessment: a standing is only meaningful
 * beside the rules that produced it, and an administrator retuning weights
 * needs to see what the change does to the live population *before* it lands on
 * anybody's profile. `simulate` is that preview, and it is the difference
 * between tuning a programme and guessing at one.
 */
@Injectable()
export class ValuePolicyService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * The active policy, or the seeded one if this installation has none.
   *
   * Seeding on first read rather than in a migration keeps the defaults in
   * TypeScript where they are commented, and means a fresh database is usable
   * without a separate step.
   */
  async active(): Promise<ValuePolicy> {
    const existing = await this.prisma.valuePolicy.findFirst({
      where: { isActive: true },
      orderBy: { version: 'desc' },
    });
    if (existing) return existing;
    return this.seed();
  }

  /** The active policy flattened into what the kernel consumes. */
  async view(policy?: ValuePolicy): Promise<ValuePolicyView> {
    const row = policy ?? (await this.active());
    return {
      pillarWeights: row.pillarWeights as Record<ValuePillar, number>,
      pillarScales: row.pillarScales as Record<ValuePillar, number>,
      dailyPillarCaps: row.dailyPillarCaps as Record<ValuePillar, number>,
      halfLifeDays: row.halfLifeDays,
      horizonDays: row.horizonDays,
      commerceCeilingBps: row.commerceCeilingBps,
      reliabilityBaseline: row.reliabilityBaseline,
      minEvidencePerPillar: row.minEvidencePerPillar,
    };
  }

  /** What one contribution is worth today. */
  async weightFor(code: string): Promise<number> {
    const policy = await this.active();
    const weights = policy.eventWeights as Record<string, number>;
    return weights[code] ?? DEFAULT_EVENT_WEIGHTS[code] ?? 0;
  }

  async tiers(): Promise<ValueTier[]> {
    const rows = await this.prisma.valueTier.findMany({
      where: { isActive: true },
      orderBy: { rank: 'asc' },
    });
    if (rows.length) return rows;
    await this.seedTiers();
    return this.prisma.valueTier.findMany({
      where: { isActive: true },
      orderBy: { rank: 'asc' },
    });
  }

  /** The ladder in the shape `resolveTier` takes. */
  async ladder(): Promise<TierRung[]> {
    const tiers = await this.tiers();
    return tiers.map((tier) => ({
      id: tier.id,
      key: tier.key,
      name: tier.name,
      minScore: tier.minScore,
      rank: tier.rank,
      demotionBufferScore: tier.demotionBufferScore,
      holdDays: tier.holdDays,
    }));
  }

  // ── Seeding ───────────────────────────────────────────────────────────

  async seed(): Promise<ValuePolicy> {
    await this.seedTiers();
    await this.seedBenefits();

    const existing = await this.prisma.valuePolicy.findUnique({
      where: { version: 1 },
    });
    if (existing) return existing;

    return this.prisma.valuePolicy.create({
      data: {
        version: 1,
        isActive: true,
        pillarWeights: DEFAULT_PILLAR_WEIGHTS as unknown as Prisma.InputJsonValue,
        pillarScales: DEFAULT_PILLAR_SCALES as unknown as Prisma.InputJsonValue,
        eventWeights: DEFAULT_EVENT_WEIGHTS as unknown as Prisma.InputJsonValue,
        dailyPillarCaps: DEFAULT_DAILY_PILLAR_CAPS as unknown as Prisma.InputJsonValue,
        halfLifeDays: DEFAULT_HALF_LIFE_DAYS,
        horizonDays: DEFAULT_HORIZON_DAYS,
        commerceCeilingBps: DEFAULT_COMMERCE_CEILING_BPS,
        reliabilityBaseline: DEFAULT_RELIABILITY_BASELINE,
        minEvidencePerPillar: DEFAULT_MIN_EVIDENCE_PER_PILLAR,
        note: 'Seeded from value.constants.ts',
        activatedAt: new Date(),
      },
    });
  }

  private async seedTiers(): Promise<void> {
    for (const tier of DEFAULT_TIERS) {
      await this.prisma.valueTier.upsert({
        where: { key: tier.key },
        create: {
          key: tier.key,
          name: tier.name,
          nameAr: tier.nameAr,
          minScore: tier.minScore,
          rank: tier.rank,
          demotionBufferScore: tier.demotionBufferScore,
          holdDays: tier.holdDays,
          presentation: tier.presentation as unknown as Prisma.InputJsonValue,
        },
        // Upsert rather than create-if-missing: a re-seed must not overwrite a
        // ladder an administrator has retuned.
        update: {},
      });
    }
  }

  private async seedBenefits(): Promise<void> {
    const tiers = await this.prisma.valueTier.findMany({ select: { id: true, key: true } });
    const byKey = new Map(tiers.map((tier) => [tier.key, tier.id]));

    for (const benefit of DEFAULT_BENEFITS) {
      await this.prisma.valueBenefit.upsert({
        where: { key: benefit.key },
        create: {
          key: benefit.key,
          kind: benefit.kind,
          title: benefit.title,
          titleAr: benefit.titleAr,
          descriptionAr: benefit.descriptionAr,
          minTierId: byKey.get(benefit.minTierKey) ?? null,
          config: benefit.config as unknown as Prisma.InputJsonValue,
          perUserQuota: benefit.perUserQuota,
          quotaPeriodDays: benefit.quotaPeriodDays,
          totalBudget: benefit.totalBudget,
          unitCostSyp: benefit.unitCostSyp,
          grantTtlDays: benefit.grantTtlDays,
        },
        update: {},
      });
    }
  }

  // ── Administration ────────────────────────────────────────────────────

  /**
   * Write a new version. Never active on creation — activation is a separate,
   * deliberate act, so a half-finished edit cannot reach anybody's profile.
   */
  async draft(
    input: Partial<{
      pillarWeights: Record<string, number>;
      pillarScales: Record<string, number>;
      eventWeights: Record<string, number>;
      dailyPillarCaps: Record<string, number>;
      halfLifeDays: number;
      horizonDays: number;
      commerceCeilingBps: number;
      reliabilityBaseline: number;
      minEvidencePerPillar: number;
      note: string;
    }>,
    createdById?: string,
  ): Promise<ValuePolicy> {
    const current = await this.active();
    const latest = await this.prisma.valuePolicy.findFirst({
      orderBy: { version: 'desc' },
      select: { version: true },
    });

    return this.prisma.valuePolicy.create({
      data: {
        version: (latest?.version ?? 0) + 1,
        isActive: false,
        pillarWeights: (input.pillarWeights ??
          current.pillarWeights) as Prisma.InputJsonValue,
        pillarScales: (input.pillarScales ??
          current.pillarScales) as Prisma.InputJsonValue,
        eventWeights: (input.eventWeights ??
          current.eventWeights) as Prisma.InputJsonValue,
        dailyPillarCaps: (input.dailyPillarCaps ??
          current.dailyPillarCaps) as Prisma.InputJsonValue,
        halfLifeDays: input.halfLifeDays ?? current.halfLifeDays,
        horizonDays: input.horizonDays ?? current.horizonDays,
        commerceCeilingBps: input.commerceCeilingBps ?? current.commerceCeilingBps,
        reliabilityBaseline: input.reliabilityBaseline ?? current.reliabilityBaseline,
        minEvidencePerPillar:
          input.minEvidencePerPillar ?? current.minEvidencePerPillar,
        note: input.note ?? null,
        createdById: createdById ?? null,
      },
    });
  }

  async activate(policyId: string): Promise<ValuePolicy> {
    const policy = await this.prisma.valuePolicy.findUnique({ where: { id: policyId } });
    if (!policy) throw new NotFoundException('Policy not found');

    return this.prisma.$transaction(async (tx) => {
      await tx.valuePolicy.updateMany({
        where: { isActive: true },
        data: { isActive: false },
      });
      return tx.valuePolicy.update({
        where: { id: policyId },
        data: { isActive: true, activatedAt: new Date() },
      });
    });
  }

  async list(): Promise<ValuePolicy[]> {
    return this.prisma.valuePolicy.findMany({ orderBy: { version: 'desc' }, take: 20 });
  }

  /**
   * The guarantee, checked.
   *
   * Returns the highest standing reachable by spending alone against the rung
   * ladder, so the admin screen can say plainly whether money can still buy the
   * top of the programme. A policy that fails this is not rejected — an
   * administrator may have a reason — but it is never allowed to be silent.
   */
  async guarantee(policy?: ValuePolicy): Promise<{
    spendingCeiling: number;
    highestRungReachableBySpending: string | null;
    topRung: string | null;
    holds: boolean;
  }> {
    const view = await this.view(policy);
    const ceiling = spendingAloneCeiling(view);
    const ladder = await this.ladder();
    const sorted = [...ladder].sort((a, b) => a.rank - b.rank);

    const reachable = [...sorted].reverse().find((rung) => ceiling >= rung.minScore);
    const top = sorted[sorted.length - 1];

    return {
      spendingCeiling: ceiling,
      highestRungReachableBySpending: reachable?.key ?? null,
      topRung: top?.key ?? null,
      // The programme's promise: money must not reach the upper half of the
      // ladder on its own.
      holds: !!top && (!reachable || reachable.rank < top.rank - 1),
    };
  }
}
