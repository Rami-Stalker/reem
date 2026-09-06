import { Module } from '@nestjs/common';
import { TrendsModule } from '../trends/trends.module';
import { PostsController } from './posts.controller';
import { PostsService } from './posts.service';
import { PostsRepository } from './posts.repository';
import { SellerPostsController } from './seller-posts.controller';
import { SellerPostsService } from './seller-posts.service';

@Module({
  imports: [TrendsModule],
  controllers: [SellerPostsController, PostsController],
  providers: [PostsService, SellerPostsService, PostsRepository],
})
export class PostsModule {}
