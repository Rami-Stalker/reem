import {
  BadRequestException,
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

import { AuthUser } from '../../common/decorators/current-user.decorator';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { Money } from '../../common/money';
import { AdminFinanceService } from './admin-finance.service';
import { CourierSettlementService } from './courier-settlement.service';
import { DisputeRuling, DisputesService } from './disputes.service';
import { FxRevaluationService } from './fx-revaluation.service';
import { ExchangeRateSyncService } from '../pricing/exchange-rate-sync.service';
import {
  AppealDisputeDto,
  ConvertPointsDto,
  CurrencyQueryDto,
  DecideDisputeDto,
  DisputeMessageDto,
  OpenDisputeDto,
  SettleCourierCashDto,
} from './dto/finance.dto';
import { LoyaltyService } from './loyalty.service';
import { ReconciliationService } from './reconciliation.service';
import { SellerEarningsService } from './seller-earnings.service';

/**
 * Finance operations.
 *
 * Q62 restricts money to the general manager and the accountant, so the admin
 * routes are `SUPER_ADMIN` / `FINANCE_ADMIN`. The two exceptions are opening a
 * dispute — which a customer must be able to do herself — and converting her
 * own points.
 */
@Controller('finance')
export class FinanceController {
  constructor(
    private readonly disputes: DisputesService,
    private readonly couriers: CourierSettlementService,
    private readonly loyalty: LoyaltyService,
    private readonly reconciliation: ReconciliationService,
    private readonly sellerEarnings: SellerEarningsService,
    private readonly fx: FxRevaluationService,
    private readonly fxSync: ExchangeRateSyncService,
    private readonly adminFinance: AdminFinanceService,
  ) {}

  /**
   * Everything the finance console shows, in one call.
   *
   * Assembled server-side so no client has to fold money totals of its own —
   * see `AdminFinanceService`.
   */
  @Get('admin/overview')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  overview(@Query() query: CurrencyQueryDto) {
    return this.adminFinance.overview(query.currency ?? Currency.SYP);
  }

  /**
   * Pulls the rate now instead of waiting for the morning run.
   *
   * Reports why a rate was not published rather than failing silently — a
   * feed that has drifted out of shape looks identical to one that is simply
   * unchanged unless someone is told which it was.
   */
  @Post('admin/fx/sync')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  @HttpCode(HttpStatus.OK)
  syncRate() {
    return this.fxSync.syncNow();
  }

  // ── FX position (Q45–Q48) ────────────────────────────────────────────

  /**
   * What the platform's foreign-currency position is worth today, and what
   * past conversions have actually cost.
   *
   * The two are reported side by side because they answer different
   * questions: exposure is a forecast about a rate that has not moved yet,
   * result is money already spent.
   */
  @Get('admin/fx')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  async fxPosition(@Query() query: CurrencyQueryDto) {
    const foreign = query.currency ?? Currency.USD;
    const [exposure, result] = await Promise.all([
      this.fx.exposure(foreign),
      this.fx.accumulatedResult(foreign),
    ]);
    return { exposure, result };
  }

  // ── Seller statement (Q69, Q98) ──────────────────────────────────────

  /**
   * Her own earnings, read from the ledger.
   *
   * Reports escrow, payable and disputed separately rather than as one
   * balance — that split is precisely what a seller queries.
   */
  @Get('seller/earnings')
  @Roles(UserRole.SELLER)
  earnings(
    @CurrentUser('id') sellerId: string,
    @Query() query: CurrencyQueryDto,
  ) {
    return this.sellerEarnings.summaryFor(
      sellerId,
      query.currency ?? Currency.SYP,
    );
  }

  // ── Disputes (Q107) ──────────────────────────────────────────────────

  /** A customer raises a dispute; the amount under review freezes at once. */
  @Post('disputes')
  @HttpCode(HttpStatus.CREATED)
  openDispute(
    @Body() dto: OpenDisputeDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.disputes.open({
      sellerOrderId: dto.seller_order_id,
      openedById: userId,
      subject: dto.subject,
      // Passed through as a string — the service applies the sub-order's own
      // currency to it.
      amount: dto.amount,
    });
  }

  @Post('disputes/:id/decide')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  decideDispute(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: DecideDisputeDto,
    @CurrentUser('id') adminId: string,
  ) {
    return this.disputes.decide(id, this.toRuling(dto), adminId);
  }

  /** Q107 — one appeal per dispute. */
  @Post('disputes/:id/appeal')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN, UserRole.SUPPORT_ADMIN)
  appealDispute(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AppealDisputeDto,
  ) {
    return this.disputes.appeal(id, dto.note);
  }

  /** Disputes past their 3/7 working-day clock. */
  /**
   * Q107 — «طلب أدلة من الطرفين».
   *
   * Open to both parties and to support, because a dispute with only one side
   * on the record is not a review, it is a verdict.
   */
  @Get('disputes/:id/messages')
  disputeMessages(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.disputes.messages(id, user);
  }

  @Post('disputes/:id/messages')
  @HttpCode(HttpStatus.CREATED)
  addDisputeMessage(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: DisputeMessageDto,
  ) {
    return this.disputes.addMessage(id, user, {
      body: dto.body,
      evidence: dto.evidence,
      isInternal: dto.is_internal,
    });
  }

  /** Whichever side of the sale the reader is on. */
  @Get('disputes')
  myDisputes(@CurrentUser() user: AuthUser) {
    return this.disputes.listFor(user);
  }

  @Get('disputes/overdue')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN, UserRole.SUPPORT_ADMIN)
  overdueDisputes() {
    return this.disputes.overdue();
  }

  // ── Courier cash (Q56) ───────────────────────────────────────────────

  /** What a courier owes for a given day, before settling it. */
  @Get('couriers/:courierId/expected')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  async expectedCash(
    @Param('courierId', ParseUUIDPipe) courierId: string,
    @Query('date') date: string,
    @Query() query: CurrencyQueryDto,
  ) {
    const expected = await this.couriers.expectedFor(
      courierId,
      date ? new Date(date) : new Date(),
      query.currency ?? Currency.SYP,
    );
    return { expected: expected.toJSON() };
  }

  @Post('couriers/settle')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  @HttpCode(HttpStatus.CREATED)
  settleCourier(
    @Body() dto: SettleCourierCashDto,
    @CurrentUser('id') adminId: string,
  ) {
    return this.couriers.settle({
      courierId: dto.courier_id,
      date: new Date(dto.date),
      collected: Money.of(dto.collected, dto.currency ?? Currency.SYP),
      settledById: adminId,
      note: dto.note,
    });
  }

  /** Cash still sitting with couriers, per courier. */
  @Get('couriers/outstanding')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  outstandingCash(@Query() query: CurrencyQueryDto) {
    return this.couriers.outstanding(query.currency ?? Currency.SYP);
  }

  // ── Loyalty (Q43) ────────────────────────────────────────────────────

  /** She converts her own points into wallet credit. */
  @Post('loyalty/convert')
  @HttpCode(HttpStatus.CREATED)
  convertPoints(
    @CurrentUser('id') userId: string,
    @Body() dto: ConvertPointsDto,
  ) {
    return this.loyalty.convertToWallet(userId, dto.points);
  }

  // ── Reconciliation ───────────────────────────────────────────────────

  /** Runs every consistency check now instead of waiting for the nightly job. */
  @Get('admin/reconciliation')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  async reconcile(@Query() query: CurrencyQueryDto) {
    const currency = query.currency ?? Currency.SYP;
    const [report, walletFindings] = await Promise.all([
      this.reconciliation.run(currency),
      this.reconciliation.verifyWallets(currency),
    ]);
    const findings = [...report.findings, ...walletFindings];
    return { ...report, findings, healthy: findings.length === 0 };
  }

  // ── Internals ────────────────────────────────────────────────────────

  private toRuling(dto: DecideDisputeDto): DisputeRuling {
    if (dto.outcome !== 'SPLIT') {
      return { outcome: dto.outcome, note: dto.note };
    }
    if (!dto.customer_share) {
      throw new BadRequestException(
        'A split ruling must state the customer_share',
      );
    }
    return {
      outcome: 'SPLIT',
      // The service applies the dispute's own currency to this.
      customerShare: dto.customer_share,
      note: dto.note,
    };
  }
}
