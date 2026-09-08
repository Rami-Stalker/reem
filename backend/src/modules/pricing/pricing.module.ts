import { Module } from '@nestjs/common';
import { ExchangeRateService } from './exchange-rate.service';
import { ExchangeRateSyncService } from './exchange-rate-sync.service';
import { FlashSalesAdminController } from './flash-sales.admin.controller';
import { FlashSalesController } from './flash-sales.controller';
import { FlashSalesService } from './flash-sales.service';

/**
 * Currency and rate resolution. Imported by every module that has to turn a
 * seller's quoted price into what the customer is charged.
 */
@Module({
  controllers: [FlashSalesController, FlashSalesAdminController],
  providers: [ExchangeRateService, ExchangeRateSyncService, FlashSalesService],
  exports: [ExchangeRateService, ExchangeRateSyncService, FlashSalesService],
})
export class PricingModule {}
