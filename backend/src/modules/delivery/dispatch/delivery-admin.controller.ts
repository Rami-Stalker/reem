import {
  Body,
  Controller,
  Delete,
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

import { Authorize } from '../../../common/decorators/authorize.decorator';
import { AppPermission } from '../../../common/permissions';
import {
  CancelDispatchDto,
  CreateDeliveryProviderDto,
  DispatchQueryDto,
  UpdateDeliveryProviderDto,
} from '../dto/delivery-provider.dto';
import { DeliveryAdminService } from './delivery-admin.service';
import { DeliveryDispatchService } from './delivery-dispatch.service';

/**
 * The carrier desk.
 *
 * Everything the requirement asks an admin to be able to do later — choose a
 * delivery company, turn one on or off, change its settings — without touching
 * code. `order:manage` rather than a new permission, because dispatching is
 * order operations; the roles that hold it are operations and super admins,
 * and finance/support deliberately do not.
 *
 * No route here returns a credential. The carrier's secrets live in the
 * environment; this surface shows only which variables are named and whether
 * each is set.
 */
@Authorize({
  action: 'manage',
  resource: 'order',
  roles: [UserRole.SUPER_ADMIN, UserRole.OPERATIONS_ADMIN],
  permissions: [AppPermission.orderManage],
})
@Controller('admin/delivery')
export class DeliveryAdminController {
  constructor(
    private readonly admin: DeliveryAdminService,
    private readonly dispatches: DeliveryDispatchService,
  ) {}

  /** Which adapters this build can serve — the menu behind "add a carrier". */
  @Get('adapters')
  adapters() {
    return this.admin.adapters();
  }

  @Get('providers')
  list() {
    return this.admin.list();
  }

  @Post('providers')
  create(@Body() dto: CreateDeliveryProviderDto) {
    return this.admin.create(dto);
  }

  @Patch('providers/:id')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateDeliveryProviderDto,
  ) {
    return this.admin.update(id, dto);
  }

  @Post('providers/:id/enable')
  @HttpCode(HttpStatus.OK)
  enable(@Param('id', ParseUUIDPipe) id: string) {
    return this.admin.setEnabled(id, true);
  }

  @Post('providers/:id/disable')
  @HttpCode(HttpStatus.OK)
  disable(@Param('id', ParseUUIDPipe) id: string) {
    return this.admin.setEnabled(id, false);
  }

  @Delete('providers/:id')
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.admin.remove(id);
  }

  // ── Parcels with carriers ─────────────────────────────────────────────

  @Get('dispatches')
  dispatchList(@Query() query: DispatchQueryDto) {
    return this.admin.dispatches(query);
  }

  @Get('dispatches/:id/events')
  events(@Param('id', ParseUUIDPipe) id: string) {
    return this.admin.events(id);
  }

  /** Re-offer a parcel the carrier never accepted. */
  @Post('dispatches/:id/retry')
  @HttpCode(HttpStatus.OK)
  retry(@Param('id', ParseUUIDPipe) id: string) {
    return this.dispatches.retry(id);
  }

  /** Ask the carrier where a parcel is, when a callback never came. */
  @Post('dispatches/:id/refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Param('id', ParseUUIDPipe) id: string) {
    return this.dispatches.refresh(id);
  }

  @Post('dispatches/:shipmentId/cancel')
  @HttpCode(HttpStatus.OK)
  async cancel(
    @Param('shipmentId', ParseUUIDPipe) shipmentId: string,
    @Body() dto: CancelDispatchDto,
  ) {
    await this.dispatches.cancel(shipmentId, dto.reason);
    return { cancelled: true };
  }
}
