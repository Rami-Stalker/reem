import { Module } from '@nestjs/common';

import { PrismaModule } from '../../../prisma/prisma.module';
import { InventoryReservationService } from './inventory-reservation.service';
import { SellerOrderWorkflowService } from './seller-order-workflow.service';

/**
 * The sub-order lifecycle, on its own.
 *
 * Deliberately tiny and dependency-free: orders, delivery, returns and the
 * seller's own screens all move parcels, and if this lived inside any one of
 * them the other three would need a circular import to reach it. Depending
 * only on Prisma keeps it underneath everything that uses it.
 */
@Module({
  imports: [PrismaModule],
  providers: [InventoryReservationService, SellerOrderWorkflowService],
  exports: [InventoryReservationService, SellerOrderWorkflowService],
})
export class OrderWorkflowModule {}
