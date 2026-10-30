import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
} from '@nestjs/common';
import { PaymentMethodType, UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AdPlanPaymentsService } from './ad-plan-payments.service';
import {
  PlanPaymentInstructionsDto,
  RejectPlanPaymentDto,
} from './dto/promotions.dto';

/**
 * Finance's half of «باقات الإعلان»: the transfers to match, where boutiques
 * send the money, and the month at a glance.
 */
@Controller('ads/admin')
@Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
export class AdminAdsController {
  constructor(private readonly payments: AdPlanPaymentsService) {}

  @Get('summary')
  summary() {
    return this.payments.summary();
  }

  @Get('purchases')
  pending() {
    return this.payments.pending();
  }

  @Post('purchases/:id/confirm')
  @HttpCode(HttpStatus.OK)
  confirm(
    @CurrentUser('id') actorId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.payments.confirm(actorId, id);
  }

  @Post('purchases/:id/reject')
  @HttpCode(HttpStatus.OK)
  reject(
    @CurrentUser('id') actorId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejectPlanPaymentDto,
  ) {
    return this.payments.reject(actorId, id, dto.reason);
  }

  @Get('payment-instructions')
  instructions() {
    return this.payments.adminInstructions();
  }

  @Put('payment-instructions')
  setInstructions(
    @CurrentUser('id') actorId: string,
    @Body() dto: PlanPaymentInstructionsDto,
  ) {
    return this.payments.setInstructions(actorId, {
      [PaymentMethodType.SHAM_CASH]: dto.sham_cash ?? null,
      [PaymentMethodType.SYRIATEL_CASH]: dto.syriatel_cash ?? null,
      [PaymentMethodType.MTN_CASH]: dto.mtn_cash ?? null,
      [PaymentMethodType.BANK_TRANSFER]: dto.bank_transfer ?? null,
      [PaymentMethodType.HAWALA]: dto.hawala ?? null,
    });
  }
}
