/**
 * The facts the scorer is allowed to see.
 *
 * Deliberately narrower than the rows they are gathered from. The kernel does
 * not know what a `SellerOrder` is, cannot reach a database, and could not
 * leak a customer's name if it wanted to — every field here is a count, a
 * ratio or a flag. That is what makes the scoring testable in one line and
 * auditable in one screen.
 *
 * Money is USD (see `cod-trust.constants`).
 */

/** What her own delivery history says, over `HISTORY_WINDOW_DAYS`. */
export interface CustomerFacts {
  /** No account behind this order at all (Q46 P1 permits guest checkout). */
  isGuest: boolean;
  accountAgeDays: number | null;
  phoneVerified: boolean;
  /** At least one device has completed key enrolment. */
  deviceEnrolled: boolean;

  /** Parcels that reached her hands. */
  deliveredParcels: number;
  /** Parcels she was there for and turned away. */
  refusedParcels: number;
  /**
   * Parcels that failed for a reason short of refusal — no answer, wrong
   * address, an area the courier could not reach.
   */
  failedParcels: number;
  /** Orders she cancelled after a seller had been told to prepare them. */
  cancelledAfterConfirmation: number;
  /** Orders placed at all, cash or otherwise. */
  totalOrders: number;

  /** The middle of what she usually spends, USD. Null until she has a history. */
  medianOrderValue: number | null;

  /** Disputes still open against her orders. */
  openDisputes: number;
}

/** What the destination says. */
export interface DestinationFacts {
  /** Chosen from her address book rather than typed at checkout. */
  fromAddressBook: boolean;
  addressLineLength: number;
  hasLandmark: boolean;
  isRural: boolean;

  /** Delivery attempts the platform has made into this governorate. */
  governorateAttempts: number;
  governorateRefusals: number;

  /**
   * How many *other* accounts have shipped to this recipient phone. One
   * number on three accounts is either a family sharing a handset or a
   * customer who has run out of accounts that still get cash on delivery.
   */
  otherAccountsOnPhone: number;
}

/** What this particular basket says. */
export interface BasketFacts {
  /** USD, after discounts and shipping — what the courier collects. */
  orderValue: number;
  sellerCount: number;
  itemCount: number;
  /** Units on the single largest line. */
  maxUnitsOnOneLine: number;
}

export interface CodFacts {
  customer: CustomerFacts;
  destination: DestinationFacts;
  basket: BasketFacts;
}

/** One signal's contribution, with the arithmetic left visible. */
export interface CodRiskFactor {
  code: string;
  /** Signed points actually added to the score. Zero when evidence is thin. */
  points: number;
  /** The most this factor could have moved the score. */
  weight: number;
  evidence: 'sufficient' | 'insufficient';
  /** The raw numbers the points came from, so a human can check the claim. */
  detail: Record<string, number | boolean>;
}

export interface CodRiskScore {
  /** 0–100. Higher is likelier to be refused at the door. */
  score: number;
  /** 0–1. How much of her own history stands behind that number. */
  confidence: number;
  factors: CodRiskFactor[];
}
