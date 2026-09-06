import { Module } from '@nestjs/common';
import { ProductsController } from './products.controller';
import { CategoriesController } from './categories.controller';
import { CategoriesService } from './categories.service';
import { ProductsService } from './products.service';
import { ProductsRepository } from './products.repository';
import { SellerProductsController } from './seller-products.controller';
import { SellerProductsService } from './seller-products.service';
import { SellerOffersController } from './seller-offers.controller';
import { SellerOffersService } from './seller-offers.service';
import { CatalogRollupService } from './catalog-rollup.service';
import { FavoritesModule } from '../favorites/favorites.module';
import { PricingModule } from '../pricing/pricing.module';
import { TrendsModule } from '../trends/trends.module';
import { ValueModule } from '../value/value.module';

@Module({
  // ValueModule is read-only here: the catalogue asks what her standing lets
  // her see. Nothing in the value module knows what a product is.
  imports: [FavoritesModule, PricingModule, TrendsModule, ValueModule],
  controllers: [
    CategoriesController,
    SellerOffersController,
    SellerProductsController,
    ProductsController,
  ],
  providers: [
    ProductsService,
    CategoriesService,
    SellerProductsService,
    SellerOffersService,
    CatalogRollupService,
    ProductsRepository,
  ],
  exports: [
    ProductsService,
    CategoriesService,
    CatalogRollupService,
    SellerOffersService,
  ],
})
export class ProductsModule {}
