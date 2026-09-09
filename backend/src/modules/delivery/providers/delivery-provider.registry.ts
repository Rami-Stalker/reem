import { Inject, Injectable, NotFoundException } from '@nestjs/common';

import {
  DELIVERY_PROVIDER,
  DeliveryProvider,
} from './delivery-provider.interface';

/**
 * Every adapter the build knows how to be, keyed by the code an account names.
 *
 * Adding a carrier is: write a class implementing `DeliveryProvider`, list it
 * in `DeliveryModule`, and create an account row that names its `code`. No
 * call site in orders, seller commerce, returns or the client changes.
 *
 * An account whose adapter is missing is a configuration error worth shouting
 * about — it means a row survived the code that served it — so the lookup
 * refuses rather than silently falling back to another carrier.
 */
@Injectable()
export class DeliveryProviderRegistry {
  private readonly byCode: Map<string, DeliveryProvider>;

  constructor(
    @Inject(DELIVERY_PROVIDER) providers: DeliveryProvider[],
  ) {
    this.byCode = new Map(providers.map((provider) => [provider.code, provider]));
  }

  get(code: string): DeliveryProvider {
    const provider = this.byCode.get(code);
    if (!provider) {
      throw new NotFoundException(
        `No delivery adapter is registered for "${code}"`,
      );
    }
    return provider;
  }

  has(code: string): boolean {
    return this.byCode.has(code);
  }

  list(): DeliveryProvider[] {
    return [...this.byCode.values()];
  }
}
