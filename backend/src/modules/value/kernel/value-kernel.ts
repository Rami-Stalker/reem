import { ValuePillar } from '@prisma/client';
import {
  PillarResult,
  StandingState,
  TierDecision,
  TierRung,
  ValueContribution,
  ValuePolicyView,
  ValueScore,
} from './value-facts';

/**
 * Standing.
 *
 * One pure function turns a woman's confirmed contributions and the active
 * policy into a number between 0 and 1000, the six pillar scores that add up to
 * it, and the evidence behind each. Nothing here reads a database and nothing
 * here asks a model — which is the only reason a standing can be defended when
 * she asks why her sister is a rung above her.
 *
 * Four properties are enforced by the arithmetic rather than by intention, and
 * each is a reason this is not a points balance:
 *
 *  - **Concavity.** A pillar saturates, so the fiftieth review is worth a
 *    fraction of the fifth. Volume cannot substitute for breadth.
 *  - **Decay.** Every contribution is discounted by its age. Standing is what
 *    the relationship is, not what it once was.
 *  - **A ceiling on money.** COMMERCE is clipped at a fixed share of the total,
 *    so the upper rungs are unreachable by spending alone. See
 *    `spendingAloneCeiling`.
 *  - **An evidence gate.** A pillar with too few confirmed events reports
 *    "insufficient" rather than a low score — not knowing is not the same as
 *    knowing something bad.
 */

const clamp = (value: number, low: number, high: number): number =>
  Math.min(high, Math.max(low, value));

const DAY_MS = 86_400_000;

/** Two decimal places, so a stored figure and a recomputed one compare equal. */
const round = (value: number, places = 2): number => {
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
};

const PILLARS: readonly ValuePillar[] = [
  ValuePillar.COMMERCE,
  ValuePillar.CRAFT,
  ValuePillar.COMMUNITY,
  ValuePillar.ADVOCACY,
  ValuePillar.DISCOVERY,
  ValuePillar.RELIABILITY,
];

/**
 * What a contribution is still worth, given its age.
 *
 * Exponential on a half-life rather than a cliff at twelve months. A cliff
 * makes a woman's standing fall off a shelf on an anniversary she cannot see
 * coming; a half-life makes it drift, which is what a relationship actually
 * does when it is not tended.
 */
export function decayFactor(ageDays: number, halfLifeDays: number): number {
  if (halfLifeDays <= 0) return 1;
  return 0.5 ** (Math.max(0, ageDays) / halfLifeDays);
}

/** Whole days between two instants, floored at zero. */
function ageInDays(occurredAt: Date, now: Date): number {
  return Math.max(0, Math.floor((now.getTime() - occurredAt.getTime()) / DAY_MS));
}

/** `YYYY-MM-DD` in UTC — the bucket the daily cap is applied over. */
function dayKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/**
 * Sum one pillar's contributions, with the daily cap applied and decay on top.
 *
 * The cap is applied **at read time under the current policy**, which is a
 * deliberate exception to the rule that a contribution keeps the weight it was
 * stamped with. A weight is a price and repricing the past is arbitrary; a
 * daily cap is an anti-farming rule, and an anti-farming rule that only applies
 * to future farms does not close the farm that already happened.
 *
 * Negative weights are never capped. A woman cannot dilute a run of refusals by
 * concentrating them into one afternoon.
 */
function decayedRaw(
  contributions: readonly ValueContribution[],
  cap: number | undefined,
  policy: ValuePolicyView,
  now: Date,
): number {
  const positivesByDay = new Map<string, ValueContribution[]>();
  let total = 0;

  for (const contribution of contributions) {
    const age = ageInDays(contribution.occurredAt, now);
    if (age > policy.horizonDays) continue;

    if (contribution.weight < 0) {
      total += contribution.weight * decayFactor(age, policy.halfLifeDays);
      continue;
    }
    const key = dayKey(contribution.occurredAt);
    const bucket = positivesByDay.get(key) ?? [];
    bucket.push(contribution);
    positivesByDay.set(key, bucket);
  }

  for (const bucket of positivesByDay.values()) {
    // Highest-weight first, so a cap keeps her best contribution of the day
    // rather than whichever one the query happened to return first.
    const ordered = [...bucket].sort((a, b) => b.weight - a.weight);
    let spent = 0;
    for (const contribution of ordered) {
      const room = cap === undefined ? contribution.weight : cap - spent;
      if (room <= 0) break;
      const counted = Math.min(contribution.weight, room);
      spent += counted;
      total +=
        counted *
        decayFactor(ageInDays(contribution.occurredAt, now), policy.halfLifeDays);
    }
  }

  return total;
}

