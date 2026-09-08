import { Module } from '@nestjs/common';
import { CustomerFactsService } from './customer-facts.service';
import { CustomerIntelligenceAdminController } from './customer-intelligence.admin.controller';
import { CustomerIntelligenceService } from './customer-intelligence.service';

/**
 * What the platform knows about each customer.
 *
 * Exported, because almost everything downstream wants it: win-back targeting
 * by churn risk rather than by a calendar, notification scheduling by the hour
 * she is actually awake, offers weighted by what she is worth. Nothing here
 * sends anything or changes anything a customer can see — it only answers
 * questions.
 */
@Module({
  controllers: [CustomerIntelligenceAdminController],
  providers: [CustomerIntelligenceService, CustomerFactsService],
  exports: [CustomerIntelligenceService, CustomerFactsService],
})
export class CustomerIntelligenceModule {}
