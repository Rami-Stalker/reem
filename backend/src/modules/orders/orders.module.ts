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
import { CodTrustModule } from '../cod-trust/cod-trust.module';
import { MarketModule } from '../market/market.module';
import { CodTrustScheduler } from '../cod-trust/cod-trust.scheduler';
import { InvoicesController } from './invoices.controller';
import { InvoicesService } from './invoices.service';
import { OrdersScheduler } from './orders.scheduler';

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
    CodTrustModule,
    // Drops record a conversion from the checkout that produced it. The
    // dependency goes this way and only this way: the market layer never
    // reaches into orders.
    MarketModule,
  ],
  controllers: [InvoicesController, OrdersController],
  providers: [
    InvoicesService,
    OrdersService,
    CheckoutService,
    OrdersRepository,
    // Lives in `cod-trust/` but is registered here: it cancels orders, and the
    // trust engine is not allowed to depend on the module that owns them.
    CodTrustScheduler,
    // The backstop beneath it: every other way an order can be left unpaid.
    OrdersScheduler,
  ],
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
