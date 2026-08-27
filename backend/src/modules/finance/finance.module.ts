import { Module, forwardRef } from '@nestjs/common';

import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { LedgerModule } from '../ledger/ledger.module';
import { OrderWorkflowModule } from '../orders/workflow/order-workflow.module';
import { PricingModule } from '../pricing/pricing.module';
import {
  WALLET_AUDIT_HOOK,
  WalletAuditHook,
} from '../ledger/wallet.service';
import {
  RATE_AUDIT_HOOK,
  RateAuditHook,
} from '../pricing/exchange-rate-sync.service';
import { AdminFinanceService } from './admin-finance.service';
import { CourierSettlementService } from './courier-settlement.service';
import { CustomerRefundsService } from './customer-refunds.service';
import { DisputesService } from './disputes.service';
import {
  FinancialAction,
  FinancialAuditService,
} from './financial-audit.service';
import { FxRevaluationService } from './fx-revaluation.service';
import { FinanceController } from './finance.controller';
import { LoyaltyService } from './loyalty.service';
import { ReconciliationService } from './reconciliation.service';
import { SellerEarningsService } from './seller-earnings.service';

/**
 * Everything that moves money for a business reason, layered over the ledger
 * kernel in [LedgerModule].
 *
 * The split is deliberate: `LedgerModule` knows how to record money and
 * nothing about why, and this module knows why and delegates the recording.
 * That is what keeps the balancing invariants in one place instead of being
 * re-implemented by every feature that touches a balance.
 */
@Module({
  imports: [
    PrismaModule,
    LedgerModule,
    PricingModule,
    OrderWorkflowModule,
    forwardRef(() => AuthModule),
  ],
  controllers: [FinanceController],
  providers: [
    DisputesService,
    CustomerRefundsService,
    CourierSettlementService,
    LoyaltyService,
    ReconciliationService,
    SellerEarningsService,
    FxRevaluationService,
    AdminFinanceService,
    FinancialAuditService,

    // The kernel modules take an optional callback rather than importing this
    // one, so the dependency runs one way: ledger and pricing underneath,
    // finance above. These bind the real implementation to those seams.
    {
      provide: WALLET_AUDIT_HOOK,
      inject: [FinancialAuditService],
      useFactory: (audit: FinancialAuditService): WalletAuditHook => {
        return (event) =>
          audit.recordBalanceChange(
            event.action === 'wallet.frozen'
              ? FinancialAction.WalletFrozen
              : FinancialAction.WalletCredited,
            {
              actorId: event.actorId,
              subjectId: event.walletId,
              subjectType: 'wallet',
              before: event.before,
              after: event.after,
              reason: event.reason,
              extra: { user_id: event.userId, source: event.source ?? null },
            },
          );
      },
    },
    {
      provide: RATE_AUDIT_HOOK,
      inject: [FinancialAuditService],
      useFactory: (audit: FinancialAuditService): RateAuditHook => {
        return (event) =>
          audit.record({
            action: event.published
              ? FinancialAction.ExchangeRatePublished
              : FinancialAction.ExchangeRateRejected,
            subjectId: 'USD/SYP',
            subjectType: 'exchange_rate',
            before: event.previous ?? null,
            after: event.rate ?? null,
            reason: event.reason ?? event.source,
            outcome: event.published ? 'success' : 'refused',
            extra: { source: event.source },
          });
      },
    },
  ],
  exports: [
    DisputesService,
    CustomerRefundsService,
    CourierSettlementService,
    LoyaltyService,
    ReconciliationService,
    SellerEarningsService,
    FxRevaluationService,
    AdminFinanceService,
    FinancialAuditService,
  ],
})
export class FinanceModule {}
