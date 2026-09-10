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
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { Money } from '../../common/money';
import { AdminFinanceService } from './admin-finance.service';
import { CourierSettlementService } from './courier-settlement.service';
import { DisputeRuling, DisputesService } from './disputes.service';
import { FxRevaluationService } from './fx-revaluation.service';
import { ExchangeRateSyncService } from '../pricing/exchange-rate-sync.service';
import {
  AppealDisputeDto,
  ConvertPointsDto,
  CourierExpectedCashQueryDto,
  CurrencyQueryDto,
  DecideDisputeDto,
  DisputeMessageDto,
  OpenDisputeDto,
  RequestPayoutDto,
  SettleCourierCashDto,
} from './dto/finance.dto';
import { LoyaltyService } from './loyalty.service';
import { ReconciliationService } from './reconciliation.service';
import { SellerEarningsService } from './seller-earnings.service';
import { SellerPayoutsService } from './seller-payouts.service';

/**
 * Finance operations.
 *
 * Q62 restricts money to the general manager and the accountant, so the admin
 * routes are `SUPER_ADMIN` / `FINANCE_ADMIN`. The two exceptions are opening a
 * dispute — which a customer must be able to do herself — and converting her
 * own points.
 */
/**
 * The money surface: an accountant's console, a seller's earnings, and the
 * few things a customer does with her own funds.
 *
 * Every administrative route here names `SUPER_ADMIN`/`FINANCE_ADMIN` and is
 * judged by that. What is left — opening a dispute, reading and writing its
 * messages, listing the disputes she is party to, converting her own points —
 * turns on which side of the sale the caller is on, which the service decides
 * from the `AuthUser` it is handed.
 *
 * Undeclared, that remainder was refused: a customer could not open a dispute
 * or answer one, and neither could the seller she opened it against.
 */
@SelfScoped(
  "the dispute routes hand the whole AuthUser to DisputeService, which admits only the two parties to the sub-order and support; the loyalty conversion moves the caller's own points",
)
@Controller('finance')
export class FinanceController {
  constructor(
    private readonly disputes: DisputesService,
    private readonly couriers: CourierSettlementService,
    private readonly loyalty: LoyaltyService,
    private readonly reconciliation: ReconciliationService,
    private readonly sellerEarnings: SellerEarningsService,
    private readonly sellerPayouts: SellerPayoutsService,
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

  /**
   * The other half of Q69 P1 — what she could withdraw, and why not.
   *
   * Read before the button is drawn, so a disabled «سحب» carries a reason
   * rather than being mysteriously grey.
   */
  @Get('seller/payouts/availability')
  @Roles(UserRole.SELLER)
  payoutAvailability(
    @CurrentUser('id') sellerId: string,
    @Query() query: CurrencyQueryDto,
  ) {
    return this.sellerPayouts.availability(
      sellerId,
      query.currency ?? Currency.SYP,
    );
  }

  /** Her withdrawal requests, newest first. */
  @Get('seller/payouts')
  @Roles(UserRole.SELLER)
  payoutHistory(
    @CurrentUser('id') sellerId: string,
    @Query() query: CurrencyQueryDto,
  ) {
    return this.sellerPayouts.history(sellerId, query.currency);
  }

  /**
   * She asks to be paid what is released.
   *
   * This creates a `PENDING` payout and nothing else. No money moves here:
   * approving and releasing it stay with the general manager (Q62), and the
   * cash movement is posted by the ledger when it is marked paid.
   */
  @Post('seller/payouts')
  @Roles(UserRole.SELLER)
  @HttpCode(HttpStatus.CREATED)
  requestPayout(
    @CurrentUser('id') sellerId: string,
    @Body() dto: RequestPayoutDto,
  ) {
    return this.sellerPayouts.request(sellerId, dto.currency ?? Currency.SYP);
  }

  /** She withdraws the request while it is still waiting on a decision. */
  @Post('seller/payouts/:id/cancel')
  @Roles(UserRole.SELLER)
  @HttpCode(HttpStatus.OK)
  cancelPayout(
    @CurrentUser('id') sellerId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.sellerPayouts.cancel(sellerId, id);
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
    @Query() query: CourierExpectedCashQueryDto,
  ) {
    const expected = await this.couriers.expectedFor(
      courierId,
      query.date ? new Date(query.date) : new Date(),
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
