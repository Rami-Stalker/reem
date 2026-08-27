import { Module, forwardRef } from '@nestjs/common';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { CheckoutService } from './checkout.service';
import { OrdersRepository } from './orders.repository';
import { CartModule } from '../cart/cart.module';
import { PaymentsModule } from '../payments/payments.module';
import { DeliveryModule } from '../delivery/delivery.module';
import { RewardsModule } from '../rewards/rewards.module';
import { CommissionsModule } from '../commissions/commissions.module';
import { FinanceModule } from '../finance/finance.module';
import { PricingModule } from '../pricing/pricing.module';
import { OrderWorkflowModule } from './workflow/order-workflow.module';
import { InvoicesController } from './invoices.controller';
import { InvoicesService } from './invoices.service';

@Module({
  imports: [
    CartModule,
    // Payment confirmation calls back into CheckoutService.confirm() to fan the
    // sub-orders out, so the two modules reference each other.
    forwardRef(() => PaymentsModule),
    DeliveryModule,
    RewardsModule,
    CommissionsModule,
    PricingModule,
    OrderWorkflowModule,
    FinanceModule,
  ],
  controllers: [InvoicesController, OrdersController],
  providers: [InvoicesService, OrdersService, CheckoutService, OrdersRepository],
  // `OrdersService` is exported for `syncParentStatus`: the parent order's
  // status is a pure function of its children, and every module that moves a
  // sub-order has to re-derive it through the same code or the two drift.
  exports: [
    InvoicesService,
    OrdersService,
    CheckoutService,
    OrdersRepository,
    OrderWorkflowModule,
  ],
})
export class OrdersModule {}
