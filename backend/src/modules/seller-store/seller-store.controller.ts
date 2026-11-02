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
  Put,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import {
  ActivityQueryDto,
  InviteTeamMemberDto,
  UpdateShippingSettingsDto,
  UpdateStorePoliciesDto,
  UpdateTeamMemberDto,
} from './dto/seller-store.dto';
import { SellerStoreService } from './seller-store.service';

/** The owner's settings for her shop. */
@Controller('seller')
export class SellerStoreController {
  constructor(private readonly store: SellerStoreService) {}

  @Get('store-settings/policies')
  @Roles(UserRole.SELLER)
  policies(@CurrentUser('id') sellerId: string) {
    return this.store.policies(sellerId);
  }

  @Put('store-settings/policies')
  @Roles(UserRole.SELLER)
  updatePolicies(
    @CurrentUser('id') sellerId: string,
    @Body() dto: UpdateStorePoliciesDto,
  ) {
    return this.store.updatePolicies(sellerId, dto);
  }

  @Get('store-settings/shipping')
  @Roles(UserRole.SELLER)
  shipping(@CurrentUser('id') sellerId: string) {
    return this.store.shipping(sellerId);
  }

  @Put('store-settings/shipping')
  @Roles(UserRole.SELLER)
  updateShipping(
    @CurrentUser('id') sellerId: string,
    @Body() dto: UpdateShippingSettingsDto,
  ) {
    return this.store.updateShipping(sellerId, dto);
  }

  @Get('team')
  @Roles(UserRole.SELLER)
  team(@CurrentUser('id') sellerId: string) {
    return this.store.team(sellerId);
  }

  @Post('team')
  @Roles(UserRole.SELLER)
  invite(
    @CurrentUser('id') sellerId: string,
    @Body() dto: InviteTeamMemberDto,
  ) {
    return this.store.invite(sellerId, dto);
  }

  @Patch('team/:id')
  @Roles(UserRole.SELLER)
  changeRole(
    @CurrentUser('id') sellerId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateTeamMemberDto,
  ) {
    return this.store.changeRole(sellerId, id, dto.role);
  }

  @Delete('team/:id')
  @Roles(UserRole.SELLER)
  remove(
    @CurrentUser('id') sellerId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.store.remove(sellerId, id);
  }

  @Get('activity')
  @Roles(UserRole.SELLER)
  activity(
    @CurrentUser('id') sellerId: string,
    @Query() query: ActivityQueryDto,
  ) {
    return this.store.activity(sellerId, query);
  }
}

/** The member's side: invitations and the shops she works in. */
@SelfScoped(
  'Every query is keyed on the caller: memberships where member_id is her own id.',
)
@Controller('store-memberships')
export class StoreMembershipsController {
  constructor(private readonly store: SellerStoreService) {}

  @Get()
  mine(@CurrentUser('id') userId: string) {
    return this.store.memberships(userId);
  }

  @Post(':id/accept')
  @HttpCode(HttpStatus.OK)
  accept(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.store.respond(userId, id, true);
  }

  @Post(':id/decline')
  @HttpCode(HttpStatus.OK)
  decline(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.store.respond(userId, id, false);
  }

  @Post(':id/leave')
  @HttpCode(HttpStatus.OK)
  leave(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.store.leave(userId, id);
  }
}

/** What a shopper reads about a shop. */
@Controller('sellers')
export class SellerStoreInfoController {
  constructor(private readonly store: SellerStoreService) {}

  @Public()
  @Get(':id/store-info')
  info(@Param('id', ParseUUIDPipe) id: string) {
    return this.store.publicInfo(id);
  }
}
