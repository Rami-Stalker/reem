import { Injectable } from '@nestjs/common';
import {
  ValueEvent,
  ValueEventStatus,
  ValuePillar,
  ValueProfile,
  ValueSnapshot,
  ValueTier,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { PillarResult, TierRung } from './kernel/value-facts';
import { nextRungAdvice } from './kernel/value-kernel';
import { BenefitOffer, ValueBenefitService } from './value-benefit.service';
import { ValuePolicyService } from './value-policy.service';
import { ValueScoringService } from './value-scoring.service';

export interface ValueStanding {
  profile: ValueProfile;
  tier: ValueTier | null;
  nextTier: ValueTier | null;
  /** Ladder rungs, for the progress rail. */
  ladder: ValueTier[];
  pillars: PillarResult[];
  /** What would move her, as pillars rather than as a number. */
  advice: Array<{ pillar: ValuePillar; headroom: number; needed: number }>;
  /** Recent confirmed contributions — the "why". */
  recent: ValueEvent[];
  /** Ninety days of standing, for the line. */
  history: ValueSnapshot[];
  benefits: BenefitOffer[];
}

/**
 * The read side.
 *
 * One call assembles everything a woman's standing screen needs, because the
 * alternative on a Syrian mobile connection is six round trips to render one
 * card. Nothing here computes: the profile was written by the scoring service,
 * the benefits by the benefit service, and this only gathers.
 *
 * The shape is chosen to make one thing impossible: showing her a number
 * without showing her what is behind it. `pillars`, `recent` and `advice` are
 * not optional extras on this payload, they are the payload — a standing that
 * arrives as a bare integer is a credit score, and nobody has ever felt valued
 * by one.
 */
@Injectable()
export class ValueService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly policies: ValuePolicyService,
    private readonly scoring: ValueScoringService,
    private readonly benefits: ValueBenefitService,
  ) {}

  async standing(userId: string): Promise<ValueStanding> {
    const profile = await this.scoring.findOrCreate(userId);
    const ladder = await this.policies.tiers();

    const tier = profile.tierKey
      ? (ladder.find((rung) => rung.key === profile.tierKey) ?? null)
      : null;
    const nextTier =
      ladder.find((rung) => rung.rank > (tier?.rank ?? -1)) ?? null;

    const pillars = (profile.pillars as unknown as PillarResult[]) ?? [];

    const [recent, history, benefits] = await Promise.all([
      this.prisma.valueEvent.findMany({
        where: { userId, status: ValueEventStatus.CONFIRMED },
        orderBy: { occurredAt: 'desc' },
        take: 20,
      }),
      this.prisma.valueSnapshot.findMany({
        where: { profileId: profile.id },
        orderBy: { capturedOn: 'desc' },
        take: 90,
      }),
      this.benefits.catalogueFor(userId),
    ]);

    const view = await this.policies.view();
    const nextRung: TierRung | null = nextTier
      ? {
          id: nextTier.id,
          key: nextTier.key,
          name: nextTier.name,
          minScore: nextTier.minScore,
          rank: nextTier.rank,
          demotionBufferScore: nextTier.demotionBufferScore,
          holdDays: nextTier.holdDays,
        }
      : null;

    return {
      profile,
      tier,
      nextTier,
      ladder,
      pillars,
      advice: nextRungAdvice({ score: profile.score, pillars }, view, nextRung),
      recent,
      // Oldest first, so a chart does not have to reverse it.
      history: history.reverse(),
      benefits,
    };
  }

  /**
   * The compact form, for the surfaces that decorate rather than explain — a
   * badge in the app bar, a line on the profile screen.
   */
  async badge(userId: string): Promise<{
    score: number;
    tier_key: string | null;
    tier_name: string | null;
    momentum: number;
    next_tier_name: string | null;
    to_next_tier: number;
  }> {
    const profile = await this.scoring.findOrCreate(userId);
    const ladder = await this.policies.tiers();
    const tier = ladder.find((rung) => rung.key === profile.tierKey) ?? null;
    const next = ladder.find((rung) => rung.rank > (tier?.rank ?? -1)) ?? null;

    // snake_case, like every other payload on the wire. This one endpoint used
    // to answer in camelCase, and the client only survived it by accepting both
    // spellings of every key — which is the sort of accommodation that quietly
    // becomes the contract if nobody fixes the side that is wrong.
    return {
      score: profile.score,
      tier_key: profile.tierKey,
      tier_name: profile.tierName,
      momentum: profile.momentum,
      next_tier_name: next?.nameAr ?? next?.name ?? null,
      to_next_tier: next ? Math.max(0, next.minScore - profile.score) : 0,
    };
  }

  /** Her contributions, paged — the full ledger behind the number. */
  async events(
    userId: string,
    options: { limit?: number; cursor?: string; pillar?: ValuePillar } = {},
  ) {
    const limit = Math.min(options.limit ?? 30, 100);
    const rows = await this.prisma.valueEvent.findMany({
      where: {
        userId,
        // Reversed and expired rows are hers to see: "why did it drop" is a
        // fair question and an absent row is not an answer.
        status: { not: ValueEventStatus.PENDING },
        ...(options.pillar ? { pillar: options.pillar } : {}),
      },
      orderBy: [{ occurredAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(options.cursor ? { cursor: { id: options.cursor }, skip: 1 } : {}),
    });

    return {
      events: rows.slice(0, limit),
      nextCursor: rows.length > limit ? rows[limit - 1].id : null,
    };
  }
}
