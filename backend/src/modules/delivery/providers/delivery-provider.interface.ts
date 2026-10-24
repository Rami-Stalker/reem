import {
  Currency,
  DeliveryFailureReason,
  DeliveryProviderAccount,
  ShipmentStatus,
} from '@prisma/client';

/**
 * The contract every delivery company implements.
 *
 * Ohara does not run drivers. It owns the order, the money and the customer's
 * expectations; a carrier owns the journey. Everything the platform needs from
 * a carrier is on this interface, and nothing else in the codebase knows which
 * carrier it is talking to — which is what makes adding a second one a class
 * and a row rather than a change to the order system.
 *
 * Three rules the adapters must keep:
 *
 * **Idempotency is the caller's, honoured by the adapter.** `createDelivery`
 * is given a key derived from the parcel; a carrier that supports an
 * idempotency header must send it, and one that does not must be safe to call
 * twice (the orchestrator will not call it twice for the same parcel, but a
 * crash between the HTTP call and the database write is not preventable —
 * only recoverable).
 *
 * **Nothing here throws for a business answer.** "This address is out of our
 * coverage" is a result, not an exception; an exception means the call itself
 * failed and may be retried.
 *
 * **An adapter never speaks the carrier's status vocabulary outwards.** It maps
 * to `ShipmentStatus`, the one lifecycle the whole platform reads, and keeps
 * the carrier's own word beside it for support.
 */
export const DELIVERY_PROVIDER = Symbol('DELIVERY_PROVIDER');

/** Where the parcel is collected from. */
export interface DeliveryAddress {
  name: string;
  phone: string;
  governorate: string;
  city: string;
  district?: string | null;
  addressLine: string;
  landmark?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  notes?: string | null;
}

export interface CreateDeliveryInput {
  /** Ohara's own reference. Sent to the carrier so support can match records. */
  reference: string;
  /** Stable per parcel — the same value on every retry of the same dispatch. */
  idempotencyKey: string;
  pickup: DeliveryAddress;
  dropoff: DeliveryAddress;
  /** Cash to collect at the door. Absent on a prepaid parcel. */
  codAmount?: string | null;
  currency: Currency;
  /** Declared value, for carriers that insure or cap. */
  declaredValue?: string | null;
  itemCount: number;
  weightGrams?: number | null;
  isExpress: boolean;
  scheduledFor?: Date | null;
  notes?: string | null;
}

export interface CreateDeliveryResult {
  /** The carrier's id for this delivery. Required — nothing can be tracked without it. */
  externalDeliveryId: string;
  trackingNumber?: string | null;
  trackingUrl?: string | null;
  labelUrl?: string | null;
  status: ShipmentStatus;
  providerStatus?: string | null;
  fee?: { amount: string; currency: Currency } | null;
  /**
   * For the in-house fleet only: which `Courier` row is carrying this parcel.
   *
   * The platform's own riders are modelled as one more provider, and their
   * "delivery id" is the parcel's reference like anybody else's — this is how
   * the one field that genuinely differs is passed without a second code path.
   */
  internalCourierId?: string | null;
  /** Anything the carrier said that support might need. Never a credential. */
  raw?: unknown;
}

export interface CancelDeliveryInput {
  externalDeliveryId: string;
  reason?: string;
}

export interface DeliveryStatusResult {
  status: ShipmentStatus;
  providerStatus?: string | null;
  occurredAt?: Date | null;
  failureReason?: DeliveryFailureReason | null;
  failureNote?: string | null;
  /** Cash the carrier says it collected, where the carrier reports it. */
  collectedAmount?: string | null;
  trackingNumber?: string | null;
  raw?: unknown;
}

export interface TrackingCheckpoint {
  status: ShipmentStatus;
  providerStatus?: string | null;
  note?: string | null;
  at: Date;
}

export interface TrackingResult {
  status: ShipmentStatus;
  trackingNumber?: string | null;
  trackingUrl?: string | null;
  estimatedDeliveryAt?: Date | null;
  checkpoints: TrackingCheckpoint[];
}

export interface QuoteInput {
  pickup: Pick<DeliveryAddress, 'governorate' | 'city' | 'district'>;
  dropoff: Pick<DeliveryAddress, 'governorate' | 'city' | 'district'>;
  currency: Currency;
  isExpress: boolean;
  declaredValue?: string | null;
  weightGrams?: number | null;
}

export interface QuoteResult {
  amount: string;
  currency: Currency;
  /** How long the carrier stands behind this price, where it says. */
  expiresAt?: Date | null;
  etaMinutes?: number | null;
}

/** One normalised event out of a carrier's callback. */
export interface DeliveryWebhookEventInput {
  /** The carrier's event id, where it sends one. Used to ignore redeliveries. */
  externalEventId?: string | null;
  externalDeliveryId: string;
  status: ShipmentStatus;
  providerStatus?: string | null;
  occurredAt?: Date | null;
  failureReason?: DeliveryFailureReason | null;
  failureNote?: string | null;
  collectedAmount?: string | null;
  trackingNumber?: string | null;
}

export interface WebhookRequest {
  /** The exact bytes the carrier sent — signatures are over these, not over re-serialised JSON. */
  rawBody: Buffer | undefined;
  headers: Record<string, string | string[] | undefined>;
  body: unknown;
}

export interface WebhookVerdict {
  signatureValid: boolean;
  events: DeliveryWebhookEventInput[];
  /** Set when the payload could not be understood; recorded, never thrown away. */
  error?: string;
}

/**
 * A carrier, as the platform sees it.
 *
 * `account` is passed on every call rather than injected once: the same
 * adapter class serves every account of its kind — two contracts with the same
 * company, a sandbox beside production — and none of them may see another's
 * configuration or credentials.
 */
export interface DeliveryProvider {
  /** Matches `DeliveryProviderAccount.code`. */
  readonly code: string;
  readonly displayName: string;

  createDelivery(
    account: DeliveryProviderAccount,
    input: CreateDeliveryInput,
  ): Promise<CreateDeliveryResult>;

  cancelDelivery(
    account: DeliveryProviderAccount,
    input: CancelDeliveryInput,
  ): Promise<void>;

  getDeliveryStatus(
    account: DeliveryProviderAccount,
    externalDeliveryId: string,
  ): Promise<DeliveryStatusResult>;

  getTracking(
    account: DeliveryProviderAccount,
    externalDeliveryId: string,
  ): Promise<TrackingResult>;

  /**
   * Optional: only carriers that price by API implement it. The platform falls
   * back to its own zone table (`DeliveryService.quote`) when this is absent,
   * so a checkout never fails because a carrier's pricing endpoint is down.
   */
  calculateDeliveryFee?(
    account: DeliveryProviderAccount,
    input: QuoteInput,
  ): Promise<QuoteResult>;

  /**
   * Verifies and parses a callback. Never applies anything: the orchestrator
   * decides what a status means for the order, and the adapter only says what
   * the carrier said.
   */
  handleWebhook(
    account: DeliveryProviderAccount,
    request: WebhookRequest,
  ): Promise<WebhookVerdict>;
}
