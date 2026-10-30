import { PromotionsModule } from '../promotions/promotions.module';
import { Module } from '@nestjs/common';
import { CommerceContentModule } from '../commerce-content/commerce-content.module';
import { TrendsModule } from '../trends/trends.module';
import { PostsController } from './posts.controller';
import { PostsService } from './posts.service';
import { SellerPostsController } from './seller-posts.controller';
import { SellerPostsService } from './seller-posts.service';

@Module({
  // The legacy routes are adapters over the content platform now, so they
  // write through its services rather than their own tables.
  imports: [TrendsModule, CommerceContentModule, PromotionsModule],
  controllers: [SellerPostsController, PostsController],
  providers: [PostsService, SellerPostsService],
})
export class PostsModule {}
