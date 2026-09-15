import { Module } from '@nestjs/common';
import {
  ProductSocialController,
  UserPicksController,
} from './product-social.controller';
import { ProductSocialService } from './product-social.service';

@Module({
  controllers: [ProductSocialController, UserPicksController],
  providers: [ProductSocialService],
  exports: [ProductSocialService],
})
export class ProductSocialModule {}