/**
 * A pillar's 0–100 score from its decayed contribution.
 *
 * `1 - e^(-raw/scale)` — concave, asymptotic, and never quite 100, because a
 * relationship is never finished. `scale` is the contribution at which the
 * pillar reaches about 63%, so it is the one number an administrator tunes to
 * say "this is what a strong contributor looks like here".
 */
function saturate(raw: number, scale: number): number {
  if (scale <= 0) return 0;
  return 100 * (1 - Math.exp(-Math.max(0, raw) / scale));
}

/**
 * RELIABILITY, which moves both ways from a baseline.
 *
 * `tanh` rather than the concave curve above because this pillar has to be
 * symmetric: a run of clean deliveries should lift it about as far as a run of
 * refusals drops it, and both should saturate. Someone with no history sits at
 * the baseline — the absence of trouble is not evidence of trouble, and
 * starting a new customer at zero would read as an accusation.
 */
function reliabilityScore(raw: number, scale: number, baseline: number): number {
  if (scale <= 0) return baseline;
  return clamp(baseline + 100 * Math.tanh(raw / scale), 0, 100);
}

export function scoreValue(
  contributions: readonly ValueContribution[],
  policy: ValuePolicyView,
  now: Date = new Date(),
): ValueScore {
  const byPillar = new Map<ValuePillar, ValueContribution[]>();
  for (const contribution of contributions) {
    const bucket = byPillar.get(contribution.pillar) ?? [];
    bucket.push(contribution);
    byPillar.set(contribution.pillar, bucket);
  }

  const totalWeight = PILLARS.reduce(
    (sum, pillar) => sum + (policy.pillarWeights[pillar] ?? 0),
    0,
  );

  const results: PillarResult[] = [];

  for (const pillar of PILLARS) {
    const weight = policy.pillarWeights[pillar] ?? 0;
    const scale = policy.pillarScales[pillar] ?? 0;
    const bucket = byPillar.get(pillar) ?? [];
    const raw = decayedRaw(bucket, policy.dailyPillarCaps[pillar], policy, now);

    const isReliability = pillar === ValuePillar.RELIABILITY;
    const enoughEvidence = bucket.length >= policy.minEvidencePerPillar;

    // The gate. A thin pillar reports "we do not know" rather than a low
    // number — except RELIABILITY, whose baseline *is* the answer for someone
    // with no history.
    let score: number;
    if (isReliability) {
      score = enoughEvidence
        ? reliabilityScore(raw, scale, policy.reliabilityBaseline)
        : policy.reliabilityBaseline;
    } else {
      score = enoughEvidence ? saturate(raw, scale) : 0;
    }

    const share = totalWeight > 0 ? weight / totalWeight : 0;
    let contribution = 1000 * share * (score / 100);

    // The economic guarantee, applied here and nowhere else.
    let capped = false;
    if (pillar === ValuePillar.COMMERCE) {
      const ceiling = (policy.commerceCeilingBps / 10_000) * 1000;
      if (contribution > ceiling) {
        contribution = ceiling;
        capped = true;
      }
    }

    results.push({
      pillar,
      score: round(score),
      raw: round(raw),
      events: bucket.length,
      evidence: enoughEvidence ? 'sufficient' : 'insufficient',
      contribution: round(contribution),
      ...(capped ? { capped } : {}),
    });
  }

  const score = clamp(
    Math.round(results.reduce((sum, result) => sum + result.contribution, 0)),
    0,
    1000,
  );

  return { score, pillars: results };
}

/**
 * The highest standing reachable by spending and nothing else.
 *
 * The number that makes "not just spending" checkable rather than claimed.
 * Surfaced on the admin policy screen beside the tier ladder: if this figure
 * ever rises above the top rung's threshold, the programme has become a
 * spending ladder and somebody should be told before it ships.
 *
 * RELIABILITY's baseline is included because it accrues without her doing
 * anything at all — a woman who only ever buys still gets it, so it belongs in
 * an honest ceiling.
 */
