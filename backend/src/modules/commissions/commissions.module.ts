import { Module } from '@nestjs/common';
import { LedgerModule } from '../ledger/ledger.module';
import { FinanceModule } from '../finance/finance.module';
import { CommissionsController } from './commissions.controller';
import { CommissionsService } from './commissions.service';
import { CommissionQuoteService } from './commission-quote.service';

@Module({
  imports: [LedgerModule, FinanceModule],
  controllers: [CommissionsController],
  providers: [CommissionsService, CommissionQuoteService],
  exports: [CommissionsService, CommissionQuoteService],
})
export class CommissionsModule {}
