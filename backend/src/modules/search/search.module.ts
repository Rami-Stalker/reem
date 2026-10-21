import { Module } from '@nestjs/common';
import { ValueModule } from '../value/value.module';
import { TrendsModule } from '../trends/trends.module';
import { PromotionsModule } from '../promotions/promotions.module';
import { SearchController } from './search.controller';
import { SearchService } from './search.service';
import { ProductMatcher } from './product-matcher.service';
import { SynonymsService } from './synonyms.service';
import { SynonymsAdminController } from './synonyms.admin.controller';
import { SynonymsAdminService } from './synonyms.admin.service';

@Module({
  imports: [TrendsModule, PromotionsModule, ValueModule],
  controllers: [SearchController, SynonymsAdminController],
  providers: [
    SearchService,
    ProductMatcher,
    SynonymsService,
    SynonymsAdminService,
  ],
  exports: [ProductMatcher, SynonymsService],
})
export class SearchModule {}