export function spendingAloneCeiling(policy: ValuePolicyView): number {
  const totalWeight = PILLARS.reduce(
    (sum, pillar) => sum + (policy.pillarWeights[pillar] ?? 0),
    0,
  );
  if (totalWeight <= 0) return 0;

  const commerceShare = (policy.pillarWeights[ValuePillar.COMMERCE] ?? 0) / totalWeight;
  const commerce = Math.min(
    1000 * commerceShare,
    (policy.commerceCeilingBps / 10_000) * 1000,
  );

  const reliabilityShare =
    (policy.pillarWeights[ValuePillar.RELIABILITY] ?? 0) / totalWeight;
  const reliability = 1000 * reliabilityShare * (policy.reliabilityBaseline / 100);

  return Math.round(commerce + reliability);
}

/**
 * Which rung a score sits on, given where she already stands.
 *
 * Promotion is immediate: reaching a rung should feel like reaching it, on the
 * day. Demotion is not, and the two guards below are the reason standing feels
 * like standing:
 *
 *  - **A hold.** A rung is kept for `holdDays` whatever the score does. Status
 *    that can evaporate in a fortnight was never status.
 *  - **Hysteresis.** After the hold, she must fall a full buffer below the
 *    threshold before dropping. Without it a score hovering on a boundary
 *    promotes and demotes her on alternate nights.
 */
export function resolveTier(
  score: number,
  tiers: readonly TierRung[],
  current: StandingState,
  now: Date = new Date(),
): TierDecision {
  const ladder = [...tiers].sort((a, b) => a.rank - b.rank);
  if (!ladder.length) {
    return { tier: null, movement: 'unchanged', heldUntil: null };
  }

  const earned =
    [...ladder].reverse().find((rung) => score >= rung.minScore) ?? null;
  const held = ladder.find((rung) => rung.key === current.tierKey) ?? null;

  // Nothing yet, or her first rung.
  if (!held) {
    return {
      tier: earned,
      movement: earned ? 'promoted' : 'unchanged',
      heldUntil: earned ? new Date(now.getTime() + earned.holdDays * DAY_MS) : null,
    };
  }

  // Up is always immediate.
  if (earned && earned.rank > held.rank) {
    return {
      tier: earned,
      movement: 'promoted',
      heldUntil: new Date(now.getTime() + earned.holdDays * DAY_MS),
    };
  }

  const wouldDrop = !earned || earned.rank < held.rank;
  if (!wouldDrop) {
    return { tier: held, movement: 'unchanged', heldUntil: current.tierHeldUntil };
  }

  // The hold has not run out.
  if (current.tierHeldUntil && current.tierHeldUntil > now) {
    return { tier: held, movement: 'held', heldUntil: current.tierHeldUntil };
  }

  // The hold has run out, but she has not fallen far enough to mean it.
  if (score >= held.minScore - held.demotionBufferScore) {
    return { tier: held, movement: 'held', heldUntil: current.tierHeldUntil };
  }

  return {
    tier: earned,
    movement: 'demoted',
    heldUntil: earned ? new Date(now.getTime() + earned.holdDays * DAY_MS) : null,
  };
}

/**
 * What she needs to reach the next rung, expressed as pillars rather than a
 * number.
 *
 * "٦٠ نقطة للذهبي" is a points system talking. "تقييم واحد مفيد، وصديقة وحدة
 * بتطلب" is a relationship talking, and it is the same arithmetic read the
 * other way round: the shortfall is divided across the pillars with the most
 * headroom, so the advice is always something she can actually do.
 */
export function nextRungAdvice(
  score: ValueScore,
  policy: ValuePolicyView,
  next: TierRung | null,
): Array<{ pillar: ValuePillar; headroom: number; needed: number }> {
  if (!next) return [];
  const shortfall = Math.max(0, next.minScore - score.score);
  if (shortfall === 0) return [];

  const totalWeight = PILLARS.reduce(
    (sum, pillar) => sum + (policy.pillarWeights[pillar] ?? 0),
    0,
  );

  return score.pillars
    .map((result) => {
      const weight = policy.pillarWeights[result.pillar] ?? 0;
      const share = totalWeight > 0 ? weight / totalWeight : 0;
      // What this pillar could still add if it were filled completely — capped
      // for COMMERCE, so the advice never says "spend more" past the ceiling.
      const ceiling =
        result.pillar === ValuePillar.COMMERCE
          ? Math.min(1000 * share, (policy.commerceCeilingBps / 10_000) * 1000)
          : 1000 * share;
      return {
        pillar: result.pillar,
        headroom: round(Math.max(0, ceiling - result.contribution)),
        needed: shortfall,
      };
    })
    .filter((entry) => entry.headroom > 0)
    .sort((a, b) => b.headroom - a.headroom);
}
