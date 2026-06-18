import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
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

  @Post(':id/retry')
  @HttpCode(HttpStatus.OK)
  retry(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.payments.retry(userId, id);
  }
}
