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
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { isOrderBucket, OrdersService } from './orders.service';
import { CheckoutService } from './checkout.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { ConfirmCodOrderDto } from '../cod-trust/dto/cod-trust.dto';

@Controller('orders')
export class OrdersController {
  constructor(
    private readonly orders: OrdersService,
    private readonly checkout: CheckoutService,
  ) {}

  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post('checkout')
  @HttpCode(HttpStatus.CREATED)
  placeOrder(@CurrentUser('id') userId: string, @Body() dto: CreateOrderDto) {
    return this.checkout.checkout(userId, dto);
  }

  /**
   * Her orders. `?bucket=pending|processing|delivered|cancelled` narrows the
   * list to the pile the profile screen counted — an unknown value is ignored
   * rather than refused, so a stale link degrades to "everything".
   */
  @Get()
  list(
    @CurrentUser('id') userId: string,
    @Query() page: PaginationDto,
    @Query('bucket') bucket?: string,
  ) {
    return this.orders.list(
      userId,
      page,
      bucket && isOrderBucket(bucket) ? bucket : undefined,
    );
  }

  @Get(':id')
  detail(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.orders.detail(userId, id);
  }

  @Get(':id/timeline')
  timeline(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.orders.timeline(userId, id);
  }

  /**
   * Releases a cash order the trust engine held for a code.
   *
   * Throttled harder than the rest of the controller: the code is six digits
   * against one order, and the challenge's own attempt counter is the second
   * line rather than the first.
   */
  @Throttle({ default: { limit: 6, ttl: 60_000 } })
  @Post(':id/cod-confirmation')
  @HttpCode(HttpStatus.OK)
  confirmCod(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ConfirmCodOrderDto,
  ) {
    return this.checkout.confirmCod(userId, id, dto.code);
  }

  @Throttle({ default: { limit: 3, ttl: 60_000 } })
  @Post(':id/cod-confirmation/resend')
  @HttpCode(HttpStatus.OK)
  resendCodConfirmation(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.checkout.resendCodConfirmation(userId, id);
  }

  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  cancel(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.orders.cancel(userId, id);
  }

  @Post(':id/reorder')
  @HttpCode(HttpStatus.OK)
  reorder(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.orders.reorder(userId, id);
  }
}
