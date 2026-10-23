import { Module } from '@nestjs/common';
import { LedgerModule } from '../ledger/ledger.module';
import { PromotionsController } from './promotions.controller';
import { PromotionsService } from './promotions.service';
import { SponsoredController } from './sponsored.controller';

/**
 * Sponsored placements.
 *
 * Exported so search and discovery can ask for the paid slots. They are given
 * offer ids and nothing else, deliberately: a sponsored result has to be shown
 * as sponsored, and handing back ready-made cards would make it easy to
 * forget the label.
 */
@Module({
  imports: [LedgerModule],
  controllers: [PromotionsController, SponsoredController],
  providers: [PromotionsService],
  exports: [PromotionsService],
})
export class PromotionsModule {}
