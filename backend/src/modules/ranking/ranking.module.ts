import { Module } from '@nestjs/common';
import { RankingController } from './ranking.controller';
import { RankingService } from './ranking.service';

/**
 * Where a listing or a boutique sits, and why.
 *
 * Exported so discovery and search can order by the stored score. Nothing here
 * decides what a customer sees — it decides the order of what she was going to
 * see anyway, which is a smaller claim and the honest one.
 */
@Module({
  controllers: [RankingController],
  providers: [RankingService],
  exports: [RankingService],
})
export class RankingModule {}
