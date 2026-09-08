import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import {
  AddFlashSaleItemDto,
  CreateFlashSaleDto,
  SetFlashSaleStatusDto,
} from './dto/flash-sales.dto';
import { FlashSalesService } from './flash-sales.service';

/**
 * Running a sale.
 *
 * One controller for staff and sellers rather than two, because the rules that
 * separate them are about *ownership* and belong in the service: a seller may
 * only touch her own sale and put her own listings in it, and the service
 * enforces both from the role it is handed. Two controllers would mean two
 * copies of that check, and eventually one of them would be wrong.
 */
@Authorize({
  action: 'manage',
  resource: 'product',
  roles: [
    UserRole.SUPER_ADMIN,
    UserRole.OPERATIONS_ADMIN,
    UserRole.ADMIN,
    UserRole.SELLER,
  ],
  permissions: [AppPermission.productManage],
})
@Controller('flash-sales/manage')
export class FlashSalesAdminController {
  constructor(private readonly sales: FlashSalesService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return user.role === UserRole.SELLER
      ? this.sales.listForSeller(user.id)
      : this.sales.listAll();
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateFlashSaleDto) {
    return this.sales.create({
      title: dto.title,
      note: dto.note,
      startsAt: new Date(dto.starts_at),
      endsAt: new Date(dto.ends_at),
      actorId: user.id,
      actorRole: user.role,
      sellerId: dto.seller_id ?? null,
    });
  }

  @Post(':id/items')
  addItem(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AddFlashSaleItemDto,
  ) {
    return this.sales.addItem({
      saleId: id,
      offerId: dto.offer_id,
      salePrice: dto.sale_price,
      quantityCap: dto.quantity_cap ?? null,
      fundedBySeller: dto.funded_by_seller,
      actorId: user.id,
      actorRole: user.role,
    });
  }

  @Delete(':id/items/:itemId')
  removeItem(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
  ) {
    return this.sales.removeItem(id, itemId, user.id, user.role);
  }

  /** Going live, and the stop button. */
  @Patch(':id/status')
  setStatus(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetFlashSaleStatusDto,
  ) {
    return this.sales.setStatus(id, dto.status, user.id, user.role);
  }

  @Delete(':id')
  remove(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.sales.remove(id, user.id, user.role);
  }
}
