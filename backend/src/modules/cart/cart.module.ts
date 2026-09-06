import { Module } from '@nestjs/common';
import { TrendsModule } from '../trends/trends.module';
import { CartController } from './cart.controller';
import { CartService } from './cart.service';
import { CartRepository } from './cart.repository';

@Module({
  imports: [TrendsModule],
  controllers: [CartController],
  providers: [CartService, CartRepository],
  exports: [CartService],
})
export class CartModule {}
