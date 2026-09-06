/**
 * The score.
 *
 * One pure function turns a customer's delivery history, her destination and
 * the basket in front of her into a number between 0 and 100, the factors that
 * add up to it, and a confidence saying how much of it to believe.
 *
 * Nothing here reads a database and nothing here asks a model. The number a
 * seller sees next to an order is arithmetic over rows she could count
 * herself, which is the only reason it can be defended when a customer asks
 * why she was sent a code and her sister was not.
 */

import {
  BASE_SCORE,
  CONFIDENCE_SATURATION_ATTEMPTS,
  MIN_EVIDENCE,
  MIN_USEFUL_ADDRESS_LENGTH,
  WEIGHTS,
} from '../cod-trust.constants';
import { CodFacts, CodRiskFactor, CodRiskScore } from './cod-facts';

const clamp = (value: number, low: number, high: number): number =>
  Math.min(high, Math.max(low, value));

/** Two decimal places, so a stored score and a recomputed one compare equal. */
const round = (value: number, places = 2): number => {
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
};

/**
 * A ratio, softened towards zero when the sample is small.
 *
 * Two refusals out of two attempts is 100% by arithmetic and roughly nothing
 * by evidence. Adding the minimum sample as pseudo-attempts pulls a thin rate
 * down towards the platform's assumption of innocence, and leaves a thick one
 * almost untouched.
 */
const shrunkRate = (hits: number, attempts: number, prior: number): number => {
  if (attempts <= 0) return 0;
  return hits / (attempts + prior);
};

const asFactor = (
  code: string,
  weight: number,
  severity: number,
  evidence: 'sufficient' | 'insufficient',
  detail: Record<string, number | boolean>,
): CodRiskFactor => ({
  code,
  points: evidence === 'sufficient' ? round(weight * clamp(severity, 0, 1)) : 0,
  weight,
  evidence,
  detail,
});

