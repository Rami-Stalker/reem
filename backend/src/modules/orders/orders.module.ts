import { Module } from '@nestjs/common';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { CheckoutService } from './checkout.service';
import { OrdersRepository } from './orders.repository';
import { CartModule } from '../cart/cart.module';
import { PaymentsModule } from '../payments/payments.module';
import { DeliveryModule } from '../delivery/delivery.module';
import { RewardsModule } from '../rewards/rewards.module';
import { CommissionsModule } from '../commissions/commissions.module';

@Module({
  imports: [CartModule, PaymentsModule, DeliveryModule, RewardsModule, CommissionsModule],
  controllers: [OrdersController],
  providers: [OrdersService, CheckoutService, OrdersRepository],
})
export class OrdersModule {}
