import {
  FulfilmentMode,
  ReturnCostBearer,
  ReturnReason,
  ReturnStatus,
} from '@prisma/client';

/**
 * The return rules, as data.
 *
 * Q56 P1 is the source: «خلال 7 أيام من الاستلام، بشرط أن يكون المنتج غير
 * مستخدم وبحالته الأصلية»، the seller bears the return leg «إذا كان الخطأ من
 * البائع» and the customer bears it «إذا غيّرت رأيها»، with مستحضرات التجميل
 * والعناية الشخصية المفتوحة والمنتجات المصنوعة حسب الطلب excluded.
 *
 * Everything here is a pure function of facts the caller has already read, so
 * the rules can be unit-tested without a database and — more importantly — so
 * the same decision is reachable from two places that must never disagree:
 * the eligibility screen the customer sees *before* she asks, and the check
 * that runs when she does.
 */

/** Q56 P1 — «خلال 7 أيام من الاستلام». */
export const RETURN_WINDOW_DAYS = 7;

/**
 * When the right to return a parcel expires, counted from delivery.
 *
 * `extraDays` is Reem Value's `ENHANCED_RETURNS` benefit, passed in by the
 * caller rather than looked up here — this file stays a pure function of facts
 * somebody else has already read, which is what lets the eligibility screen and
 * the check that runs when she asks share one implementation.
 *
 * It can only ever lengthen the window. A standing benefit that could shorten
 * one would be a penalty wearing a reward's clothes, and `Math.max` is where
 * that is ruled out rather than trusted.
 */
export function returnWindowClosesAt(deliveredAt: Date, extraDays = 0): Date {
  const closes = new Date(deliveredAt);
  closes.setDate(closes.getDate() + RETURN_WINDOW_DAYS + Math.max(0, extraDays));
  return closes;
}

// ── Fault ───────────────────────────────────────────────────────────────

/**
 * Reasons that assert something went wrong on our side of the sale.
 *
 * The distinction runs through the whole file: it decides who pays the return
 * leg, whether photographic evidence is required, whether an excluded category
 * may still come back, and whether the goods can be put back on the shelf.
 */
const FAULT_REASONS: ReadonlySet<ReturnReason> = new Set([
  ReturnReason.DEFECTIVE,
  ReturnReason.WRONG_ITEM,
  ReturnReason.NOT_AS_DESCRIBED,
  ReturnReason.DAMAGED_IN_TRANSIT,
  ReturnReason.LATE_DELIVERY,
]);

/** Faults of carriage rather than of the goods — whoever carried it answers. */
const CARRIAGE_REASONS: ReadonlySet<ReturnReason> = new Set([
  ReturnReason.DAMAGED_IN_TRANSIT,
  ReturnReason.LATE_DELIVERY,
]);

export function isFaultReason(reason: ReturnReason): boolean {
  return FAULT_REASONS.has(reason);
}

/**
 * Q67 P1 answered «حسب الحالة» — who bears the return leg depends on the case.
 * This is the *default* the system proposes from the stated reason; whoever
 * approves the return may override it, and an admin decides the ones that have
 * no honest default.
 *
 * `OTHER` deliberately returns null rather than guessing. A free-text reason
 * carries no fault information, and charging the wrong party by default is the
 * kind of small silent unfairness nobody ever audits.
 */
export function defaultCostBearer(
  reason: ReturnReason,
  fulfilmentMode: FulfilmentMode,
): ReturnCostBearer | null {
  if (CARRIAGE_REASONS.has(reason)) {
    // Our courier, our problem; a seller who ships it herself owns her own leg.
    return fulfilmentMode === FulfilmentMode.SELLER_SHIPS
      ? ReturnCostBearer.SELLER
      : ReturnCostBearer.PLATFORM;
  }
  if (FAULT_REASONS.has(reason)) return ReturnCostBearer.SELLER;
  if (reason === ReturnReason.OTHER) return null;
  // Q56 P1 — «إذا غيّرت رأيها، تتحمل الزبونة أجور الإرجاع».
  return ReturnCostBearer.CUSTOMER;
}

/**
 * Whether a photo has to come with the request.
 *
 * A claim of fault moves money away from the seller, so it must arrive with
 * something a human can look at. A change of mind claims nothing and needs
 * nothing — demanding a photo there would only teach customers that the form
 * is a formality.
 */
export function requiresEvidence(reason: ReturnReason): boolean {
  return (
    reason === ReturnReason.DEFECTIVE ||
    reason === ReturnReason.WRONG_ITEM ||
    reason === ReturnReason.NOT_AS_DESCRIBED ||
    reason === ReturnReason.DAMAGED_IN_TRANSIT
  );
}

