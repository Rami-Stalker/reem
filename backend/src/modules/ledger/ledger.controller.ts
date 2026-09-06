import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { Currency, UserRole } from '@prisma/client';

import { Money } from '../../common/money';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AdminWalletCreditDto, WalletQueryDto } from './dto/ledger.dto';
import { LedgerService } from './ledger.service';
import { WalletService } from './wallet.service';

/**
 * Financial read surfaces and the few write actions an admin performs by hand.
 *
 * Q62 restricts the money screens to the general manager and the accountant,
 * so every admin route here is `SUPER_ADMIN` or `FINANCE_ADMIN` — support and
 * operations admins deliberately cannot see or move funds.
 */
@Controller('ledger')
export class LedgerController {
  constructor(
    private readonly ledger: LedgerService,
    private readonly wallets: WalletService,
  ) {}

  // ── Customer-facing wallet ────────────────────────────────────────────

  /** Her own balance. */
  @Get('wallet')
  async myWallet(
    @CurrentUser('id') userId: string,
    @Query() query: WalletQueryDto,
  ) {
    const currency = query.currency ?? Currency.SYP;
    const balance = await this.wallets.balanceOf(userId, currency);
    return { balance: balance.toJSON(), withdrawable: false };
  }

  /** Q41 — «سجل كامل لحركات المحفظة». */
  @Get('wallet/transactions')
  async myWalletStatement(
    @CurrentUser('id') userId: string,
    @Query() query: WalletQueryDto,
  ) {
    return this.wallets.statement(userId, query.currency ?? Currency.SYP, {
      skip: query.skip ?? 0,
      take: query.take ?? 50,
    });
  }

  // ── Admin: the book of record ─────────────────────────────────────────

  /**
   * The trial balance. `balanced: false` means debits and credits disagree —
   * money has been created or destroyed somewhere, and it is worth an alert.
   */
  @Get('admin/trial-balance')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  trialBalance(@Query() query: WalletQueryDto) {
    return this.ledger.trialBalance(query.currency ?? Currency.SYP);
  }

  /** Re-derives one account's balance from its lines to prove the cache agrees. */
  @Get('admin/accounts/:accountId/verify')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  verifyAccount(@Param('accountId', ParseUUIDPipe) accountId: string) {
    return this.ledger.verifyAccount(accountId);
  }

  // ── Admin: manual wallet credit (Q41 «شحن يدوي من الإدارة») ────────────

  @Post('admin/wallets/:userId/credit')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  @HttpCode(HttpStatus.CREATED)
  creditWallet(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() dto: AdminWalletCreditDto,
    @CurrentUser('id') adminId: string,
  ) {
    return this.wallets.credit({
      userId,
      amount: Money.of(dto.amount, dto.currency ?? Currency.SYP),
      source: dto.source,
      reason: dto.reason,
      reference: dto.reference,
      createdById: adminId,
    });
  }
}
