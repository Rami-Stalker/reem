import { Injectable } from '@nestjs/common';
import { PaymentMethodType, PaymentStatus } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import {
  InitiateInput,
  InitiateResult,
  PaymentProvider,
  VerifyResult,
} from './payment-provider.interface';

const ref = (prefix: string) =>
  `${prefix}-${randomUUID().split('-')[0].toUpperCase()}`;

/**
 * Cash on Delivery — no gateway. Marked PENDING until the courier collects, at
 * which point delivery confirmation flips it to PAID.
 */
@Injectable()
export class CodProvider implements PaymentProvider {
  readonly method = PaymentMethodType.COD;
  readonly displayName = 'Cash on Delivery';
  readonly requiresOnlineConfirmation = false;

  async initiate(): Promise<InitiateResult> {
    return {
      status: PaymentStatus.PENDING,
      transactionRef: ref('COD'),
      message: 'Pay in cash when your order arrives',
    };
  }

  async verify(): Promise<VerifyResult> {
    return { status: PaymentStatus.PAID, message: 'Collected on delivery' };
  }
}

/**
 * Base for online gateways (sandbox). Real integrations replace `initiate`
 * (create a gateway session) and `verify` (check the gateway callback/status).
 */
abstract class OnlineGatewayProvider implements PaymentProvider {
  abstract readonly method: PaymentMethodType;
  abstract readonly displayName: string;
  protected abstract readonly prefix: string;
  readonly requiresOnlineConfirmation = true;

  async initiate(input: InitiateInput): Promise<InitiateResult> {
    const transactionRef = ref(this.prefix);
    return {
      status: PaymentStatus.PENDING,
      transactionRef,
      redirectUrl: `https://sandbox.reem.pay/${this.prefix.toLowerCase()}/${transactionRef}?amount=${input.amount}`,
      message: `Awaiting ${this.displayName} confirmation`,
    };
  }

  async verify(): Promise<VerifyResult> {
    // Sandbox: deterministically authorize. Swap for a real gateway lookup.
    return {
      status: PaymentStatus.PAID,
      providerRef: ref('AUTH'),
      message: 'Payment authorized',
    };
  }
}

@Injectable()
export class VisaProvider extends OnlineGatewayProvider {
  readonly method = PaymentMethodType.VISA;
  readonly displayName = 'Visa Card';
  protected readonly prefix = 'VISA';
}

@Injectable()
export class ShamCashProvider extends OnlineGatewayProvider {
  readonly method = PaymentMethodType.SHAM_CASH;
  readonly displayName = 'Sham Cash';
  protected readonly prefix = 'SHAM';
}

@Injectable()
export class BemoProvider extends OnlineGatewayProvider {
  readonly method = PaymentMethodType.BEMO;
  readonly displayName = 'Bemo Bank';
  protected readonly prefix = 'BEMO';
}
