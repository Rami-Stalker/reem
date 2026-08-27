import { Module } from '@nestjs/common';
import { ExchangeRateService } from './exchange-rate.service';
import { ExchangeRateSyncService } from './exchange-rate-sync.service';

/**
 * Currency and rate resolution. Imported by every module that has to turn a
 * seller's quoted price into what the customer is charged.
 */
@Module({
  providers: [ExchangeRateService, ExchangeRateSyncService],
  exports: [ExchangeRateService, ExchangeRateSyncService],
})
export class PricingModule {}