/**
 * Whether the goods go back on sale once received.
 *
 * Q56 P1 requires the item to come back «غير مستخدم وبحالته الأصلية», which a
 * change of mind satisfies and a defect does not. Restocking a broken item
 * would sell it to the next customer, so the default is decided by the reason
 * and the receiving seller can still say otherwise.
 */
export function isResaleable(reason: ReturnReason): boolean {
  return !FAULT_REASONS.has(reason);
}

// ── Eligibility ─────────────────────────────────────────────────────────

/** Why a line cannot come back. `null` means it can. */
export const ReturnBlocker = {
  NotDelivered: 'NOT_DELIVERED',
  WindowClosed: 'WINDOW_CLOSED',
  CategoryExcluded: 'CATEGORY_EXCLUDED',
  OfferExcluded: 'OFFER_EXCLUDED',
  MadeToOrder: 'MADE_TO_ORDER',
  FullyReturned: 'FULLY_RETURNED',
} as const;

export type ReturnBlocker = (typeof ReturnBlocker)[keyof typeof ReturnBlocker];

/** What the caller has to have read about one order line to decide. */
export interface LineReturnFacts {
  readonly quantityOrdered: number;
  /** Already claimed on other requests that have not been rejected. */
  readonly quantityClaimed: number;
  /** Q56 P1 — the category is inside the change-of-mind window at all. */
  readonly categoryAllowsReturns: boolean;
  /** The seller's own switch on this offer. */
  readonly offerAcceptsReturns: boolean;
  /** Q30 — made to order for this customer. */
  readonly isMadeToOrder: boolean;
}

export interface ParcelReturnFacts {
  readonly deliveredAt: Date | null;
  readonly now?: Date;
  /**
   * Extra days her standing buys her — Reem Value's `ENHANCED_RETURNS`.
   *
   * Optional and defaulting to none, so every existing caller keeps the Q56
   * window unchanged and only the paths that have looked up her benefit pass
   * anything here.
   */
  readonly extraWindowDays?: number;
}

/**
 * Why this line cannot be returned for this reason, or `null` if it can.
 *
 * The order of the checks is the order a person would explain them in, so the
 * message a customer sees is the first real obstacle rather than an arbitrary
 * one.
 *
 * The exclusions are read exactly as the client wrote them: they are
 * exclusions from the **change-of-mind** return, not a waiver of the seller's
 * responsibility for what she sent. A made-to-order dress that arrives torn
 * comes back; the same dress that simply was not loved does not.
 */
export function blockerFor(
  line: LineReturnFacts,
  parcel: ParcelReturnFacts,
  reason: ReturnReason,
): ReturnBlocker | null {
  if (!parcel.deliveredAt) return ReturnBlocker.NotDelivered;

  const now = parcel.now ?? new Date();
  if (now > returnWindowClosesAt(parcel.deliveredAt, parcel.extraWindowDays)) {
    return ReturnBlocker.WindowClosed;
  }

  if (line.quantityClaimed >= line.quantityOrdered) {
    return ReturnBlocker.FullyReturned;
  }

  if (isFaultReason(reason)) return null;

  if (line.isMadeToOrder) return ReturnBlocker.MadeToOrder;
  if (!line.categoryAllowsReturns) return ReturnBlocker.CategoryExcluded;
  if (!line.offerAcceptsReturns) return ReturnBlocker.OfferExcluded;

  return null;
}

/** How many units of a line are still returnable. */
export function returnableQuantity(line: LineReturnFacts): number {
  return Math.max(0, line.quantityOrdered - line.quantityClaimed);
}

// ── Status sets ─────────────────────────────────────────────────────────

/**
 * A request in flight: the units it claims are reserved and the sub-order's
 * escrow is held open until it resolves.
 */
export const LIVE_RETURN_STATUSES: readonly ReturnStatus[] = [
  ReturnStatus.REQUESTED,
  ReturnStatus.APPROVED,
  ReturnStatus.IN_TRANSIT,
  ReturnStatus.RECEIVED,
];

/**
 * A request that settled: the units did come back and were paid for or
 * swapped, so they stay claimed for ever.
 */
export const SETTLED_RETURN_STATUSES: readonly ReturnStatus[] = [
  ReturnStatus.REFUNDED,
  ReturnStatus.EXCHANGED,
];

/**
 * A request that released its claim — refused or withdrawn, so it never took
 * anything and the units are on sale again.
 */
export const RELEASED_RETURN_STATUSES: readonly ReturnStatus[] = [
  ReturnStatus.REJECTED,
  ReturnStatus.CANCELLED,
];

/** The union of live and settled: everything that still claims its units. */
export const CLAIMING_RETURN_STATUSES: readonly ReturnStatus[] = [
  ...LIVE_RETURN_STATUSES,
  ...SETTLED_RETURN_STATUSES,
];
