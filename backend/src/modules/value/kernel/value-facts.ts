import { ValuePillar } from '@prisma/client';

/**
 * The facts the scorer is allowed to see.
 *
 * Deliberately narrower than the rows they are gathered from. The kernel does
 * not know what an order is, cannot reach a database, and holds nothing that
 * identifies anybody — every field below is a weight, a date or a count. That
 * is what makes standing testable in one line and auditable in one screen.
 */

/** One confirmed contribution, reduced to what the arithmetic needs. */
export interface ValueContribution {
  pillar: ValuePillar;
  /** The earning rule that fired. Carried for the daily-cap grouping only. */
  code: string;
  /** Signed. Negative appears in RELIABILITY alone. */
  weight: number;
  /** When it happened, not when it was recorded. Decay is measured from here. */
  occurredAt: Date;
}

/**
 * The active policy, flattened.
 *
 * Every map is keyed by `ValuePillar`. A missing key means the pillar is
 * switched off rather than defaulted — an administrator who removes a weight
 * has said something, and quietly substituting one would be the engine
 * overruling her.
 */
export interface ValuePolicyView {
  pillarWeights: Partial<Record<ValuePillar, number>>;
  pillarScales: Partial<Record<ValuePillar, number>>;
  /** Most positive weight one pillar may take from a single day. */
  dailyPillarCaps: Partial<Record<ValuePillar, number>>;
  halfLifeDays: number;
  horizonDays: number;
  /** Basis points of the 0–1000 score that COMMERCE may ever contribute. */
  commerceCeilingBps: number;
  reliabilityBaseline: number;
  minEvidencePerPillar: number;
}

export type PillarEvidence = 'sufficient' | 'insufficient';

export interface PillarResult {
  pillar: ValuePillar;
  /** 0–100. */
  score: number;
  /** The decayed, capped contribution behind the score. */
  raw: number;
  /** Confirmed events counted. */
  events: number;
  evidence: PillarEvidence;
  /** Points this pillar put into the 0–1000 total. */
  contribution: number;
  /** True when the commerce ceiling clipped this pillar's contribution. */
  capped?: boolean;
}

export interface ValueScore {
  /** 0–1000. */
  score: number;
  pillars: PillarResult[];
}

/** A rung, as the tiering function needs it. */
export interface TierRung {
  id: string;
  key: string;
  name: string;
  minScore: number;
  rank: number;
  demotionBufferScore: number;
  holdDays: number;
}

/** Where she stands now, for the hysteresis to reason about. */
export interface StandingState {
  tierKey: string | null;
  tierAchievedAt: Date | null;
  tierHeldUntil: Date | null;
}

export interface TierDecision {
  tier: TierRung | null;
  /** `promoted`, `demoted`, `held` or `unchanged`. Drives the notification. */
  movement: 'promoted' | 'demoted' | 'held' | 'unchanged';
  /** Set when a demotion was due and suppressed. */
  heldUntil: Date | null;
}
