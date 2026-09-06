import { Injectable, NotFoundException } from '@nestjs/common';
import {
  Prisma,
  ValueBenefit,
  ValueBenefitKind,
  ValueEventStatus,
  ValueGrantStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money } from '../../common/money';
import { ValuePolicyService } from './value-policy.service';
import { ValueScoringService } from './value-scoring.service';

/**
 * Running the programme.
 *
 * Three questions an administrator has to be able to answer, and each maps to
 * one method here:
 *
 *  - **Where does everybody stand?** `distribution`. A ladder whose top rung
 *    holds nobody is decoration; one that holds a third of the population is
 *    not a standing.
 *  - **What does it cost?** `projectedCost`. Every benefit carries a unit cost
 *    and a budget, so the bill is arithmetic rather than a surprise.
 *  - **Is anyone gaming it?** `suspects`. Not an accusation — a list of
 *    profiles whose contribution shape is unusual enough to look at, with the
 *    freeze switch beside it.
 */
@Injectable()
export class ValueAdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly policies: ValuePolicyService,
    private readonly scoring: ValueScoringService,
  ) {}

  /** How the population sits across the ladder. */
  async distribution() {
    const tiers = await this.policies.tiers();
    const grouped = await this.prisma.valueProfile.groupBy({
      by: ['tierKey'],
      _count: { _all: true },
      _avg: { score: true },
    });

    const byKey = new Map(
      grouped.map((row) => [row.tierKey ?? 'none', row]),
    );
    const total = grouped.reduce((sum, row) => sum + row._count._all, 0);

    const guarantee = await this.policies.guarantee();

    return {
      total,
      tiers: tiers.map((tier) => {
        const row = byKey.get(tier.key);
        const count = row?._count._all ?? 0;
        return {
          key: tier.key,
          name: tier.nameAr,
          minScore: tier.minScore,
          count,
          shareBps: total ? Math.round((count / total) * 10_000) : 0,
          averageScore: Math.round(row?._avg.score ?? 0),
        };
      }),
      unranked: byKey.get('none')?._count._all ?? 0,
      // Shipped with the distribution rather than on its own screen, so nobody
      // can look at the ladder without seeing whether money can climb it.
      guarantee,
    };
  }

  /**
   * What the benefit catalogue is committed to.
   *
   * `issued` is money already promised; `remaining` is the most the programme
   * can still spend if every budget is exhausted. The pair is the answer to
   * "what is our exposure", and it is why `totalBudget` is a required decision
   * on any benefit that costs anything.
   */
  async projectedCost() {
    const benefits = await this.prisma.valueBenefit.findMany({
      where: { isActive: true },
      orderBy: { key: 'asc' },
    });

    let issuedTotal = 0;
    let ceilingTotal = 0;

    const rows = benefits.map((benefit) => {
      const unit = Number(benefit.unitCostSyp);
      const issued = unit * benefit.grantedCount;
      // An unbudgeted benefit that costs nothing is genuinely unbounded and
      // genuinely free; an unbudgeted one that costs money is a hole, and the
      // null here is what makes it visible on the screen.
      const ceiling =
        benefit.totalBudget === null
          ? unit === 0
            ? 0
            : null
          : unit * benefit.totalBudget;

      issuedTotal += issued;
      if (ceiling !== null) ceilingTotal += ceiling;

      return {
        key: benefit.key,
        kind: benefit.kind,
        title: benefit.titleAr,
        unitCost: Money.of(benefit.unitCostSyp, 'SYP').toJSON(),
        granted: benefit.grantedCount,
        budget: benefit.totalBudget,
        issued: Money.of(String(issued), 'SYP').toJSON(),
        ceiling:
          ceiling === null ? null : Money.of(String(ceiling), 'SYP').toJSON(),
        unbounded: benefit.totalBudget === null && unit > 0,
      };
    });

    return {
      benefits: rows,
      issuedTotal: Money.of(String(issuedTotal), 'SYP').toJSON(),
      ceilingTotal: Money.of(String(ceilingTotal), 'SYP').toJSON(),
      /** Benefits that cost money and have no budget. Should be empty. */
      unboundedCount: rows.filter((row) => row.unbounded).length,
    };
  }

  /**
   * Profiles worth a look.
   *
   * Deliberately not called "fraud". These are shapes, not verdicts: a standing
   * built almost entirely out of one pillar, or one that climbed unusually fast,
   * or one whose contributions cluster into very few days. Each is explainable
   * innocently — a prolific reviewer really does look like this — which is
   * exactly why the output is a queue for a person rather than an automatic
   * penalty.
   */
  async suspects(limit = 25) {
    const profiles = await this.prisma.valueProfile.findMany({
      where: { frozenAt: null, score: { gt: 100 } },
      orderBy: { score: 'desc' },
      take: 400,
      select: { id: true, userId: true, score: true, pillars: true, tierKey: true },
    });

    const flagged: Array<{
      userId: string;
      score: number;
      tierKey: string | null;
      reasons: string[];
      concentration: number;
      distinctDays: number;
    }> = [];

    for (const profile of profiles) {
      const pillars =
        (profile.pillars as unknown as Array<{ pillar: string; contribution: number }>) ??
        [];
      const total = pillars.reduce((sum, p) => sum + Math.max(0, p.contribution), 0);
      const top = pillars.reduce(
        (best, p) => Math.max(best, Math.max(0, p.contribution)),
        0,
      );
      const concentration = total > 0 ? top / total : 0;

      const days = await this.prisma.valueEvent.findMany({
        where: { profileId: profile.id, status: ValueEventStatus.CONFIRMED },
        select: { occurredAt: true },
        take: 500,
      });
      const distinctDays = new Set(
        days.map((event) => event.occurredAt.toISOString().slice(0, 10)),
      ).size;

      const reasons: string[] = [];
      // Nine tenths of a standing from one pillar. Possible honestly; worth a
      // glance.
      if (concentration > 0.9 && total > 200) reasons.push('single_pillar');
      // A lot of contribution compressed into very few days.
      if (days.length >= 20 && distinctDays <= 3) reasons.push('burst');
      if (!reasons.length) continue;

      flagged.push({
        userId: profile.userId,
        score: profile.score,
        tierKey: profile.tierKey,
        reasons,
        concentration: Math.round(concentration * 100) / 100,
        distinctDays,
      });
    }

    return flagged.slice(0, limit);
  }

  /**
   * Stop a standing moving while somebody looks at it.
   *
   * Freezing is not a penalty and deletes nothing: events stop accruing,
   * benefits stop being granted, and the profile keeps every number it had. The
   * reversible version of a punishment is the only kind an automated system
   * should be able to apply on suspicion.
   */
  async freeze(userId: string, reason: string) {
    return this.prisma.valueProfile.update({
      where: { userId },
      data: { frozenAt: new Date(), frozenReason: reason },
    });
  }

  async unfreeze(userId: string) {
    const profile = await this.prisma.valueProfile.update({
      where: { userId },
      data: { frozenAt: null, frozenReason: null },
    });
    // Recompute immediately: she has been standing still while frozen, and the
    // next sweep may be hours away.
    return this.scoring.recompute(profile.userId);
  }

  /** One woman's standing, for a support agent answering "why". */
  async inspect(userId: string) {
    const profile = await this.prisma.valueProfile.findUnique({
      where: { userId },
      include: { tier: true, policy: true },
    });
    if (!profile) throw new NotFoundException('No standing for this account');

    const [events, grants] = await Promise.all([
      this.prisma.valueEvent.findMany({
        where: { profileId: profile.id },
        orderBy: { occurredAt: 'desc' },
        take: 100,
      }),
      this.prisma.valueBenefitGrant.findMany({
        where: { profileId: profile.id },
        include: { benefit: true },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
    ]);

    return { profile, events, grants };
  }

  // ── Benefit administration ────────────────────────────────────────────

  async listBenefits(): Promise<ValueBenefit[]> {
    return this.prisma.valueBenefit.findMany({ orderBy: { key: 'asc' } });
  }

  async upsertBenefit(input: {
    key: string;
    kind: ValueBenefitKind;
    title: string;
    titleAr: string;
    descriptionAr?: string;
    minTierKey?: string | null;
    config?: Record<string, unknown>;
    perUserQuota?: number | null;
    quotaPeriodDays?: number | null;
    totalBudget?: number | null;
    unitCostSyp?: number;
    grantTtlDays?: number | null;
    isActive?: boolean;
    endsAt?: Date | null;
  }): Promise<ValueBenefit> {
    const minTier = input.minTierKey
      ? await this.prisma.valueTier.findUnique({ where: { key: input.minTierKey } })
      : null;

    const data = {
      kind: input.kind,
      title: input.title,
      titleAr: input.titleAr,
      descriptionAr: input.descriptionAr ?? null,
      minTierId: minTier?.id ?? null,
      config: (input.config ?? {}) as Prisma.InputJsonValue,
      perUserQuota: input.perUserQuota ?? null,
      quotaPeriodDays: input.quotaPeriodDays ?? null,
      totalBudget: input.totalBudget ?? null,
      unitCostSyp: input.unitCostSyp ?? 0,
      grantTtlDays: input.grantTtlDays ?? null,
      isActive: input.isActive ?? true,
      endsAt: input.endsAt ?? null,
    };

    return this.prisma.valueBenefit.upsert({
      where: { key: input.key },
      create: { key: input.key, ...data },
      update: data,
    });
  }

  /** Grants outstanding, so a campaign can be watched while it runs. */
  async grantSummary() {
    const grouped = await this.prisma.valueBenefitGrant.groupBy({
      by: ['status'],
      _count: { _all: true },
    });
    return Object.fromEntries(
      grouped.map((row) => [row.status, row._count._all]),
    ) as Record<ValueGrantStatus, number>;
  }
}
