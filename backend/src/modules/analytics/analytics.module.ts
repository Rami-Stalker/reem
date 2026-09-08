import { Module } from '@nestjs/common';
import { AnalyticsController } from './analytics.controller';
import { AnalyticsService } from './analytics.service';
import { EconomicsController } from './economics.controller';
import { EconomicsService } from './economics.service';

@Module({
  controllers: [AnalyticsController, EconomicsController],
  providers: [AnalyticsService, EconomicsService],
  exports: [AnalyticsService, EconomicsService],
})
export class AnalyticsModule {}
