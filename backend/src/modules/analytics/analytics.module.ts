import { Module } from '@nestjs/common';
import { AnalyticsController } from './analytics.controller';
import { AnalyticsService } from './analytics.service';
import { EconomicsController } from './economics.controller';
import { EconomicsService } from './economics.service';
import { OrderPlacedListener } from './order-placed.listener';

@Module({
  controllers: [AnalyticsController, EconomicsController],
  providers: [AnalyticsService, EconomicsService, OrderPlacedListener],
  exports: [AnalyticsService, EconomicsService],
})
export class AnalyticsModule {}
