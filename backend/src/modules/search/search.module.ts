import { Module } from '@nestjs/common';
import { TrendsModule } from '../trends/trends.module';
import { SearchController } from './search.controller';
import { SearchService } from './search.service';

@Module({
  imports: [TrendsModule],
  controllers: [SearchController],
  providers: [SearchService],
})
export class SearchModule {}
