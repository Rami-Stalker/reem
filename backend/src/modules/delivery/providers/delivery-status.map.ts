import { DeliveryFailureReason, ShipmentStatus } from '@prisma/client';

/**
 * One vocabulary for where a parcel is.
 *
 * Every carrier has its own words — `ASSIGNED_TO_RIDER`, `en_route`, `3`,
 * `تم التسليم` — and the rest of Ohara must never learn any of them. A carrier's
 * word is mapped here, once, into the `ShipmentStatus` the platform already
 * speaks; the raw word is kept beside it on the dispatch row so support can
 * still answer "what did they actually say".
 *
 * The canonical ladder, which is the one the requirement names:
 *
 *   pending → assigned → picked_up → in_transit → out_for_delivery → delivered
 *
 * with `FAILED` (an attempt that did not land), `RETURNING`/`RETURNED` (coming
 * back to the seller) and `CANCELLED` off the side of it.
 */
export const CANONICAL_DELIVERY_STATUSES: readonly ShipmentStatus[] = [
  ShipmentStatus.CREATED,
  ShipmentStatus.ASSIGNED,
  ShipmentStatus.PICKED_UP,
  ShipmentStatus.IN_TRANSIT,
  ShipmentStatus.OUT_FOR_DELIVERY,
  ShipmentStatus.DELIVERED,
  ShipmentStatus.FAILED,
  ShipmentStatus.RETURNING,
  ShipmentStatus.RETURNED,
  ShipmentStatus.CANCELLED,
];

/**
 * The words carriers actually use, as they have been met in the wild.
 *
 * A carrier's own map (`config.statusMap`) is consulted first and wins; this
 * is the fallback so that a new integration is usually a base URL and a
 * credential rather than a table of synonyms. Keys are compared folded:
 * lower-cased, spaces and dashes turned into underscores.
 */
const DEFAULT_STATUS_WORDS: Readonly<Record<string, ShipmentStatus>> = {
  pending: ShipmentStatus.CREATED,
  created: ShipmentStatus.CREATED,
  new: ShipmentStatus.CREATED,
  waiting: ShipmentStatus.CREATED,
  registered: ShipmentStatus.CREATED,

  assigned: ShipmentStatus.ASSIGNED,
  accepted: ShipmentStatus.ASSIGNED,
  confirmed: ShipmentStatus.ASSIGNED,
  courier_assigned: ShipmentStatus.ASSIGNED,
  driver_assigned: ShipmentStatus.ASSIGNED,
  rider_assigned: ShipmentStatus.ASSIGNED,

  picked_up: ShipmentStatus.PICKED_UP,
  pickup: ShipmentStatus.PICKED_UP,
  collected: ShipmentStatus.PICKED_UP,
  picked: ShipmentStatus.PICKED_UP,

  in_transit: ShipmentStatus.IN_TRANSIT,
  transit: ShipmentStatus.IN_TRANSIT,
  shipped: ShipmentStatus.IN_TRANSIT,
  on_the_way: ShipmentStatus.IN_TRANSIT,
  at_hub: ShipmentStatus.IN_TRANSIT,
  in_warehouse: ShipmentStatus.IN_TRANSIT,

  out_for_delivery: ShipmentStatus.OUT_FOR_DELIVERY,
  outfordelivery: ShipmentStatus.OUT_FOR_DELIVERY,
  dispatched: ShipmentStatus.OUT_FOR_DELIVERY,
  last_mile: ShipmentStatus.OUT_FOR_DELIVERY,

  delivered: ShipmentStatus.DELIVERED,
  completed: ShipmentStatus.DELIVERED,
  success: ShipmentStatus.DELIVERED,
  done: ShipmentStatus.DELIVERED,

  failed: ShipmentStatus.FAILED,
  failure: ShipmentStatus.FAILED,
  attempt_failed: ShipmentStatus.FAILED,
  undelivered: ShipmentStatus.FAILED,
  postponed: ShipmentStatus.FAILED,
  rescheduled: ShipmentStatus.FAILED,
  rejected: ShipmentStatus.FAILED,
  refused: ShipmentStatus.FAILED,

  returning: ShipmentStatus.RETURNING,
  return_in_transit: ShipmentStatus.RETURNING,
  returning_to_sender: ShipmentStatus.RETURNING,

  returned: ShipmentStatus.RETURNED,
  returned_to_sender: ShipmentStatus.RETURNED,

  cancelled: ShipmentStatus.CANCELLED,
  canceled: ShipmentStatus.CANCELLED,
  voided: ShipmentStatus.CANCELLED,
};

