import { Module, forwardRef } from '@nestjs/common';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { PaymentProviderRegistry } from './providers/payment-provider.registry';
import { PAYMENT_PROVIDER } from './providers/payment-provider.interface';
import {
  BankCardProvider,
  BankTransferProvider,
  CodProvider,
  CourierCollectProvider,
  HawalaProvider,
  MtnCashProvider,
  PlatformWalletProvider,
  ShamCashProvider,
  SyriatelCashProvider,
} from './providers/payment.providers';
import { OrdersModule } from '../orders/orders.module';
import { LedgerModule } from '../ledger/ledger.module';
import { FinanceModule } from '../finance/finance.module';

const PROVIDERS = [
  CodProvider,
  CourierCollectProvider,
  SyriatelCashProvider,
  MtnCashProvider,
  ShamCashProvider,
  BankCardProvider,
  BankTransferProvider,
  HawalaProvider,
  PlatformWalletProvider,
] as const;

@Module({
  imports: [
    LedgerModule,
    forwardRef(() => OrdersModule),
    forwardRef(() => FinanceModule),
  ],
  controllers: [PaymentsController],
  providers: [
    PaymentsService,
    PaymentProviderRegistry,
    // Concrete providers. Adding a rail means adding its class to PROVIDERS —
    // the factory below picks it up without a second edit.
    ...PROVIDERS,
    {
      provide: PAYMENT_PROVIDER,
      useFactory: (...providers: InstanceType<(typeof PROVIDERS)[number]>[]) =>
        providers,
      inject: [...PROVIDERS],
    },
  ],
  exports: [PaymentsService],
})
export class PaymentsModule {}
