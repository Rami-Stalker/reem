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
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SubmitPaymentReferenceDto } from './dto/submit-payment-reference.dto';
import { PaymentsService } from './payments.service';

@Controller('payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  @Get('methods')
  methods() {
    return this.payments.methods();
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
