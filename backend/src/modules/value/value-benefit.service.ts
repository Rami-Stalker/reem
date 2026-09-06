import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Prisma,
  ValueBenefit,
  ValueBenefitGrant,
  ValueBenefitKind,
  ValueGrantStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ValuePolicyService } from './value-policy.service';
import { ValueScoringService } from './value-scoring.service';

export interface BenefitOffer {
  benefit: ValueBenefit;
  /** Her standing already opens this. */
  unlocked: boolean;
  /** She holds a live grant for it. */
  grant: ValueBenefitGrant | null;
  /** Set when locked: the rung it opens at. */
  requiresTierKey: string | null;
  /** Set when unlocked but unavailable: `quota`, `budget` or `window`. */
  blockedBy: string | null;
}

/**
 * What standing opens.
 *
 * The rule this service exists to enforce is stated once, here, and nowhere
 * else in the module contradicts it: **taking up a benefit never changes a
 * score.** There is no debit, no cost in standing, no "spend your value on".
 * A woman at the top rung who uses early access twenty times is exactly as
 * highly regarded on the twenty-first day as she was on the first. That is what
 * separates a standing from a balance, and it is why `grantFor` writes to
 * `ValueBenefitGrant` and never touches `ValueProfile`.
 *
 * What *is* bounded is the platform's exposure, and it is bounded at the
 * benefit rather than at the customer: `perUserQuota` limits how often one
 * woman may hold something, `totalBudget` limits how many the programme will
 * ever issue, and `unitCostSyp` lets an administrator see the bill before
 * signing it.
 */
