import { Module } from '@nestjs/common';

import { PrismaModule } from '../../prisma/prisma.module';
import { CommissionsModule } from '../commissions/commissions.module';
import { FinanceModule } from '../finance/finance.module';
import { OrderWorkflowModule } from '../orders/workflow/order-workflow.module';
import { SellerCommerceController } from './seller-commerce.controller';
import { SellerCommerceService } from './seller-commerce.service';
import { SellerOrdersController } from './seller-orders.controller';
import { SellerOrdersService } from './seller-orders.service';

/**
 * The seller's own commerce surface: the figures she reads and the orders she
 * works. The two belong together — the dashboard's «طلبات بانتظار التأكيد»
 * counts the very queue the other half lets her clear.
 */
@Module({
  imports: [
    PrismaModule,
    CommissionsModule,
    OrderWorkflowModule,
    FinanceModule,
  ],
  controllers: [SellerCommerceController, SellerOrdersController],
  providers: [SellerCommerceService, SellerOrdersService],
  exports: [SellerOrdersService],
})
export class SellerCommerceModule {}
