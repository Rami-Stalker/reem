import { Module } from '@nestjs/common';
import { ProductsController } from './products.controller';
import { ProductsService } from './products.service';
import { ProductsRepository } from './products.repository';
import { SellerProductsController } from './seller-products.controller';
import { SellerProductsService } from './seller-products.service';
import { SellerOffersController } from './seller-offers.controller';
import { SellerOffersService } from './seller-offers.service';
import { CatalogRollupService } from './catalog-rollup.service';
import { FavoritesModule } from '../favorites/favorites.module';
import { PricingModule } from '../pricing/pricing.module';

@Module({
  imports: [FavoritesModule, PricingModule],
  controllers: [
    SellerOffersController,
    SellerProductsController,
    ProductsController,
  ],
  providers: [
    ProductsService,
    SellerProductsService,
    SellerOffersService,
    CatalogRollupService,
    ProductsRepository,
  ],
  exports: [ProductsService, CatalogRollupService, SellerOffersService],
})
export class ProductsModule {}