@Injectable()
export class ValueBenefitService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly policies: ValuePolicyService,
    private readonly scoring: ValueScoringService,
  ) {}

  /**
   * Everything in the catalogue, marked as open or not for her.
   *
   * Locked benefits are returned rather than hidden. A programme that shows a
   * woman only what she already has cannot tell her what standing is *for*, and
   * the locked rows are the entire argument for taking part.
   */
  async catalogueFor(userId: string, now = new Date()): Promise<BenefitOffer[]> {
    const profile = await this.scoring.findOrCreate(userId);
    const tiers = await this.policies.tiers();
    const rankByKey = new Map(tiers.map((tier) => [tier.key, tier.rank]));
    const rankById = new Map(tiers.map((tier) => [tier.id, tier.rank]));
    const keyById = new Map(tiers.map((tier) => [tier.id, tier.key]));
    const herRank = profile.tierKey ? (rankByKey.get(profile.tierKey) ?? -1) : -1;

    const benefits = await this.prisma.valueBenefit.findMany({
      where: {
        isActive: true,
        startsAt: { lte: now },
        OR: [{ endsAt: null }, { endsAt: { gt: now } }],
      },
      orderBy: [{ minTierId: 'asc' }, { key: 'asc' }],
    });

    const grants = await this.prisma.valueBenefitGrant.findMany({
      where: {
        profileId: profile.id,
        status: { in: [ValueGrantStatus.OFFERED, ValueGrantStatus.ACTIVE] },
      },
    });
    const grantByBenefit = new Map(grants.map((grant) => [grant.benefitId, grant]));

    const offers: BenefitOffer[] = [];
    for (const benefit of benefits) {
      const required = benefit.minTierId ? (rankById.get(benefit.minTierId) ?? 0) : -1;
      // Her rank, or a grant she is already holding — the same rule
      // `isUnlocked` applies, because the screen that lists her benefits and
      // the gate that enforces them must not disagree. The grants were already
      // being loaded here to attach below; only the flag ignored them, so a
      // woman the platform was genuinely letting through still read «مقفل» on
      // her own standing page.
      const unlocked = herRank >= required || grantByBenefit.has(benefit.id);

      let blockedBy: string | null = null;
      if (unlocked) {
        if (
          benefit.totalBudget !== null &&
          benefit.grantedCount >= benefit.totalBudget
        ) {
          blockedBy = 'budget';
        } else if (await this.quotaExhausted(profile.id, benefit, now)) {
          blockedBy = 'quota';
        }
      }

      offers.push({
        benefit,
        unlocked,
        grant: grantByBenefit.get(benefit.id) ?? null,
        requiresTierKey: unlocked
          ? null
          : benefit.minTierId
            ? (keyById.get(benefit.minTierId) ?? null)
            : null,
        blockedBy,
      });
    }

    return offers;
  }

  /**
   * Whether a benefit is open to her right now — the question every other
   * module asks.
   *
   * Cheap and read-only: checkout asks it for enhanced returns, the catalog
   * asks it for early access, support asks it for queue priority. None of them
   * need a grant row, because a standing benefit is not something she claims —
   * it is something that is true about her.
   */
  async isUnlocked(userId: string, benefitKey: string): Promise<boolean> {
    const benefit = await this.prisma.valueBenefit.findUnique({
      where: { key: benefitKey },
      select: { id: true, isActive: true, minTierId: true, endsAt: true, startsAt: true },
    });
    if (!benefit?.isActive) return false;

    const now = new Date();
    if (benefit.startsAt > now) return false;
    if (benefit.endsAt && benefit.endsAt <= now) return false;
    if (!benefit.minTierId) return true;

    // A grant she already holds settles the question before her tier is asked.
    //
    // Two things depended on this and neither worked without it. An
    // administrator's hand grant wrote a row that nothing downstream ever read,
    // so the gesture changed nothing she could see. And the promise `grant()`
    // makes in its own comment — that a benefit earned at one standing is not
    // taken back when she slips — was not kept, because every reader asked this
    // method and this method asked only where she stands *today*.
    //
    // REVOKED and EXPIRED are excluded: those are the two ways an entitlement
    // is meant to end.
    const held = await this.prisma.valueBenefitGrant.findFirst({
      where: {
        userId,
        benefitId: benefit.id,
        status: {
          in: [
            ValueGrantStatus.OFFERED,
            ValueGrantStatus.ACTIVE,
            ValueGrantStatus.USED,
          ],
        },
        OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
      },
      select: { id: true },
    });
    if (held) return true;

    const profile = await this.prisma.valueProfile.findUnique({
      where: { userId },
      select: { tierKey: true, frozenAt: true },
    });
    if (!profile || profile.frozenAt) return false;

    const tiers = await this.policies.tiers();
    const required = tiers.find((tier) => tier.id === benefit.minTierId)?.rank ?? 0;
    const hers = tiers.find((tier) => tier.key === profile.tierKey)?.rank ?? -1;
    return hers >= required;
  }

  /**
   * The configuration of an unlocked benefit, or null.
   *
   * How the rest of the platform reads a benefit's terms — the extra return
   * days, the early-access window — without knowing what a tier is.
   */
  async configFor(
    userId: string,
    benefitKey: string,
  ): Promise<Record<string, unknown> | null> {
    if (!(await this.isUnlocked(userId, benefitKey))) return null;
    const benefit = await this.prisma.valueBenefit.findUnique({
      where: { key: benefitKey },
      select: { config: true },
    });
    return (benefit?.config as Record<string, unknown> | null) ?? {};
  }

  /**
   * Which benefit kinds she currently holds. One query, for the surfaces that
   * decorate themselves — a badge on the product page, a line in checkout.
   */
  async unlockedKinds(userId: string): Promise<ValueBenefitKind[]> {
    const offers = await this.catalogueFor(userId);
    return [
      ...new Set(
        offers
          .filter((offer) => offer.unlocked && !offer.blockedBy)
          .map((offer) => offer.benefit.kind),
      ),
    ];
  }

  // ── Granting ──────────────────────────────────────────────────────────

  /**
   * Issue a benefit that has to be held rather than merely enjoyed — a gift, a
   * personalised offer.
   *
   * Note again what this does not do: it writes a grant, decrements a budget,
   * and leaves `ValueProfile` untouched. `dedupeKey` makes it safe to call from
   * a scheduler that may run twice.
   *
   * The budget check and the increment happen in one transaction, because two
   * concurrent grants against the last unit of a two-hundred-gift campaign is
   * exactly the race that turns a bounded programme into an unbounded one.
   */
  async grant(
    userId: string,
    benefitKey: string,
    options: { dedupeKey?: string; now?: Date; overrideStanding?: boolean } = {},
  ): Promise<ValueBenefitGrant> {
    const now = options.now ?? new Date();
    const benefit = await this.prisma.valueBenefit.findUnique({
      where: { key: benefitKey },
    });
    if (!benefit) throw new NotFoundException('Benefit not found');

    // `overrideStanding` is what separates an administrator's gesture from a
    // woman claiming what she has earned.
    //
    // Without it the admin route enforced the tier gate too, which made it
    // useless by construction: the only benefits it could hand out were the
    // ones she could already claim herself. Goodwill after a bad order,
    // compensation, a gift to an early tester — every real reason to grant one
    // by hand is a reason to grant it *out* of standing.
    //
    // The budget ceiling below is deliberately NOT overridden. Standing is a
    // judgement an administrator is entitled to make; the money the programme
    // has agreed to spend is not.
    if (!options.overrideStanding && !(await this.isUnlocked(userId, benefitKey))) {
      throw new BadRequestException('This benefit is not open at your standing');
    }

    const profile = await this.scoring.findOrCreate(userId);
    if (await this.quotaExhausted(profile.id, benefit, now)) {
      throw new BadRequestException('You already hold this benefit');
    }

    const dedupeKey = options.dedupeKey ?? `${benefit.key}:${periodKey(now, benefit)}`;

    return this.prisma.$transaction(async (tx) => {
      if (benefit.totalBudget !== null) {
        const fresh = await tx.valueBenefit.findUniqueOrThrow({
          where: { id: benefit.id },
          select: { grantedCount: true, totalBudget: true },
        });
        if (
          fresh.totalBudget !== null &&
          fresh.grantedCount >= fresh.totalBudget
        ) {
          throw new BadRequestException('This benefit has run out');
        }
      }

      const existing = await tx.valueBenefitGrant.findUnique({
        where: { userId_dedupeKey: { userId, dedupeKey } },
      });
      if (existing) return existing;

      const created = await tx.valueBenefitGrant.create({
        data: {
          profileId: profile.id,
          userId,
          benefitId: benefit.id,
          status: ValueGrantStatus.OFFERED,
          // Frozen: a benefit earned at one standing is not withdrawn because
          // she slipped later. The grant records what was true when it was
          // given.
          tierKeyAtGrant: profile.tierKey,
          scoreAtGrant: profile.score,
          dedupeKey,
          expiresAt: benefit.grantTtlDays
            ? new Date(now.getTime() + benefit.grantTtlDays * 86_400_000)
            : null,
        },
      });

      await tx.valueBenefit.update({
        where: { id: benefit.id },
        data: { grantedCount: { increment: 1 } },
      });

      return created;
    });
  }

  /** She has used it. */
  async markUsed(
    userId: string,
    grantId: string,
    usedOn: { type: string; id: string },
  ): Promise<ValueBenefitGrant> {
    const grant = await this.prisma.valueBenefitGrant.findFirst({
      where: { id: grantId, userId },
    });
    if (!grant) throw new NotFoundException('Grant not found');
    if (grant.status === ValueGrantStatus.USED) return grant;

    return this.prisma.valueBenefitGrant.update({
      where: { id: grantId },
      data: {
        status: ValueGrantStatus.USED,
        usedOnType: usedOn.type,
        usedOnId: usedOn.id,
        usedAt: new Date(),
      },
    });
  }

  async revoke(grantId: string, reason: string): Promise<ValueBenefitGrant> {
    return this.prisma.valueBenefitGrant.update({
      where: { id: grantId },
      data: {
        status: ValueGrantStatus.REVOKED,
        revokedAt: new Date(),
        revokedReason: reason,
      },
    });
  }

  /** Retire grants whose window closed. Nightly. */
  async expireStale(now = new Date()): Promise<number> {
    const result = await this.prisma.valueBenefitGrant.updateMany({
      where: {
        status: { in: [ValueGrantStatus.OFFERED, ValueGrantStatus.ACTIVE] },
        expiresAt: { lt: now },
      },
      data: { status: ValueGrantStatus.EXPIRED },
    });
    return result.count;
  }

  private async quotaExhausted(
    profileId: string,
    benefit: Pick<ValueBenefit, 'id' | 'perUserQuota' | 'quotaPeriodDays'>,
    now: Date,
  ): Promise<boolean> {
    if (benefit.perUserQuota === null) return false;
    const since = benefit.quotaPeriodDays
      ? new Date(now.getTime() - benefit.quotaPeriodDays * 86_400_000)
      : undefined;

    const held = await this.prisma.valueBenefitGrant.count({
      where: {
        profileId,
        benefitId: benefit.id,
        // A revoked grant does not count against her: it was taken back, and
        // charging her quota for it would punish her twice.
        status: { not: ValueGrantStatus.REVOKED },
        ...(since ? { createdAt: { gte: since } } : {}),
      },
    });
    return held >= benefit.perUserQuota;
  }
}

/**
 * The window a recurring benefit is granted per.
 *
 * Bucketing by period rather than by timestamp is what makes an automatic grant
 * idempotent: the seasonal gift's key is the same all quarter, so a scheduler
 * that runs nightly issues it once.
 */
function periodKey(
  now: Date,
  benefit: Pick<ValueBenefit, 'quotaPeriodDays'>,
): string {
  if (!benefit.quotaPeriodDays) return 'once';
  const bucket = Math.floor(now.getTime() / (benefit.quotaPeriodDays * 86_400_000));
  return String(bucket);
}
