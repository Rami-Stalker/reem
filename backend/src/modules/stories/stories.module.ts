import { Module } from '@nestjs/common';
import { CommerceContentModule } from '../commerce-content/commerce-content.module';
import { TrendsModule } from '../trends/trends.module';
import { StoriesController } from './stories.controller';
import { StoriesService } from './stories.service';
import { SellerStoriesController } from './seller-stories.controller';
import { SellerStoriesService } from './seller-stories.service';

@Module({
  // The legacy routes are adapters over the content platform now, so they
  // write through its services rather than their own tables.
  imports: [TrendsModule, CommerceContentModule],
  controllers: [SellerStoriesController, StoriesController],
  providers: [StoriesService, SellerStoriesService],
})
export class StoriesModule {}