export function scoreCodRisk(facts: CodFacts): CodRiskScore {
  const { customer, destination, basket } = facts;

  const attempts =
    customer.deliveredParcels + customer.refusedParcels + customer.failedParcels;
  const hasPersonalEvidence = attempts >= MIN_EVIDENCE.personalAttempts;

  const factors: CodRiskFactor[] = [];

  // ── What she has done at the door ──────────────────────────────────────
  //
  // Refusal and non-delivery are kept apart on purpose. Turning a courier away
  // is a decision; a phone that rang out is a scheduling problem, and pricing
  // the two the same would punish a woman who works shifts.
  factors.push(
    asFactor(
      'refusalRate',
      WEIGHTS.refusalRate,
      shrunkRate(customer.refusedParcels, attempts, MIN_EVIDENCE.personalAttempts) *
        2.2,
      hasPersonalEvidence ? 'sufficient' : 'insufficient',
      { refused: customer.refusedParcels, attempts },
    ),
  );

  factors.push(
    asFactor(
      'failureRate',
      WEIGHTS.failureRate,
      shrunkRate(customer.failedParcels, attempts, MIN_EVIDENCE.personalAttempts) *
        1.8,
      hasPersonalEvidence ? 'sufficient' : 'insufficient',
      { failed: customer.failedParcels, attempts },
    ),
  );

  factors.push(
    asFactor(
      'cancellationRate',
      WEIGHTS.cancellationRate,
      shrunkRate(
        customer.cancelledAfterConfirmation,
        customer.totalOrders,
        MIN_EVIDENCE.personalOrders,
      ) * 2,
      customer.totalOrders >= MIN_EVIDENCE.personalOrders
        ? 'sufficient'
        : 'insufficient',
      {
        cancelled: customer.cancelledAfterConfirmation,
        orders: customer.totalOrders,
      },
    ),
  );

  // ── This basket against her own baseline ───────────────────────────────
  //
  // Only the upside counts. A woman who usually spends 20 and today spends 5
  // is not a risk; the classic refused parcel is the one that was four times
  // the order she is used to placing.
  const median = customer.medianOrderValue;
  const multiple = median && median > 0 ? basket.orderValue / median : 0;
  factors.push(
    asFactor(
      'valueAnomaly',
      WEIGHTS.valueAnomaly,
      (multiple - 2) / 4,
      median !== null && customer.deliveredParcels >= MIN_EVIDENCE.personalOrders
        ? 'sufficient'
        : 'insufficient',
      { order_value: round(basket.orderValue), median_value: round(median ?? 0) },
    ),
  );

  // ── Who is behind the order ────────────────────────────────────────────
  //
  // Always scored: absence of evidence *is* the evidence here. A guest with an
  // unverified number is not an unknown quantity, she is a known one.
  const identityGaps =
    (customer.isGuest ? 0.5 : 0) +
    (customer.phoneVerified ? 0 : 0.3) +
    (customer.deviceEnrolled ? 0 : 0.2);
  factors.push(
    asFactor('weakIdentity', WEIGHTS.weakIdentity, identityGaps, 'sufficient', {
      guest: customer.isGuest,
      phone_verified: customer.phoneVerified,
      device_enrolled: customer.deviceEnrolled,
    }),
  );

  // ── Where it is going ──────────────────────────────────────────────────
  const addressGaps =
    (destination.fromAddressBook ? 0 : 0.35) +
    (destination.addressLineLength < MIN_USEFUL_ADDRESS_LENGTH ? 0.4 : 0) +
    (destination.hasLandmark ? 0 : 0.15) +
    (destination.isRural ? 0.1 : 0);
  factors.push(
    asFactor('addressQuality', WEIGHTS.addressQuality, addressGaps, 'sufficient', {
      from_address_book: destination.fromAddressBook,
      address_length: destination.addressLineLength,
      has_landmark: destination.hasLandmark,
      is_rural: destination.isRural,
    }),
  );

  factors.push(
    asFactor(
      'phoneReuse',
      WEIGHTS.phoneReuse,
      destination.otherAccountsOnPhone / 3,
      'sufficient',
      { other_accounts: destination.otherAccountsOnPhone },
    ),
  );

  // The governorate's own base rate, expressed as how far above the platform's
  // opening assumption it sits. A quiet governorate contributes nothing.
  const destinationRate =
    destination.governorateAttempts > 0
      ? destination.governorateRefusals / destination.governorateAttempts
      : 0;
  factors.push(
    asFactor(
      'destinationBaseRate',
      WEIGHTS.destinationBaseRate,
      (destinationRate - 0.05) / 0.2,
      destination.governorateAttempts >= MIN_EVIDENCE.destinationAttempts
        ? 'sufficient'
        : 'insufficient',
      {
        refusals: destination.governorateRefusals,
        attempts: destination.governorateAttempts,
      },
    ),
  );

  // ── The shape of the basket ────────────────────────────────────────────
  //
  // Only read on a first order. Once she has a delivery history, that history
  // answers the question better than the number of sellers in her cart ever
  // could.
  const basketOddity =
    (basket.sellerCount >= 3 ? 0.4 : 0) +
    (basket.maxUnitsOnOneLine >= 4 ? 0.4 : 0) +
    (basket.itemCount >= 8 ? 0.2 : 0);
  factors.push(
    asFactor(
      'basketShape',
      WEIGHTS.basketShape,
      basketOddity,
      customer.deliveredParcels === 0 ? 'sufficient' : 'insufficient',
      {
        sellers: basket.sellerCount,
        items: basket.itemCount,
        max_units: basket.maxUnitsOnOneLine,
      },
    ),
  );

  // ── The credit she has earned ──────────────────────────────────────────
  //
  // The only negative factor, and the reason a loyal customer stops being
  // asked for codes. It is scaled by a *clean* history: deliveries she also
  // refused parcels around are worth proportionally less.
  const cleanShare = attempts > 0 ? customer.deliveredParcels / attempts : 0;
  factors.push(
    asFactor(
      'provenHistory',
      WEIGHTS.provenHistory,
      (customer.deliveredParcels / CONFIDENCE_SATURATION_ATTEMPTS) * cleanShare,
      customer.deliveredParcels > 0 ? 'sufficient' : 'insufficient',
      { delivered: customer.deliveredParcels, attempts },
    ),
  );

  // An open dispute is not scored — it is a fight about a parcel that already
  // arrived, and folding it into a refusal score would charge her twice for
  // one bad experience. It is surfaced to the reviewer instead.

  const score = clamp(
    round(BASE_SCORE + factors.reduce((total, f) => total + f.points, 0)),
    0,
    100,
  );

  return {
    score,
    confidence: round(clamp(attempts / CONFIDENCE_SATURATION_ATTEMPTS, 0, 1), 2),
    factors,
  };
}
