import { RoomCandidateStatus, RoomDecisionStatus } from '@prisma/client';

/**
 * When a room is finished deciding, and what the room thinks.
 *
 * Pure: no database, no money, no clock beyond what is handed in. Everything
 * here is arithmetic over the shape of the decisions, which is what lets the
 * readiness badge on a room card, the blockers listed on the room screen and
 * the refusal that stops a half-decided plan being drawn all come from one
 * function and therefore never disagree.
 *
 * One rule runs through the whole file and is worth stating before the code:
 * **votes advise, they never decide.** `consensusFor` reports what the room
 * leans towards and how firmly, and nothing anywhere calls it to choose. A
 * group that could outvote the woman paying is not a group of friends helping
 * her shop, it is a committee spending her money.
 */

export interface CandidateFacts {
  id: string;
  status: RoomCandidateStatus;
  quantity: number;
  votesUp: number;
  votesDown: number;
  voteScore: number;
  /** SYP, live at read time. Null when the offer has gone. */
  unitPriceSyp: number | null;
  /** False when the offer is delisted or out of stock. */
  purchasable: boolean;
}

export interface DecisionFacts {
  id: string;
  title: string;
  status: RoomDecisionStatus;
  pickCount: number;
  isRequired: boolean;
  isSuggested: boolean;
  candidates: CandidateFacts[];
}

/** Why a room cannot be turned into a plan yet. */
export type BlockerCode =
  | 'NO_DECISIONS'
  | 'NOTHING_CHOSEN'
  | 'DECISION_UNRESOLVED'
  | 'DECISION_EMPTY'
  | 'CHOSEN_UNAVAILABLE'
  | 'OVER_PICK_COUNT';

export interface Blocker {
  code: BlockerCode;
  decisionId: string | null;
  decisionTitle: string | null;
}

export interface DecisionState {
  id: string;
  /** Candidates marked CHOSEN. */
  chosen: CandidateFacts[];
  /** `pickCount` minus how many are chosen; zero when satisfied. */
  remaining: number;
  /** Resolved, or explicitly skipped. Either way it stops blocking. */
  settled: boolean;
  blockers: Blocker[];
}

export interface RoomReadiness {
  ready: boolean;
  decisions: DecisionState[];
  blockers: Blocker[];
  /** Required decisions settled, over required decisions. */
  settledRequired: number;
  totalRequired: number;
  /** 0–1, for the progress rail. Counts optional decisions too, so a room that
   *  is genuinely almost done does not read as half finished. */
  progress: number;
}

const chosenOf = (decision: DecisionFacts): CandidateFacts[] =>
  decision.candidates.filter((c) => c.status === RoomCandidateStatus.CHOSEN);

export function decisionState(decision: DecisionFacts): DecisionState {
  const chosen = chosenOf(decision);
  const blockers: Blocker[] = [];

  const settled =
    decision.status === RoomDecisionStatus.SKIPPED ||
    (decision.status === RoomDecisionStatus.RESOLVED &&
      chosen.length >= decision.pickCount);

  if (decision.status !== RoomDecisionStatus.SKIPPED) {
    if (!decision.candidates.length) {
      blockers.push({
        code: 'DECISION_EMPTY',
        decisionId: decision.id,
        decisionTitle: decision.title,
      });
    } else if (chosen.length < decision.pickCount) {
      blockers.push({
        code: 'DECISION_UNRESOLVED',
        decisionId: decision.id,
        decisionTitle: decision.title,
      });
    } else if (chosen.length > decision.pickCount) {
      // Choosing three answers to a question that wanted one is not a stricter
      // decision, it is an unmade one — and silently buying all three is the
      // failure mode a cart has.
      blockers.push({
        code: 'OVER_PICK_COUNT',
        decisionId: decision.id,
        decisionTitle: decision.title,
      });
    }

    // A piece that sold out between choosing it and buying it. Caught here so
    // the room says so on its own screen rather than at the payment step.
    if (chosen.some((candidate) => !candidate.purchasable)) {
      blockers.push({
        code: 'CHOSEN_UNAVAILABLE',
        decisionId: decision.id,
        decisionTitle: decision.title,
      });
    }
  }

  return {
    id: decision.id,
    chosen,
    remaining: Math.max(0, decision.pickCount - chosen.length),
    settled: settled && !blockers.length,
    blockers,
  };
}

