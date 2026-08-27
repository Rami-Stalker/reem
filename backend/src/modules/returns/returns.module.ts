import { Module } from '@nestjs/common';

import { PrismaModule } from '../../prisma/prisma.module';
import { CommissionsModule } from '../commissions/commissions.module';
import { FinanceModule } from '../finance/finance.module';
import { LedgerModule } from '../ledger/ledger.module';
import { OrderWorkflowModule } from '../orders/workflow/order-workflow.module';
import { ReturnRefundsService } from './return-refunds.service';
import { ReturnsController } from './returns.controller';
import { ReturnsScheduler } from './returns.scheduler';
import { ReturnsService } from './returns.service';

/**
 * Returns, exchanges and the money they give back.
 *
 * Sits above the ledger like the finance module does, and above orders because
 * a return is a thing that happens to an order rather than a thing an order
 * knows about — nothing here is imported the other way, so the dependency runs
 * in one direction and the checkout path stays ignorant of returns entirely.
 */
@Module({
  imports: [
    PrismaModule,
    LedgerModule,
    CommissionsModule,
    FinanceModule,
    OrderWorkflowModule,
  ],
  controllers: [ReturnsController],
  providers: [ReturnsService, ReturnRefundsService, ReturnsScheduler],
  exports: [ReturnsService, ReturnRefundsService],
})
export class ReturnsModule {}
