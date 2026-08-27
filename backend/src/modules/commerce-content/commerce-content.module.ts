import { Module } from '@nestjs/common';
import { AdminCommerceContentController } from './admin-commerce-content.controller';
import { CommerceContentController } from './commerce-content.controller';
import { CommerceContentRepository } from './commerce-content.repository';
import { CommerceContentScheduler } from './commerce-content.scheduler';
import { CommerceContentService } from './commerce-content.service';
import { CommerceContentTypesController } from './commerce-content-types.controller';
import { ContentTypeRegistryService } from './content-type-registry.service';
import { SellerCommerceContentController } from './seller-commerce-content.controller';

@Module({
  controllers: [
    AdminCommerceContentController,
    CommerceContentController,
    CommerceContentTypesController,
    SellerCommerceContentController,
  ],
  providers: [
    CommerceContentRepository,
    CommerceContentScheduler,
    CommerceContentService,
    ContentTypeRegistryService,
  ],
  exports: [CommerceContentService, ContentTypeRegistryService],
})
export class CommerceContentModule {}
