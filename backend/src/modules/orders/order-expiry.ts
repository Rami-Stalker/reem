import { PaymentMethodType } from '@prisma/client';

import { PaymentRail, railOf } from '../../common/payments/payment-rails';

/**
 * How long an unpaid order may hold its stock.
 *
 * **Why this is a policy and not one number.** Stock leaves the shelf inside
 * the checkout transaction, so every minute an unpaid order lives is a minute
 * another woman cannot buy that garment. That argues for a short deadline.
 * But a woman paying by bank transfer or hawala has to physically go
 * somewhere, and Q51 lets her come back afterwards to submit the reference —
 * cancelling her order while she is standing at the exchange office is worse
 * than holding one dress for a day.
 *
 * So the deadline is decided by what the rail actually asks of her, which is
 * already named once in `payment-rails.ts` rather than guessed here.
 *
 * **Cash is the short one, and that is not a contradiction.** A cash order is
 * confirmed the instant it is placed; it reaches `PENDING_PAYMENT` and stays
 * there only if something broke between creating the order and confirming it.
 * An hour is a generous allowance for a crash. The one cash case that
 * legitimately waits — an order held for a confirmation code — is excluded
 * from the sweep entirely, because `CodTrustScheduler` owns that hold and
 * releases it on its own thirty-minute clock. Two sweeps racing to cancel the
 * same order would each write a timeline entry for it.
 */
const TTL_MINUTES: Readonly<Record<PaymentRail, number>> = Object.freeze({
  /** Confirmed on placement. Anything still pending is a crash. */
  [PaymentRail.CASH]: 60,
  /** Debited on placement, same reasoning as cash. */
  [PaymentRail.WALLET]: 60,
  /** A gateway page she opened and did not finish. */
  [PaymentRail.ONLINE]: 60,
  /** She has to go to a bank or an exchange office, and may come back. */
  [PaymentRail.MANUAL]: 72 * 60,
});

/** The deadline to stamp on an order paid by this method. */
export function expiryFor(method: PaymentMethodType, placedAt: Date): Date {
  const minutes = TTL_MINUTES[railOf(method)];
  return new Date(placedAt.getTime() + minutes * 60_000);
}

/** Exposed for the tests, and for an ops screen that explains the deadline. */
export function expiryMinutesFor(method: PaymentMethodType): number {
  return TTL_MINUTES[railOf(method)];
}
