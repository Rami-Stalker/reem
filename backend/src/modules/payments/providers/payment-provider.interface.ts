import { Currency, PaymentMethodType, PaymentStatus } from '@prisma/client';

export const PAYMENT_PROVIDER = Symbol('PAYMENT_PROVIDER');

export interface InitiateInput {
  /** Decimal string — never a float, and never without its currency. */
  amount: string;
  currency: Currency;
  orderNumber: string;
}

export interface InitiateResult {
  status: PaymentStatus;
  transactionRef: string;
  providerRef?: string;
  redirectUrl?: string;
  message?: string;
}

export interface VerifyResult {
  status: PaymentStatus;
  providerRef?: string;
  message?: string;
}

/**
 * Strategy contract every payment method implements. Adding a rail is a matter
 * of implementing this interface and listing the class in PaymentsModule —
 * nothing else in the codebase changes.
 */
export interface PaymentProvider {
  readonly method: PaymentMethodType;
  readonly displayName: string;
  /** True for rails needing an async confirmation step (vs. cash). */
  readonly requiresOnlineConfirmation: boolean;

  /**
   * Whether this provider's `verify` can *establish* that money moved, rather
   * than merely restate what the platform already assumed.
   *
   * False for every rail today, and that is the honest answer: cash and
   * courier-collect settle when a courier records a collection, and the
   * electronic rails are sandbox stubs with no merchant account behind them.
   * A provider may set this only once its `verify` authenticates the gateway's
   * own answer — a signed callback, a server-to-server lookup — because
   * `verify` is reachable by the customer who owns the payment, and a rail
   * that cannot tell "paid" from "asked to be marked paid" hands her the goods
   * for free.
   */
  readonly attestsSettlement: boolean;

  initiate(input: InitiateInput): Promise<InitiateResult>;
  verify(transactionRef: string): Promise<VerifyResult>;
}
