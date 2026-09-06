import { Injectable, Logger } from '@nestjs/common';
import {
  Prisma,
  ValueEventStatus,
  ValuePolicy,
  ValueProfile,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ValueContribution } from './kernel/value-facts';
import { resolveTier, scoreValue } from './kernel/value-kernel';
import { ValuePolicyService } from './value-policy.service';

/**
 * Folding events into standing.
 *
 * The seam between the pure kernel and the database, and it has one job: read
 * her confirmed contributions, hand them to the kernel, and write down what
 * came back. Everything interesting happens in `value-kernel.ts`; everything
 * here is plumbing, deliberately, because the moment a scoring decision leaks
 * into this file it stops being testable without a database.
 *
 * `ValueProfile` is a cache. Every number on it is recomputable from
 * `ValueEvent` plus the active policy, which is what makes a policy change safe
 * to simulate against the whole population and safe to roll back.
 */
@Injectable()
export class ValueScoringService {
  private readonly logger = new Logger(ValueScoringService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly policies: ValuePolicyService,
  ) {}

  /** Her profile, created empty on first touch. */
  async findOrCreate(userId: string): Promise<ValueProfile> {
    try {
      return await this.prisma.valueProfile.upsert({
        where: { userId },
        create: { userId, pillars: [] as unknown as Prisma.InputJsonValue },
        update: {},
      });
    } catch (error) {
      // The same race the closet hits: `upsert` is not atomic against a
      // concurrent insert of the same row, and this profile is opened from
      // several places at once — the standing screen reads it while the
      // benefit catalogue does. The loser's row is the row it wanted.
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        return this.prisma.valueProfile.findUniqueOrThrow({ where: { userId } });
      }
      throw error;
    }
  }

  /**
   * Recompute one woman's standing.
   *
   * Called after any sweep that touched her events, and nightly. Cheap: one
   * indexed read of her confirmed events and one write.
   *
   * A frozen profile is read but never written. Freezing exists so an
   * administrator can stop a standing moving while it is investigated, and a
   * recompute that quietly overwrote a frozen profile would defeat it.
   */
  async recompute(
    userId: string,
    options: { now?: Date; policy?: ValuePolicy } = {},
  ): Promise<ValueProfile> {
    const now = options.now ?? new Date();
    const profile = await this.findOrCreate(userId);
    if (profile.frozenAt) return profile;

    const policy = options.policy ?? (await this.policies.active());
    const view = await this.policies.view(policy);

    const events = await this.prisma.valueEvent.findMany({
      where: { profileId: profile.id, status: ValueEventStatus.CONFIRMED },
      select: { pillar: true, code: true, weight: true, occurredAt: true },
      orderBy: { occurredAt: 'desc' },
      // Bounded: the horizon retires anything older, and beyond a few thousand
      // events decay has made the tail worth nothing measurable.
      take: 5000,
    });

    const contributions: ValueContribution[] = events.map((event) => ({
      pillar: event.pillar,
      code: event.code,
      weight: event.weight,
      occurredAt: event.occurredAt,
    }));

    const score = scoreValue(contributions, view, now);
    const ladder = await this.policies.ladder();
    const decision = resolveTier(
      score.score,
      ladder,
      {
        tierKey: profile.tierKey,
        tierAchievedAt: profile.tierAchievedAt,
        tierHeldUntil: profile.tierHeldUntil,
      },
      now,
    );

    const tierRow = decision.tier
      ? await this.prisma.valueTier.findUnique({ where: { key: decision.tier.key } })
      : null;

    const momentum = await this.momentumFor(profile.id, score.score, now);
    const movedTier = decision.movement === 'promoted' || decision.movement === 'demoted';

    const updated = await this.prisma.valueProfile.update({
      where: { id: profile.id },
      data: {
        score: score.score,
        pillars: score.pillars as unknown as Prisma.InputJsonValue,
        tierId: tierRow?.id ?? null,
        tierKey: tierRow?.key ?? null,
        tierName: tierRow?.nameAr ?? tierRow?.name ?? null,
        // Only stamped when the rung actually changed, so "since March" on her
        // card means since she reached it rather than since the last sweep.
        ...(movedTier ? { tierAchievedAt: now } : {}),
        tierHeldUntil: decision.heldUntil ?? profile.tierHeldUntil,
        momentum,
        policyId: policy.id,
        computedAt: now,
        // The high-water mark never falls. A relationship that dipped is not a
        // relationship that never happened.
        ...(score.score > profile.peakScore
          ? { peakScore: score.score, peakAchievedAt: now }
          : {}),
      },
    });

    await this.snapshot(profile.id, updated, now);
    return updated;
  }

  /**
   * Score today minus score thirty days ago.
   *
   * Read from `ValueSnapshot` rather than recomputed, because "what was she a
   * month ago" is a question about the past under the *policy of the time*, and
   * re-deriving it under today's policy would answer a different one.
   */
  private async momentumFor(
    profileId: string,
    score: number,
    now: Date,
  ): Promise<number> {
    const then = new Date(now.getTime() - 30 * 86_400_000);
    const past = await this.prisma.valueSnapshot.findFirst({
      where: { profileId, capturedOn: { lte: then } },
      orderBy: { capturedOn: 'desc' },
      select: { score: true },
    });
    // No history yet is momentum of zero, not momentum of her whole score —
    // a new profile has not "risen", it has just started.
    return past ? score - past.score : 0;
  }

  private async snapshot(
    profileId: string,
    profile: ValueProfile,
    now: Date,
  ): Promise<void> {
    const capturedOn = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
    );
    await this.prisma.valueSnapshot.upsert({
      where: { profileId_capturedOn: { profileId, capturedOn } },
      create: {
        profileId,
        capturedOn,
        score: profile.score,
        pillars: profile.pillars as Prisma.InputJsonValue,
        tierKey: profile.tierKey,
      },
      // One row per day: the last recompute of the day wins, which is the
      // figure she went to bed with.
      update: {
        score: profile.score,
        pillars: profile.pillars as Prisma.InputJsonValue,
        tierKey: profile.tierKey,
      },
    });
  }

  /**
   * Recompute everybody. Nightly, and after a policy activation.
   *
   * Batched rather than one transaction: a failure halfway through leaves the
   * profiles it reached correct and the rest stale, which the next run fixes.
   * Wrapping the population in one transaction would make the whole programme
   * hostage to a single bad row.
   */
  async recomputeAll(options: { batchSize?: number; now?: Date } = {}): Promise<number> {
    const batchSize = options.batchSize ?? 200;
    const policy = await this.policies.active();
    let cursor: string | undefined;
    let done = 0;

    for (;;) {
      const batch = await this.prisma.valueProfile.findMany({
        where: { frozenAt: null },
        select: { userId: true, id: true },
        orderBy: { id: 'asc' },
        take: batchSize,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      });
      if (!batch.length) break;

      for (const profile of batch) {
        try {
          await this.recompute(profile.userId, { policy, now: options.now });
          done += 1;
        } catch (error) {
          this.logger.warn(
            `Value recompute failed for ${profile.userId}: ${String(error)}`,
          );
        }
      }
      cursor = batch[batch.length - 1].id;
    }

    return done;
  }

  /**
   * What a candidate policy would do to the live population, without touching
   * anybody.
   *
   * The reason `ValuePolicy` is versioned. An administrator raising CRAFT's
   * weight can see how many women change rung before it happens, rather than
   * finding out from support.
   */
  async simulate(
    policyId: string,
    options: { sample?: number; now?: Date } = {},
  ): Promise<{
    sampled: number;
    movedUp: number;
    movedDown: number;
    unchanged: number;
    tierCounts: Record<string, number>;
    averageScoreDelta: number;
  }> {
    const now = options.now ?? new Date();
    const candidate = await this.prisma.valuePolicy.findUniqueOrThrow({
      where: { id: policyId },
    });
    const view = await this.policies.view(candidate);
    const ladder = await this.policies.ladder();
    const rankByKey = new Map(ladder.map((rung) => [rung.key, rung.rank]));

    const profiles = await this.prisma.valueProfile.findMany({
      where: { frozenAt: null },
      select: { id: true, score: true, tierKey: true, tierAchievedAt: true, tierHeldUntil: true },
      take: options.sample ?? 500,
      orderBy: { score: 'desc' },
    });

    let movedUp = 0;
    let movedDown = 0;
    let unchanged = 0;
    let deltaTotal = 0;
    const tierCounts: Record<string, number> = {};

    for (const profile of profiles) {
      const events = await this.prisma.valueEvent.findMany({
        where: { profileId: profile.id, status: ValueEventStatus.CONFIRMED },
        select: { pillar: true, code: true, weight: true, occurredAt: true },
        take: 5000,
      });
      const score = scoreValue(events, view, now);
      const decision = resolveTier(
        score.score,
        ladder,
        {
          tierKey: profile.tierKey,
          tierAchievedAt: profile.tierAchievedAt,
          tierHeldUntil: profile.tierHeldUntil,
        },
        now,
      );

      deltaTotal += score.score - profile.score;
      const key = decision.tier?.key ?? 'none';
      tierCounts[key] = (tierCounts[key] ?? 0) + 1;

      const before = rankByKey.get(profile.tierKey ?? '') ?? -1;
      const after = decision.tier ? decision.tier.rank : -1;
      if (after > before) movedUp += 1;
      else if (after < before) movedDown += 1;
      else unchanged += 1;
    }

    return {
      sampled: profiles.length,
      movedUp,
      movedDown,
      unchanged,
      tierCounts,
      averageScoreDelta: profiles.length
        ? Math.round((deltaTotal / profiles.length) * 100) / 100
        : 0,
    };
  }
}
