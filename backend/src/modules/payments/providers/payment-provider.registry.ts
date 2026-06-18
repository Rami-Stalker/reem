import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import { PaymentMethodType } from '@prisma/client';
import {
  PAYMENT_PROVIDER,
  PaymentProvider,
} from './payment-provider.interface';

@Injectable()
export class PaymentProviderRegistry {
  private readonly byMethod = new Map<PaymentMethodType, PaymentProvider>();

  constructor(
    @Inject(PAYMENT_PROVIDER) providers: PaymentProvider[],
  ) {
    for (const provider of providers) {
      this.byMethod.set(provider.method, provider);
    }
  }

  get(method: PaymentMethodType): PaymentProvider {
    const provider = this.byMethod.get(method);
    if (!provider) {
      throw new BadRequestException(`Unsupported payment method: ${method}`);
    }
    return provider;
  }

  /** Catalogue of supported methods for the payment-selection screen. */
  list() {
    return [...this.byMethod.values()].map((p) => ({
      method: p.method.toLowerCase(),
      label: p.displayName,
      requires_online_confirmation: p.requiresOnlineConfirmation,
    }));
  }
}