/** Reasons carriers give for a failed attempt, mapped onto Q37's list. */
const DEFAULT_FAILURE_WORDS: Readonly<Record<string, DeliveryFailureReason>> = {
  no_answer: DeliveryFailureReason.NO_ANSWER,
  not_answering: DeliveryFailureReason.NO_ANSWER,
  unreachable: DeliveryFailureReason.NO_ANSWER,
  customer_not_available: DeliveryFailureReason.NO_ANSWER,

  wrong_address: DeliveryFailureReason.WRONG_ADDRESS,
  address_not_found: DeliveryFailureReason.WRONG_ADDRESS,
  incomplete_address: DeliveryFailureReason.WRONG_ADDRESS,

  refused: DeliveryFailureReason.CUSTOMER_REFUSED,
  rejected: DeliveryFailureReason.CUSTOMER_REFUSED,
  customer_refused: DeliveryFailureReason.CUSTOMER_REFUSED,
  returned_by_customer: DeliveryFailureReason.CUSTOMER_REFUSED,
};

export function foldStatusWord(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[\s\-.]+/g, '_');
}

/**
 * A carrier's word for a status, in Ohara's vocabulary.
 *
 * Returns null rather than guessing when nothing matches — an unknown status
 * is recorded on the dispatch and left for a human, because moving a parcel on
 * a guess is how a customer gets told her order arrived when it did not.
 */
export function toCanonicalStatus(
  raw: string | null | undefined,
  overrides?: Record<string, string> | null,
): ShipmentStatus | null {
  if (!raw) return null;
  const folded = foldStatusWord(String(raw));

  if (overrides) {
    for (const [word, mapped] of Object.entries(overrides)) {
      if (foldStatusWord(word) === folded) {
        const candidate = String(mapped).toUpperCase() as ShipmentStatus;
        return CANONICAL_DELIVERY_STATUSES.includes(candidate)
          ? candidate
          : null;
      }
    }
  }

  const direct = folded.toUpperCase() as ShipmentStatus;
  if (CANONICAL_DELIVERY_STATUSES.includes(direct)) return direct;

  return DEFAULT_STATUS_WORDS[folded] ?? null;
}

export function toFailureReason(
  raw: string | null | undefined,
  overrides?: Record<string, string> | null,
): DeliveryFailureReason | null {
  if (!raw) return null;
  const folded = foldStatusWord(String(raw));

  if (overrides) {
    for (const [word, mapped] of Object.entries(overrides)) {
      if (foldStatusWord(word) === folded) {
        const candidate = String(mapped).toUpperCase() as DeliveryFailureReason;
        return Object.values(DeliveryFailureReason).includes(candidate)
          ? candidate
          : null;
      }
    }
  }

  const direct = folded.toUpperCase() as DeliveryFailureReason;
  if (Object.values(DeliveryFailureReason).includes(direct)) return direct;

  return DEFAULT_FAILURE_WORDS[folded] ?? DeliveryFailureReason.OTHER;
}

/**
 * Whether a parcel may move from one canonical status to another.
 *
 * Carriers send events out of order — a webhook queue retried after an outage
 * arrives newest-first as often as not — so the orchestrator asks this before
 * touching an order. Going backwards is not an error; it is simply ignored.
 */
const RANK: Readonly<Record<ShipmentStatus, number>> = {
  [ShipmentStatus.CREATED]: 0,
  [ShipmentStatus.ASSIGNED]: 1,
  [ShipmentStatus.PICKED_UP]: 2,
  [ShipmentStatus.IN_TRANSIT]: 3,
  [ShipmentStatus.OUT_FOR_DELIVERY]: 4,
  [ShipmentStatus.FAILED]: 5,
  [ShipmentStatus.RETURNING]: 6,
  [ShipmentStatus.DELIVERED]: 7,
  [ShipmentStatus.RETURNED]: 7,
  [ShipmentStatus.CANCELLED]: 7,
};

const TERMINAL: readonly ShipmentStatus[] = [
  ShipmentStatus.DELIVERED,
  ShipmentStatus.RETURNED,
  ShipmentStatus.CANCELLED,
];

export function isTerminalDeliveryStatus(status: ShipmentStatus): boolean {
  return TERMINAL.includes(status);
}

export function isForwardDeliveryStatus(
  from: ShipmentStatus,
  to: ShipmentStatus,
): boolean {
  if (from === to) return false;
  if (isTerminalDeliveryStatus(from)) return false;
  // A failed attempt may be retried, so FAILED → OUT_FOR_DELIVERY is forward
  // even though the rank says otherwise.
  if (from === ShipmentStatus.FAILED) return true;
  return RANK[to] > RANK[from];
}
