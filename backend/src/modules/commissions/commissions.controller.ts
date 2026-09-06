import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { CommissionsService } from './commissions.service';
import {
  CommissionLedgerStatusDto,
  CommissionReportQueryDto,
  CommissionRuleDto,
  PayoutCalculationDto,
  PayoutStatusDto,
} from './dto/commission.dto';

@Controller('commissions')
export class CommissionsController {
  constructor(private readonly commissions: CommissionsService) {}

  @Get('seller/earnings')
  @Roles(UserRole.SELLER)
  sellerEarnings(@CurrentUser('id') sellerId: string) {
    return this.commissions.sellerEarnings(sellerId);
  }

  @Get('seller/transactions')
  @Roles(UserRole.SELLER)
  sellerTransactions(@CurrentUser('id') sellerId: string) {
    return this.commissions.sellerTransactions(sellerId);
  }

  @Get('admin/rules')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.FINANCE_ADMIN)
  rules() {
    return this.commissions.rules();
  }

  @Post('admin/rules')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  @HttpCode(HttpStatus.CREATED)
  createRule(@Body() dto: CommissionRuleDto) {
    return this.commissions.createRule(dto);
  }

  // Q62 — «المحاسب» is the role that reads the commission report every week;
  // leaving FINANCE_ADMIN off this list meant the console's own commissions
  // screen 403'd for exactly the person it was built for.
  @Get('admin/reports')
  @Roles(
    UserRole.SUPER_ADMIN,
    UserRole.ADMIN,
    UserRole.FINANCE_ADMIN,
    UserRole.SUPPORT,
  )
  report(@Query() query: CommissionReportQueryDto) {
    return this.commissions.adminReport(query);
  }

  @Post('admin/orders/:orderId/settle')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  settleOrder(@Param('orderId', ParseUUIDPipe) orderId: string) {
    return this.commissions.settleOrder(orderId);
  }

  @Post('admin/orders/:orderId/reverse')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  reverseOrder(@Param('orderId', ParseUUIDPipe) orderId: string) {
    return this.commissions.reverseOrder(orderId, 'Manual refund adjustment');
  }

  // The accountant prepares the payout; releasing it stays with the general
  // manager, and the service checks that against the caller's own role.
  @Post('admin/payouts/calculate')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.FINANCE_ADMIN)
  @HttpCode(HttpStatus.CREATED)
  calculatePayout(@Body() dto: PayoutCalculationDto) {
    return this.commissions.calculatePayout(dto);
  }

  /**
   * Q62 — «المدير العام + المحاسب» may work with payouts, but «اعتماد صرف
   * الأرباح من المدير العام فقط»: the accountant prepares, only the general
   * manager approves or releases. That second half is enforced in the service
   * against the caller's own role, not here, so it cannot be bypassed by a
   * route that forgets it.
   */
  @Patch('admin/payouts/:id')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  updatePayout(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PayoutStatusDto,
    @CurrentUser('id') actorId: string,
    @CurrentUser('role') actorRole: UserRole,
  ) {
    return this.commissions.updatePayoutStatus(id, dto, actorId, actorRole);
  }

  @Patch('admin/ledgers/:id')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.FINANCE_ADMIN)
  updateLedger(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CommissionLedgerStatusDto,
  ) {
    return this.commissions.updateLedgerStatus(id, dto);
  }
}
