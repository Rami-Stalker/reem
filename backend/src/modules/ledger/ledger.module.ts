import { Module } from '@nestjs/common';

import { PrismaModule } from '../../prisma/prisma.module';
import { LedgerController } from './ledger.controller';
import { LedgerService } from './ledger.service';
import { WalletService } from './wallet.service';

/**
 * The financial core: the double-entry book of record and the customer wallet
 * that sits on top of it.
 *
 * Exported so commissions, orders, returns and payouts post through it rather
 * than writing money rows of their own — one ledger, one set of invariants.
 */
@Module({
  imports: [PrismaModule],
  controllers: [LedgerController],
  providers: [LedgerService, WalletService],
  exports: [LedgerService, WalletService],
})
export class LedgerModule {}
