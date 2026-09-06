/**
 * From a score to a decision.
 *
 * Scoring and policy are separate files because they answer different
 * questions and change for different reasons. The score is a claim about the
 * world — this parcel is likely to come back — and it is right or wrong. The
 * policy is a business decision about what to do given that claim, and it is
 * generous or strict. Mixing them means every tightening of the rules looks
 * like a change to the model.
 *
 * Two invariants hold and both matter:
 *
 * 1. **Rules may only raise.** A hard rule can demand more assurance than the
 *    score asked for; nothing can demand less. If a rule could lower the bar,
 *    a high score would be arguable away and the engine would be decoration.
 *
 * 2. **The ladder never ends in a refusal.** The top rung moves the basket to
 *    a payment rail that does not send cash out on the road. She can always
 *    buy. That is the difference between managing risk and turning customers
 *    away, and on a platform whose customers are women shopping from home it
 *    is not a small difference.
 */

import { CodAssurance, CodRiskTier } from '@prisma/client';
import { HARD_RULES, TIER_THRESHOLDS, TRUSTED_MIN_DELIVERIES } from '../cod-trust.constants';
import { CodFacts, CodRiskScore } from './cod-facts';

export interface CodDecision {
  tier: CodRiskTier;
  assurance: CodAssurance;
  /** Hard rules that fired, in the order they were evaluated. */
  ruleCodes: string[];
}

/** How much friction each rung represents, so two can be compared. */
const LADDER: readonly CodAssurance[] = [
  CodAssurance.NONE,
  CodAssurance.ORDER_CONFIRMATION,
  CodAssurance.PREPAYMENT,
];

const raise = (current: CodAssurance, candidate: CodAssurance): CodAssurance =>
  LADDER.indexOf(candidate) > LADDER.indexOf(current) ? candidate : current;

/**
 * The tier the score alone implies.
 *
 * `TRUSTED` additionally requires deliveries actually taken, so that a
 * customer the platform has never watched cannot arrive at the frictionless
 * tier merely by having no record.
 */
export function tierFor(score: number, deliveredParcels: number): CodRiskTier {
  if (score < TIER_THRESHOLDS.trusted && deliveredParcels >= TRUSTED_MIN_DELIVERIES) {
    return CodRiskTier.TRUSTED;
  }
  if (score < TIER_THRESHOLDS.low) return CodRiskTier.LOW;
  if (score < TIER_THRESHOLDS.medium) return CodRiskTier.MEDIUM;
  return CodRiskTier.HIGH;
}

const assuranceForTier = (tier: CodRiskTier): CodAssurance => {
  switch (tier) {
    case CodRiskTier.TRUSTED:
    case CodRiskTier.LOW:
      return CodAssurance.NONE;
    case CodRiskTier.MEDIUM:
      return CodAssurance.ORDER_CONFIRMATION;
    case CodRiskTier.HIGH:
      return CodAssurance.PREPAYMENT;
  }
};

export function decideCodAssurance(
  score: CodRiskScore,
  facts: CodFacts,
): CodDecision {
  const tier = tierFor(score.score, facts.customer.deliveredParcels);
  let assurance = assuranceForTier(tier);
  const ruleCodes: string[] = [];

  const { customer, basket } = facts;
  const firstOrder = customer.deliveredParcels === 0;

  // A first cash order of any size gets one code. It costs her ten seconds and
  // it is the whole defence against a number typed wrong or typed by someone
  // else — the failure the score cannot see, because it has no history to read.
  if (firstOrder && basket.orderValue >= HARD_RULES.firstOrderConfirmAbove) {
    assurance = raise(assurance, CodAssurance.ORDER_CONFIRMATION);
    ruleCodes.push('first_order_above_threshold');
  }

  if (customer.isGuest && basket.orderValue >= HARD_RULES.guestConfirmAbove) {
    assurance = raise(assurance, CodAssurance.ORDER_CONFIRMATION);
    ruleCodes.push('guest_above_threshold');
  }

  // Above this, the value on the road is worth ten seconds from anyone. A
  // perfect history buys a customer out of suspicion, not out of arithmetic.
  if (basket.orderValue >= HARD_RULES.alwaysConfirmAbove) {
    assurance = raise(assurance, CodAssurance.ORDER_CONFIRMATION);
    ruleCodes.push('high_value_order');
  }

  // Refusals are counted, not rated, for this rule. A rate can be argued down
  // by a long history; three parcels sent back is three couriers' days and two
  // sellers' stock, and it is the one place the engine stops negotiating.
  if (customer.refusedParcels >= HARD_RULES.refusalsForPrepayment) {
    assurance = raise(assurance, CodAssurance.PREPAYMENT);
    ruleCodes.push('repeat_refusals');
  }

  return { tier, assurance, ruleCodes };
}
