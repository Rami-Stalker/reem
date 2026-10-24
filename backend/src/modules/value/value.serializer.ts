import {
  ValueBenefit,
  ValueEvent,
  ValuePillar,
  ValueProfile,
  ValueSnapshot,
  ValueTier,
} from '@prisma/client';
import { Money } from '../../common/money';
import { PillarResult } from './kernel/value-facts';
import { BenefitOffer } from './value-benefit.service';
import { ValueStanding } from './value.service';
import { EARNING_RULE_BY_CODE } from './value.constants';

/**
 * The wire shape of Ohara Value.
 *
 * One rule governs this file: **a number never travels without its reason.** A
 * pillar goes out with its evidence count and the label of what it measures; an
 * event goes out with the rule that produced it and the counts behind it; a
 * locked benefit goes out with the rung that would open it. A payload that
 * carried only `score: 640` would render a credit rating, and nobody has ever
 * felt they had standing because of an integer.
 *
 * All Arabic lives here and in `value.constants.ts`. The kernel deals in codes
 * so that the sentence she reads is a rendering of the arithmetic that fired
 * rather than a second opinion about it — the same contract the stylist's
 * reason codes and the closet's gap headlines keep.
 */

const PILLAR_LABELS: Record<ValuePillar, { label: string; blurb: string }> = {
  COMMERCE: {
    label: 'شراء',
    blurb: 'طلبات وصلتكِ واحتفظتِ بها.',
  },
  CRAFT: {
    label: 'رأي',
    blurb: 'تقييماتكِ التي استفادت منها غيركِ.',
  },
  COMMUNITY: {
    label: 'مجتمع',
    blurb: 'منشوراتكِ وتعليقاتكِ التي تفاعلت معها النساء.',
  },
  ADVOCACY: {
    label: 'دعوة',
    blurb: 'من دعوتِهن فأصبحن جزءاً من أوهارا.',
  },
  DISCOVERY: {
    label: 'اكتشاف',
    blurb: 'قطع ومتاجر اكتشفتِها قبل غيركِ.',
  },
  RELIABILITY: {
    label: 'التزام',
    blurb: 'تعاملكِ عند الاستلام وفي المشكلات.',
  },
};

export function serializePillar(pillar: PillarResult) {
  const meta = PILLAR_LABELS[pillar.pillar];
  return {
    pillar: pillar.pillar,
    label: meta.label,
    blurb: meta.blurb,
    score: pillar.score,
    contribution: pillar.contribution,
    events: pillar.events,
    /**
     * `insufficient` is a first-class state on the wire, not a zero.
     * "لسا ما منعرف" and "ضعيف" are different things to be told, and the
     * client renders them differently.
     */
    evidence: pillar.evidence,
    capped: pillar.capped ?? false,
  };
}

export function serializeTier(tier: ValueTier) {
  return {
    key: tier.key,
    name: tier.nameAr,
    name_en: tier.name,
    min_score: tier.minScore,
    rank: tier.rank,
    presentation: tier.presentation,
  };
}

export function serializeValueEvent(event: ValueEvent) {
  const rule = EARNING_RULE_BY_CODE.get(event.code);
  return {
    id: event.id,
    pillar: event.pillar,
    pillar_label: PILLAR_LABELS[event.pillar].label,
    code: event.code,
    /// What she did, in her own language — never the raw code.
    label: rule?.labelAr ?? event.code,
    /// Why it counted, so "ليش ما انحسب" has an answer on the same screen.
    evidence_note: rule?.evidenceAr ?? null,
    status: event.status,
    weight: event.weight,
    evidence: event.evidence,
    occurred_at: event.occurredAt.toISOString(),
    reversed_reason: event.reversedReason,
  };
}

export function serializeBenefitOffer(offer: BenefitOffer) {
  const { benefit, grant } = offer;
  return {
    key: benefit.key,
    kind: benefit.kind,
    title: benefit.titleAr,
    description: benefit.descriptionAr,
    config: benefit.config,
    unlocked: offer.unlocked,
    /// The rung that would open it. The single most motivating field here, and
    /// the reason locked benefits are shown rather than hidden.
    requires_tier: offer.requiresTierKey,
    blocked_by: offer.blockedBy,
    grant: grant
      ? {
          id: grant.id,
          status: grant.status,
          expires_at: grant.expiresAt?.toISOString() ?? null,
        }
      : null,
  };
}

export function serializeStanding(standing: ValueStanding) {
  const { profile, tier, nextTier } = standing;

  return {
    score: profile.score,
    /**
     * Shipped beside the score and never instead of it. A woman whose standing
     * dipped has still stood where she stood, and a programme that only ever
     * shows the current number is a programme that punishes a quiet season.
     */
    peak_score: profile.peakScore,
    momentum: profile.momentum,
    tier: tier ? serializeTier(tier) : null,
    next_tier: nextTier ? serializeTier(nextTier) : null,
    to_next_tier: nextTier ? Math.max(0, nextTier.minScore - profile.score) : 0,
    tier_achieved_at: profile.tierAchievedAt?.toISOString() ?? null,
    /// Set while a rung is being held despite a fall — she is told, rather than
    /// silently protected and then surprised.
    tier_held_until: profile.tierHeldUntil?.toISOString() ?? null,
    frozen: profile.frozenAt !== null,

    ladder: standing.ladder.map(serializeTier),
    pillars: standing.pillars.map(serializePillar),

    /**
     * The next rung as things to do, not as points to collect.
     *
     * `nextRungAdvice` returns the pillars with the most headroom, and the
     * client renders them as sentences. "٦٠ نقطة للموثوقة" is a points system
     * talking; "تقييم واحد مفيد، وصديقة وحدة بتطلب" is a relationship talking.
     */
    advice: standing.advice.map((entry) => ({
      pillar: entry.pillar,
      label: PILLAR_LABELS[entry.pillar].label,
      blurb: PILLAR_LABELS[entry.pillar].blurb,
      headroom: entry.headroom,
    })),

    recent: standing.recent.map(serializeValueEvent),
    history: standing.history.map(serializeSnapshot),
    benefits: standing.benefits.map(serializeBenefitOffer),
  };
}

export function serializeSnapshot(snapshot: ValueSnapshot) {
  return {
    date: snapshot.capturedOn.toISOString().slice(0, 10),
    score: snapshot.score,
    tier: snapshot.tierKey,
  };
}

export function serializeAdminBenefit(benefit: ValueBenefit) {
  return {
    id: benefit.id,
    key: benefit.key,
    kind: benefit.kind,
    title: benefit.title,
    title_ar: benefit.titleAr,
    description_ar: benefit.descriptionAr,
    min_tier_id: benefit.minTierId,
    config: benefit.config,
    per_user_quota: benefit.perUserQuota,
    quota_period_days: benefit.quotaPeriodDays,
    total_budget: benefit.totalBudget,
    granted_count: benefit.grantedCount,
    unit_cost: Money.of(benefit.unitCostSyp, 'SYP').toJSON(),
    grant_ttl_days: benefit.grantTtlDays,
    is_active: benefit.isActive,
    starts_at: benefit.startsAt.toISOString(),
    ends_at: benefit.endsAt?.toISOString() ?? null,
  };
}

export function serializeProfileBadge(profile: ValueProfile) {
  return {
    score: profile.score,
    tier_key: profile.tierKey,
    tier_name: profile.tierName,
    momentum: profile.momentum,
  };
}
