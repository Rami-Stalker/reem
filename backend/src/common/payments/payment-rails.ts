import { PaymentMethodType } from '@prisma/client';

/**
 * What a payment method asks of the customer *after* the order is placed.
 *
 * The app needs this to know which order still needs something from her, and
 * the client used to guess it — `payment.method != 'cod'` — which put a
 * «تأكيد الدفع» button on a wallet payment that was already settled and none
 * on a courier-collect one that also needs nothing. The rails are named here
 * once, and both the serializer and the payment providers read them.
 */
export enum PaymentRail {
  /** Money changes hands at the door. Nothing to do in the app. */
  CASH = 'cash',

  /** Debited from her platform balance the moment the order is placed. */
  WALLET = 'wallet',

  /** A gateway she is sent to, and which answers back. */
  ONLINE = 'online',

  /** She transfers the money herself and gives us the reference. */
  MANUAL = 'manual',
}

const RAILS: Readonly<Record<PaymentMethodType, PaymentRail>> = Object.freeze({
  [PaymentMethodType.COD]: PaymentRail.CASH,
  [PaymentMethodType.COURIER_COLLECT]: PaymentRail.CASH,
  [PaymentMethodType.PLATFORM_WALLET]: PaymentRail.WALLET,
  [PaymentMethodType.SYRIATEL_CASH]: PaymentRail.ONLINE,
  [PaymentMethodType.MTN_CASH]: PaymentRail.ONLINE,
  [PaymentMethodType.SHAM_CASH]: PaymentRail.ONLINE,
  [PaymentMethodType.BANK_CARD]: PaymentRail.ONLINE,
  [PaymentMethodType.BANK_TRANSFER]: PaymentRail.MANUAL,
  [PaymentMethodType.HAWALA]: PaymentRail.MANUAL,
});

export function railOf(method: PaymentMethodType): PaymentRail {
  return RAILS[method];
}

/** True when she still has something to do before the money arrives. */
export function needsCustomerAction(method: PaymentMethodType): boolean {
  const rail = railOf(method);
  return rail === PaymentRail.ONLINE || rail === PaymentRail.MANUAL;
}
