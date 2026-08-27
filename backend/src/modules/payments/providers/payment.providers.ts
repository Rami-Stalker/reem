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
 * Q140 P2 — the platform launches on cash and wires the electronic rails in as
 * merchant accounts come through. Every method the client listed (Q51 P1) has a
 * provider here so the flow exists; the online ones are sandbox stubs until a
 * real gateway is available.
 */

/** Cash on delivery — no gateway. Flips to PAID when the courier collects. */
@Injectable()
export class CodProvider implements PaymentProvider {
  readonly method = PaymentMethodType.COD;
  readonly displayName = 'الدفع عند الاستلام';
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

/** Q51 P1 — "الدفع لمندوب الشحن": collected by the courier, reconciled daily. */
@Injectable()
export class CourierCollectProvider implements PaymentProvider {
  readonly method = PaymentMethodType.COURIER_COLLECT;
  readonly displayName = 'الدفع لمندوب الشحن';
  readonly requiresOnlineConfirmation = false;

  async initiate(): Promise<InitiateResult> {
    return {
      status: PaymentStatus.PENDING,
      transactionRef: ref('CRR'),
      message: 'The courier will collect payment on handover',
    };
  }

  async verify(): Promise<VerifyResult> {
    return { status: PaymentStatus.PAID, message: 'Collected by the courier' };
  }
}

/**
 * Offline rails — a bank transfer or an internal hawala (الفؤاد / الهرم /
 * القدموس). No gateway exists, so the customer submits a reference and an
 * operator confirms it; the payment stays PENDING until then.
 */
abstract class ManualTransferProvider implements PaymentProvider {
  abstract readonly method: PaymentMethodType;
  abstract readonly displayName: string;
  protected abstract readonly prefix: string;
  readonly requiresOnlineConfirmation = true;

  async initiate(): Promise<InitiateResult> {
    return {
      status: PaymentStatus.PENDING,
      transactionRef: ref(this.prefix),
      message: `Send the amount and submit your ${this.displayName} reference`,
    };
  }

  /** Confirmation is an operator action, never an automatic pass. */
  async verify(): Promise<VerifyResult> {
    return {
      status: PaymentStatus.PENDING,
      message: 'Awaiting finance confirmation of the transfer',
    };
  }
}

/** Base for real online gateways (sandbox until a merchant account exists). */
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
      // The amount stays out of the query string — it is looked up server-side
      // from the payment row rather than trusted from the URL.
      redirectUrl: `https://sandbox.reem.pay/${this.prefix.toLowerCase()}/${transactionRef}`,
      message: `Awaiting ${this.displayName} confirmation for ${input.orderNumber}`,
    };
  }

  async verify(): Promise<VerifyResult> {
    return {
      status: PaymentStatus.PAID,
      providerRef: ref('AUTH'),
      message: 'Payment authorized',
    };
  }
}

@Injectable()
export class SyriatelCashProvider extends OnlineGatewayProvider {
  readonly method = PaymentMethodType.SYRIATEL_CASH;
  readonly displayName = 'سيرياتيل كاش';
  protected readonly prefix = 'SYR';
}

@Injectable()
export class MtnCashProvider extends OnlineGatewayProvider {
  readonly method = PaymentMethodType.MTN_CASH;
  readonly displayName = 'MTN كاش';
  protected readonly prefix = 'MTN';
}

@Injectable()
export class ShamCashProvider extends OnlineGatewayProvider {
  readonly method = PaymentMethodType.SHAM_CASH;
  readonly displayName = 'شام كاش';
  protected readonly prefix = 'SHAM';
}

@Injectable()
export class BankCardProvider extends OnlineGatewayProvider {
  readonly method = PaymentMethodType.BANK_CARD;
  readonly displayName = 'بطاقة بنكية';
  protected readonly prefix = 'CARD';
}

@Injectable()
export class BankTransferProvider extends ManualTransferProvider {
  readonly method = PaymentMethodType.BANK_TRANSFER;
  readonly displayName = 'تحويل بنكي';
  protected readonly prefix = 'BANK';
}

@Injectable()
export class HawalaProvider extends ManualTransferProvider {
  readonly method = PaymentMethodType.HAWALA;
  readonly displayName = 'حوالة داخلية';
  protected readonly prefix = 'HWL';
}

/** Q54 P1 — paying from the customer's platform wallet balance. */
@Injectable()
export class PlatformWalletProvider implements PaymentProvider {
  readonly method = PaymentMethodType.PLATFORM_WALLET;
  readonly displayName = 'محفظة المنصة';
  readonly requiresOnlineConfirmation = false;

  async initiate(): Promise<InitiateResult> {
    return {
      status: PaymentStatus.PAID,
      transactionRef: ref('WLT'),
      message: 'Paid from your wallet balance',
    };
  }

  async verify(): Promise<VerifyResult> {
    return { status: PaymentStatus.PAID, message: 'Wallet debited' };
  }
}
