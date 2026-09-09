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
import { UserRole } from '@prisma/client';

import { Authorize } from '../../common/decorators/authorize.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { AppPermission } from '../../common/permissions';
import {
  HandOverDto,
  SellerCancelOrderDto,
  SellerDeliverDto,
  SellerQueueQueryDto,
} from './dto/seller-order.dto';
import { SellerOrdersService } from './seller-orders.service';

/**
 * The seller's order queue — the screen she lives in.
 *
 * Every route is scoped to her own parcels twice over: the guard's ownership
 * rule refuses a parcel that is not hers before the handler runs, and the
 * service checks again because it is callable from places a guard is not.
 *
 * `requireSellerVerified` for the same reason the overview carries it — an
 * applicant whose file is still pending holds a normal session now, and
 * fulfilling orders is not something a pending file should be able to do.
 */
@Authorize({
  action: 'manage',
  resource: 'order',
  roles: [UserRole.SELLER],
  permissions: [AppPermission.orderRead],
  requireSellerVerified: true,
})
@Controller('seller/orders')
export class SellerOrdersController {
  constructor(private readonly orders: SellerOrdersService) {}

  /** Her queue with the counts each tab's badge needs. */
  @Get()
  queue(@CurrentUser() user: AuthUser, @Query() query: SellerQueueQueryDto) {
    return this.orders.queue(user, query.tab, query);
  }

  @Get(':id')
  @Authorize({
    action: 'read',
    resource: 'order',
    roles: [UserRole.SELLER],
    ownership: { resource: 'sellerOrder', param: 'id' },
  })
  detail(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.orders.detail(user, id);
  }

  /** Q37 «قيد التجهيز» — and the point after which the customer can no
   * longer edit the order (Q39). */
  @Post(':id/confirm')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'manage',
    resource: 'order',
    roles: [UserRole.SELLER],
    ownership: { resource: 'sellerOrder', param: 'id' },
  })
  confirm(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.orders.confirm(user, id);
  }

  /** Q37 «جاهز للشحن». */
  @Post(':id/ready')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'manage',
    resource: 'order',
    roles: [UserRole.SELLER],
    ownership: { resource: 'sellerOrder', param: 'id' },
  })
  ready(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.orders.ready(user, id);
  }

  /** Q57 — only for a parcel she carries herself. */
  @Post(':id/hand-over')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'manage',
    resource: 'order',
    roles: [UserRole.SELLER],
    ownership: { resource: 'sellerOrder', param: 'id' },
  })
  handOver(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: HandOverDto,
  ) {
    return this.orders.handOver(user, id, dto.carrier);
  }

  /** Q57 — she delivered it herself; this is what settles the sale. */
  @Post(':id/deliver')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'manage',
    resource: 'order',
    roles: [UserRole.SELLER],
    ownership: { resource: 'sellerOrder', param: 'id' },
  })
  deliver(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SellerDeliverDto,
  ) {
    return this.orders.deliver(user, id, {
      collected: dto.collected,
      note: dto.note,
    });
  }

  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'manage',
    resource: 'order',
    roles: [UserRole.SELLER],
    ownership: { resource: 'sellerOrder', param: 'id' },
  })
  cancel(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SellerCancelOrderDto,
  ) {
    return this.orders.cancel(user, id, dto.reason);
  }
}
