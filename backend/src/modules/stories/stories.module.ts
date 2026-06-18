import { Module } from '@nestjs/common';
import { StoriesController } from './stories.controller';
import { StoriesService } from './stories.service';
import { StoriesRepository } from './stories.repository';
import { SellerStoriesController } from './seller-stories.controller';
import { SellerStoriesService } from './seller-stories.service';
import { StoriesCleanupService } from './stories-cleanup.service';

@Module({
  controllers: [SellerStoriesController, StoriesController],
  providers: [
    StoriesService,
    SellerStoriesService,
    StoriesRepository,
    StoriesCleanupService,
  ],
})
export class StoriesModule {}
