import { Module } from '@nestjs/common';
import { PostsController } from './posts.controller';
import { PostsService } from './posts.service';
import { PostsRepository } from './posts.repository';
import { SellerPostsController } from './seller-posts.controller';
import { SellerPostsService } from './seller-posts.service';

@Module({
  controllers: [SellerPostsController, PostsController],
  providers: [PostsService, SellerPostsService, PostsRepository],
})
export class PostsModule {}
