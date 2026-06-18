import { Module } from '@nestjs/common';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { PaymentProviderRegistry } from './providers/payment-provider.registry';
import { PAYMENT_PROVIDER } from './providers/payment-provider.interface';
import {
  BemoProvider,
  CodProvider,
  ShamCashProvider,
  VisaProvider,
} from './providers/payment.providers';
import { CommissionsModule } from '../commissions/commissions.module';

@Module({
  imports: [CommissionsModule],
  controllers: [PaymentsController],
  providers: [
    PaymentsService,
    PaymentProviderRegistry,
    // Concrete providers. Add a new one here + to the factory below to support it.
    CodProvider,
    VisaProvider,
    ShamCashProvider,
    BemoProvider,
    {
      provide: PAYMENT_PROVIDER,
      useFactory: (
        cod: CodProvider,
        visa: VisaProvider,
        sham: ShamCashProvider,
        bemo: BemoProvider,
      ) => [cod, visa, sham, bemo],
      inject: [CodProvider, VisaProvider, ShamCashProvider, BemoProvider],
    },
  ],
  exports: [PaymentsService],
})
export class PaymentsModule {}
