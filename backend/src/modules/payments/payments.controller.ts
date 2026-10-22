import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { SubmitPaymentReferenceDto } from './dto/submit-payment-reference.dto';
import {
  ConfirmTransferDto,
  RejectTransferDto,
} from './dto/transfer-decision.dto';
import { PaymentsService } from './payments.service';

@SelfScoped(
  'every payment is loaded by id together with the userId that owns its order',
)
@Controller('payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  @Get('methods')
  methods() {
    return this.payments.methods();
  }

  // ── Finance: bank transfers and hawala (Q51) ──────────────────────────
  // Declared before `:id` so the literal path is not read as a payment id.

  @Get('admin/transfers')
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  pendingTransfers() {
    return this.payments.pendingTransfers();
  }

  @Post('admin/transfers/:id/confirm')
  @HttpCode(HttpStatus.OK)
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  confirmTransfer(
    @CurrentUser('id') actorId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ConfirmTransferDto,
  ) {
    return this.payments.confirmTransfer(actorId, id, dto.note);
  }

  @Post('admin/transfers/:id/reject')
  @HttpCode(HttpStatus.OK)
  @Roles(UserRole.SUPER_ADMIN, UserRole.FINANCE_ADMIN)
  rejectTransfer(
    @CurrentUser('id') actorId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejectTransferDto,
  ) {
    return this.payments.rejectTransfer(actorId, id, dto.reason);
  }

  @Get()
  history(@CurrentUser('id') userId: string) {
    return this.payments.history(userId);
  }

  @Get(':id')
  detail(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.payments.detail(userId, id);
  }

  @Post(':id/verify')
  @HttpCode(HttpStatus.OK)
  verify(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.payments.verify(userId, id);
  }

  /** Q51 — the reference for a transfer she has already sent. */
  @Post(':id/reference')
  @HttpCode(HttpStatus.OK)
  submitReference(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SubmitPaymentReferenceDto,
  ) {
    return this.payments.submitReference(userId, id, dto.reference);
  }

  @Post(':id/retry')
  @HttpCode(HttpStatus.OK)
  retry(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.payments.retry(userId, id);
  }
}
