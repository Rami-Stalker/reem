import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { Currency, UserRole } from '@prisma/client';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import { Money } from '../../common/money';
import {
  CreatePromotionDto,
  SetPromotionStatusDto,
  toAudience,
} from './dto/promotions.dto';
import { PromotionsService } from './promotions.service';

/**
 * Buying a slot.
 *
 * A seller manages her own placements; staff see everything. Ownership is
 * enforced in the service from the role on the token, so there is no seller
 * parameter anywhere here to tamper with.
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
@Controller('promotions')
export class PromotionsController {
  constructor(private readonly promotions: PromotionsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return user.role === UserRole.SELLER
      ? this.promotions.listForSeller(user.id)
      : this.promotions.listAll();
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreatePromotionDto) {
    return this.promotions.create({
      offerId: dto.offer_id,
      placement: dto.placement,
      fee: dto.fee !== undefined ? Money.of(dto.fee, Currency.SYP) : undefined,
      startsAt: new Date(dto.starts_at),
      endsAt: new Date(dto.ends_at),
      audience: toAudience(dto.audience),
      contentId: dto.content_id,
      actorId: user.id,
      actorRole: user.role,
    });
  }

  /** Going live takes the fee; pausing does not give it back. */
  @Patch(':id/status')
  setStatus(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetPromotionStatusDto,
  ) {
    return this.promotions.setStatus(id, dto.status, user.id, user.role);
  }
}
