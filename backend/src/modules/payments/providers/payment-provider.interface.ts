import { PaymentMethodType, PaymentStatus } from '@prisma/client';

export const PAYMENT_PROVIDER = Symbol('PAYMENT_PROVIDER');

export interface InitiateInput {
  amount: number;
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
 * Strategy contract every payment method implements. Adding a new provider is a
 * matter of implementing this interface and registering it under the
 * PAYMENT_PROVIDER multi-token — nothing else in the codebase changes.
 */
export interface PaymentProvider {
  readonly method: PaymentMethodType;
  readonly displayName: string;
  /** True for gateways that need an async confirmation step (vs. COD). */
  readonly requiresOnlineConfirmation: boolean;

  initiate(input: InitiateInput): Promise<InitiateResult>;
  verify(transactionRef: string): Promise<VerifyResult>;
}
