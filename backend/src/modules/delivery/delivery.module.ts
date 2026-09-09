import { Module } from '@nestjs/common';
import { CommissionsModule } from '../commissions/commissions.module';
import { FinanceModule } from '../finance/finance.module';
import { OrderWorkflowModule } from '../orders/workflow/order-workflow.module';
import { CodTrustModule } from '../cod-trust/cod-trust.module';
import { DeliveryController } from './delivery.controller';
import { DeliveryService } from './delivery.service';
import { ShipmentsController } from './shipments.controller';
import { ShipmentsService } from './shipments.service';
import { DELIVERY_PROVIDER } from './providers/delivery-provider.interface';
import { DeliveryProviderRegistry } from './providers/delivery-provider.registry';
import { HttpDeliveryProvider } from './providers/http-delivery.provider';
import { InternalCourierProvider } from './providers/internal-courier.provider';
import { ProviderCredentialsService } from './providers/provider-credentials.service';
import { DeliveryAdminController } from './dispatch/delivery-admin.controller';
import { DeliveryAdminService } from './dispatch/delivery-admin.service';
import { DeliveryDispatchService } from './dispatch/delivery-dispatch.service';
import { DeliveryProviderBootstrap } from './dispatch/delivery-provider.bootstrap';
import { DeliveryWebhookController } from './dispatch/delivery-webhook.controller';
import { DeliveryWebhookService } from './dispatch/delivery-webhook.service';

/**
 * Shipping zones and quotes, the shipment lifecycle, and the integration with
 * the delivery companies that actually carry the parcels.
 *
 * Reem does not run a fleet: it hands a packed parcel to a carrier and reads
 * back what the carrier says. Everything carrier-shaped lives under
 * `providers/` (the adapters) and `dispatch/` (choosing one, calling it,
 * receiving its callbacks, and the admin desk that turns them on and off), and
 * nothing outside this module knows which company is carrying anything.
 *
 * **Adding a carrier**: implement `DeliveryProvider`, list the class in
 * `ADAPTERS` below, and create an account row naming its `code`. No change to
 * orders, seller commerce, returns, or the client.
 *
 * Depends on commissions because a delivery is what makes a sale
 * revenue-bearing, and on the order workflow because the same moment has to
 * land on the sub-order — which is what returns, escrow and reviews all read.
 */
const ADAPTERS = [InternalCourierProvider, HttpDeliveryProvider];

@Module({
  imports: [CommissionsModule, OrderWorkflowModule, FinanceModule, CodTrustModule],
  controllers: [
    DeliveryController,
    ShipmentsController,
    DeliveryWebhookController,
    DeliveryAdminController,
  ],
  providers: [
    DeliveryService,
    ShipmentsService,
    ProviderCredentialsService,
    ...ADAPTERS,
    {
      // One array of every adapter, so the registry is a constructor argument
      // rather than a file that has to be edited in two places.
      provide: DELIVERY_PROVIDER,
      useFactory: (...adapters: unknown[]) => adapters,
      inject: ADAPTERS,
    },
    DeliveryProviderRegistry,
    DeliveryDispatchService,
    DeliveryWebhookService,
    DeliveryAdminService,
    DeliveryProviderBootstrap,
  ],
  exports: [DeliveryService, ShipmentsService, DeliveryDispatchService],
})
export class DeliveryModule {}
