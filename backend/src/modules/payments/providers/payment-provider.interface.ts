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

  initiate(input: InitiateInput): Promise<InitiateResult>;
  verify(transactionRef: string): Promise<VerifyResult>;
}
