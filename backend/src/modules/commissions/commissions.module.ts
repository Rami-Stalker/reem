import { Module } from '@nestjs/common';
import { LedgerModule } from '../ledger/ledger.module';
import { FinanceModule } from '../finance/finance.module';
import { CommissionsController } from './commissions.controller';
import { CommissionsScheduler } from './commissions.scheduler';
import { CommissionsService } from './commissions.service';
import { CommissionQuoteService } from './commission-quote.service';

@Module({
  imports: [LedgerModule, FinanceModule],
  controllers: [CommissionsController],
  // `CommissionsScheduler` is what makes seller money payable at all — see the
  // file for what its absence cost. It lives here rather than in a shared
  // scheduling module because the sweep it runs is this module's own.
  providers: [CommissionsService, CommissionQuoteService, CommissionsScheduler],
  exports: [CommissionsService, CommissionQuoteService],
})
export class CommissionsModule {}