export function roomReadiness(decisions: readonly DecisionFacts[]): RoomReadiness {
  if (!decisions.length) {
    return {
      ready: false,
      decisions: [],
      blockers: [{ code: 'NO_DECISIONS', decisionId: null, decisionTitle: null }],
      settledRequired: 0,
      totalRequired: 0,
      progress: 0,
    };
  }

  const states = decisions.map(decisionState);

  // Only required decisions can hold a room back. A suggested "a bag would be
  // nice" that she never engaged with must not stop her buying the dress —
  // which is exactly what a checkout-the-whole-basket model does.
  const required = decisions.filter((d) => d.isRequired && !d.isSuggested);
  const requiredStates = states.filter((state) =>
    required.some((d) => d.id === state.id),
  );

  const blockers = requiredStates.flatMap((state) => state.blockers);
  // A room whose decisions are all optional suggestions has nothing required
  // to block it — and so read as «every decision settled», ready for a plan,
  // the moment an occasion opened it, before she had chosen a single piece.
  // Ready means there is something to buy.
  if (!states.some((state) => state.chosen.length > 0)) {
    blockers.push({ code: 'NOTHING_CHOSEN', decisionId: null, decisionTitle: null });
  }
  const settledRequired = requiredStates.filter((state) => state.settled).length;
  const settledAll = states.filter((state) => state.settled).length;

  return {
    ready: blockers.length === 0 && settledRequired === requiredStates.length,
    decisions: states,
    blockers,
    settledRequired,
    totalRequired: requiredStates.length,
    progress: states.length ? settledAll / states.length : 0,
  };
}

// ── What the room thinks ────────────────────────────────────────────────

export interface Consensus {
  /** The candidate with the best tally, or null when nobody has voted. */
  leaderId: string | null;
  /** The runner-up's id, when there is one. */
  runnerUpId: string | null;
  /** Leader's score minus the runner-up's. */
  margin: number;
  /** How many people expressed any opinion at all. */
  voters: number;
  /**
   * True when the room is split: a thin margin, or real opposition to the
   * leader. Surfaced so the screen can say «الآراء منقسمة» instead of
   * announcing a winner nobody agreed on.
   */
  contested: boolean;
  /** Nobody has voted. Different from a tie, and said differently. */
  silent: boolean;
}

export function consensusFor(candidates: readonly CandidateFacts[]): Consensus {
  const live = candidates.filter(
    (candidate) => candidate.status !== RoomCandidateStatus.REJECTED,
  );
  const voters = live.reduce(
    (total, candidate) => total + candidate.votesUp + candidate.votesDown,
    0,
  );

  if (!live.length || voters === 0) {
    return {
      leaderId: null,
      runnerUpId: null,
      margin: 0,
      voters: 0,
      contested: false,
      silent: true,
    };
  }

  const ranked = [...live].sort(
    (a, b) => b.voteScore - a.voteScore || a.id.localeCompare(b.id),
  );
  const leader = ranked[0];
  const runnerUp = ranked[1] ?? null;
  const margin = leader.voteScore - (runnerUp?.voteScore ?? 0);

  return {
    leaderId: leader.id,
    runnerUpId: runnerUp?.id ?? null,
    margin,
    voters,
    // A one-vote lead is not agreement, and neither is a leader half the room
    // voted against.
    contested:
      (runnerUp !== null && margin <= 1) ||
      leader.votesDown >= Math.max(1, leader.votesUp),
    silent: false,
  };
}

// ── Money, as a shape rather than an amount ─────────────────────────────

export interface BudgetFit {
  /** Sum of chosen candidates, SYP. */
  totalSyp: number;
  minSyp: number | null;
  maxSyp: number | null;
  /** `under`, `inside`, `over`, or `unknown` when no budget was set. */
  verdict: 'under' | 'inside' | 'over' | 'unknown';
  /** How far over the ceiling, when over. Zero otherwise. */
  overBySyp: number;
  /** Lines whose price could not be read — a delisted offer. */
  unpricedCount: number;
}

/**
 * What the chosen pieces come to, against what she said she would spend.
 *
 * Takes prices rather than reading them, so the whole calculation stays
 * testable without a catalogue — and so the caller is forced to have fetched
 * live prices rather than trusting something stored on the plan.
 */
export function budgetFit(
  chosen: readonly { unitPriceSyp: number | null; quantity: number }[],
  budget: { minSyp: number | null; maxSyp: number | null },
): BudgetFit {
  let totalSyp = 0;
  let unpricedCount = 0;

  for (const line of chosen) {
    if (line.unitPriceSyp === null) {
      unpricedCount += 1;
      continue;
    }
    totalSyp += line.unitPriceSyp * line.quantity;
  }
  totalSyp = Math.round(totalSyp * 100) / 100;

  const { minSyp, maxSyp } = budget;
  if (minSyp === null && maxSyp === null) {
    return {
      totalSyp,
      minSyp,
      maxSyp,
      verdict: 'unknown',
      overBySyp: 0,
      unpricedCount,
    };
  }

  if (maxSyp !== null && totalSyp > maxSyp) {
    return {
      totalSyp,
      minSyp,
      maxSyp,
      verdict: 'over',
      overBySyp: Math.round((totalSyp - maxSyp) * 100) / 100,
      unpricedCount,
    };
  }
  if (minSyp !== null && totalSyp < minSyp) {
    return {
      totalSyp,
      minSyp,
      maxSyp,
      verdict: 'under',
      overBySyp: 0,
      unpricedCount,
    };
  }

  return {
    totalSyp,
    minSyp,
    maxSyp,
    verdict: 'inside',
    overBySyp: 0,
    unpricedCount,
  };
}
