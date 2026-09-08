import { Module } from '@nestjs/common';
import { AnalyticsModule } from '../analytics/analytics.module';
import { CustomerIntelligenceModule } from '../customer-intelligence/customer-intelligence.module';
import { LifecycleModule } from '../lifecycle/lifecycle.module';
import { RankingModule } from '../ranking/ranking.module';
import { TrustModule } from '../trust/trust.module';
import { ProductsModule } from '../products/products.module';
import { SellerCommerceModule } from '../seller-commerce/seller-commerce.module';
import { AdminIntelligenceController } from './admin-intelligence.controller';
import { AdminIntelligenceService } from './admin-intelligence.service';
import { IntelligenceScheduler } from './intelligence.scheduler';

/**
 * Decision support for the console.
 *
 * Imports rather than reimplements. Every figure comes from the system that
 * owns it — economics, the trust queue, the customer profiles, the demand
 * signals — because a briefing that derives its own churn rate will one day
 * disagree with the churn screen, and then nobody believes either.
 */
@Module({
  imports: [
    AnalyticsModule,
    SellerCommerceModule,
    ProductsModule,
    RankingModule,
    CustomerIntelligenceModule,
    TrustModule,
    LifecycleModule,
  ],
  controllers: [AdminIntelligenceController],
  providers: [AdminIntelligenceService, IntelligenceScheduler],
  exports: [AdminIntelligenceService],
})
export class AdminIntelligenceModule {}
