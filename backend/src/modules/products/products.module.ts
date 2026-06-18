import { Module } from '@nestjs/common';
import { ProductsController } from './products.controller';
import { ProductsService } from './products.service';
import { ProductsRepository } from './products.repository';
import { SellerProductsController } from './seller-products.controller';
import { SellerProductsService } from './seller-products.service';
import { FavoritesModule } from '../favorites/favorites.module';

@Module({
  imports: [FavoritesModule],
  controllers: [SellerProductsController, ProductsController],
  providers: [ProductsService, SellerProductsService, ProductsRepository],
  exports: [ProductsService],
})
export class ProductsModule {}
