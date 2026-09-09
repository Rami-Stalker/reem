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
import { Authorize } from '../../common/decorators/authorize.decorator';
import {
  CurrentPrincipal,
  RequestPrincipal,
} from '../../common/decorators/current-principal.decorator';
import { buyerOf } from './buyer';
import { OrderQueryDto } from './dto/order-query.dto';
import { isOrderBucket, OrdersService } from './orders.service';
import { CheckoutService } from './checkout.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { ConfirmCodOrderDto } from '../cod-trust/dto/cod-trust.dto';

/**
 * A customer's orders — and a guest's.
 *
 * `allowGuest`, the same policy the cart carries, because Q46 P1 lets a
 * visitor buy. Before this she could fill a basket and not pay for it: the
 * checkout route demanded a signed-in id, so the guest cart was a dead end.
 * Every route here scopes to `buyerOf(principal)`, which resolves to her
 * account or to the guest session she is holding — never to neither.
 */
@Authorize({ action: 'write', resource: 'cart', allowGuest: true })
@Controller('orders')
export class OrdersController {
  constructor(
    private readonly orders: OrdersService,
    private readonly checkout: CheckoutService,
  ) {}

  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post('checkout')
  @HttpCode(HttpStatus.CREATED)
  placeOrder(
    @CurrentPrincipal() principal: RequestPrincipal,
    @Body() dto: CreateOrderDto,
  ) {
    return this.checkout.checkout(buyerOf(principal), dto);
  }

  /**
   * Her orders. `?bucket=pending|processing|delivered|cancelled` narrows the
   * list to the pile the profile screen counted — an unknown value is ignored
   * rather than refused, so a stale link degrades to "everything".
   */
  @Get()
  list(
    @CurrentPrincipal() principal: RequestPrincipal,
    @Query() query: OrderQueryDto,
  ) {
    return this.orders.list(
      buyerOf(principal),
      query,
      query.bucket && isOrderBucket(query.bucket) ? query.bucket : undefined,
    );
  }

  @Get(':id')
  detail(
    @CurrentPrincipal() principal: RequestPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.orders.detail(buyerOf(principal), id);
  }

  @Get(':id/timeline')
  timeline(
    @CurrentPrincipal() principal: RequestPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.orders.timeline(buyerOf(principal), id);
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
    @CurrentPrincipal() principal: RequestPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ConfirmCodOrderDto,
  ) {
    return this.checkout.confirmCod(buyerOf(principal), id, dto.code);
  }

  @Throttle({ default: { limit: 3, ttl: 60_000 } })
  @Post(':id/cod-confirmation/resend')
  @HttpCode(HttpStatus.OK)
  resendCodConfirmation(
    @CurrentPrincipal() principal: RequestPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.checkout.resendCodConfirmation(buyerOf(principal), id);
  }

  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  cancel(
    @CurrentPrincipal() principal: RequestPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.orders.cancel(buyerOf(principal), id);
  }

  @Post(':id/reorder')
  @HttpCode(HttpStatus.OK)
  reorder(
    @CurrentPrincipal() principal: RequestPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.orders.reorder(buyerOf(principal), id);
  }
}
