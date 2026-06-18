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
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  rules() {
    return this.commissions.rules();
  }

  @Post('admin/rules')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  @HttpCode(HttpStatus.CREATED)
  createRule(@Body() dto: CommissionRuleDto) {
    return this.commissions.createRule(dto);
  }

  @Get('admin/reports')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
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

  @Post('admin/payouts/calculate')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  @HttpCode(HttpStatus.CREATED)
  calculatePayout(@Body() dto: PayoutCalculationDto) {
    return this.commissions.calculatePayout(dto);
  }

  @Patch('admin/payouts/:id')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  updatePayout(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PayoutStatusDto,
  ) {
    return this.commissions.updatePayoutStatus(id, dto);
  }

  @Patch('admin/ledgers/:id')
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  updateLedger(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CommissionLedgerStatusDto,
  ) {
    return this.commissions.updateLedgerStatus(id, dto);
  }
}
