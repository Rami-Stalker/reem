import { Module } from '@nestjs/common';
import { CommissionsModule } from '../commissions/commissions.module';
import { FinanceModule } from '../finance/finance.module';
import { OrderWorkflowModule } from '../orders/workflow/order-workflow.module';
import { DeliveryController } from './delivery.controller';
import { DeliveryService } from './delivery.service';
import { ShipmentsController } from './shipments.controller';
import { ShipmentsService } from './shipments.service';

/**
 * Shipping zones and quotes, plus the shipment lifecycle and the courier's
 * own screens (Q55, Q63 P1).
 *
 * Depends on commissions because a delivery is what makes a sale
 * revenue-bearing — settling at that moment is what puts cash-on-delivery
 * money into the right courier's in-transit account — and on the order
 * workflow because the same moment has to land on the sub-order, which is
 * what returns, escrow and reviews all read.
 */
@Module({
  imports: [CommissionsModule, OrderWorkflowModule, FinanceModule],
  controllers: [DeliveryController, ShipmentsController],
  providers: [DeliveryService, ShipmentsService],
  exports: [DeliveryService, ShipmentsService],
})
export class DeliveryModule {}
