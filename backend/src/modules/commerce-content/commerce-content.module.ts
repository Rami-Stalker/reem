import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AdminCommerceContentController } from './admin-commerce-content.controller';
import { AdminContentController } from './admin-content.controller';
import { ContentAuthoringController } from './content-authoring.controller';
import { ContentSocialController } from './content-social.controller';
import { SellerContentAnalyticsController } from './seller-content-analytics.controller';
import { CommerceContentController } from './commerce-content.controller';
import { CommerceContentRepository } from './commerce-content.repository';
import { CommerceContentScheduler } from './commerce-content.scheduler';
import { CommerceContentService } from './commerce-content.service';
import { CommerceContentTypesController } from './commerce-content-types.controller';
import { ContentTypeRegistryService } from './content-type-registry.service';
import { ContentAnalyticsService } from './analytics/content-analytics.service';
import { ContentFeedService } from './feed/content-feed.service';
import { ContentAttributionService } from './attribution/content-attribution.service';
import { ContentInteractionsService } from './interactions/content-interactions.service';
import { ContentModerationService } from './moderation/content-moderation.service';
import { ProductTagPolicyService } from './tagging/product-tag-policy.service';
import { SellerCommerceContentController } from './seller-commerce-content.controller';

@Module({
  // For `AuditService`: a takedown that is not written to the audit log is
  // the silent removal this feature exists to prevent.
  imports: [AuthModule],
  controllers: [
    AdminCommerceContentController,
    AdminContentController,
    ContentAuthoringController,
    ContentSocialController,
    SellerContentAnalyticsController,
    CommerceContentController,
    CommerceContentTypesController,
    SellerCommerceContentController,
  ],
  providers: [
    CommerceContentRepository,
    CommerceContentScheduler,
    CommerceContentService,
    ContentTypeRegistryService,
    ProductTagPolicyService,
    ContentAttributionService,
    ContentInteractionsService,
    ContentModerationService,
    ContentFeedService,
    ContentAnalyticsService,
  ],
  exports: [
    CommerceContentService,
    ContentTypeRegistryService,
    ProductTagPolicyService,
    ContentAttributionService,
    ContentInteractionsService,
    ContentModerationService,
    ContentFeedService,
    ContentAnalyticsService,
  ],
})
export class CommerceContentModule {}
