/**
 * Missions: asking for something worth doing, or asking for nothing.
 *
 * The reason most of these systems are worthless is that they invent a task,
 * attach a token to it, and hope the token is motivating enough to cover the
 * fact that the task was pointless. Reem's version starts from the other end:
 * a mission may only ask for something that is *already* worth doing for her
 * own reasons — describing the pieces in her closet makes every future
 * suggestion better, reviewing a dress she actually wore helps the next woman
 * decide, closing an open decision finishes a room she started — and the
 * mission exists only to make that visible at the moment it is possible.
 *
 * ── Two rules that do all the work ───────────────────────────────────────
 *
 * 1. **No mission mints anything.** The reward is the outcome. Where the
 *    underlying act already earns standing — a written review, a shared look —
 *    it earns it through the Value collector exactly as it would have without
 *    the mission. There is no mission currency, because a currency is what
 *    turns a useful act into a farmed one.
 *
 * 2. **A mission she cannot finish is never offered.** Every criterion carries
 *    not just what is done but how much is *possible*: unreviewed deliveries
 *    she actually has, closet pieces actually missing a descriptor. Asking a
 *    woman with no deliveries to review two purchases is the moment the whole
 *    feature reads as noise.
 *
 * Pure — counts in, progress out. The queries that produce those counts live
 * in the service, and every one of them reads rows this module did not write.
 */

export type CriteriaType =
  /// Review products she has actually received.
  | 'REVIEW_PURCHASES'
  /// Fill in colour/fabric on closet pieces that have neither.
  | 'DESCRIBE_CLOSET'
  /// Record what she wore, which is what makes the wardrobe read true.
  | 'LOG_WEARS'
  /// Finish an open decision in a room she started.
  | 'CLOSE_ROOM_DECISION'
  /// Build a look from pieces she owns.
  | 'BUILD_LOOK'
  /// Look at parts of the catalogue she has never opened.
  | 'EXPLORE_CATEGORIES';

export interface Criteria {
  type: CriteriaType;
  /** How many, in total, counts as done. */
  target: number;
}

/**
 * What the database says about her, for one criterion.
 *
 * `possible` is the field that separates this from a task list: it is how many
 * opportunities genuinely exist right now, and a mission is withheld when it
 * is short of what finishing would take.
 *
 * `baseline` is the field that separates it from a scoreboard. Every count
 * here is cumulative — reviews she has written, pieces she has described — so
 * without a baseline a mission arrives half complete because of something she
 * did last spring, which is both meaningless as progress and faintly
 * insulting as a request. It is snapshotted when the mission is offered and
 * never moves; progress is what she has done *since being asked*.
 */
export interface MissionEvidence {
  done: number;
  possible: number;
  /** `done` at the moment the mission was offered. Absent means zero. */
  baseline?: number;
}

export interface MissionReading {
  /** 0-1, recomputed from evidence — never incremented. */
  progress: number;
  complete: boolean;
  /** How many more, capped at what is actually possible. */
  remaining: number;
}

const round = (n: number): number => Math.round(n * 100) / 100;

export function readProgress(
  criteria: Criteria,
  evidence: MissionEvidence,
): MissionReading {
  const target = Math.max(1, criteria.target);
  const achieved = Math.max(0, evidence.done - (evidence.baseline ?? 0));
  const progress = round(Math.min(1, achieved / target));
  return {
    progress,
    complete: achieved >= target,
    remaining: Math.max(0, target - achieved),
  };
}

/**
 * Whether to put this in front of her at all.
 *
 * Three refusals, in order of how badly each would read:
 *
 *  - already done — congratulating her for something finished before she was
 *    asked is the tell of a system pretending to have caused it;
 *  - impossible — she has fewer opportunities than the mission needs;
 *  - trivial — the target is already met by what exists, so it is not a
 *    mission, it is a receipt.
 */
export function isWorthOffering(
  criteria: Criteria,
  evidence: MissionEvidence,
): boolean {
  const reading = readProgress(criteria, evidence);
  if (reading.complete) return false;
  return evidence.possible >= reading.remaining;
}

/**
 * Ordering the offers.
 *
 * Nearest to done first, then the one with the most room to help. A woman with
 * one review left on a mission of three should see that before a fresh mission
 * of five, because finishing something is a better invitation than starting
 * something.
 */
export function rankOffers<T extends { criteria: Criteria; evidence: MissionEvidence }>(
  offers: readonly T[],
): T[] {
  return [...offers].sort((a, b) => {
    const pa = readProgress(a.criteria, a.evidence);
    const pb = readProgress(b.criteria, b.evidence);
    if (pb.progress !== pa.progress) return pb.progress - pa.progress;
    return pa.remaining - pb.remaining;
  });
}
