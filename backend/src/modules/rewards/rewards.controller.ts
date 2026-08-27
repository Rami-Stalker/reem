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
import { Currency, UserRole } from '@prisma/client';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { CouponsService } from './coupons.service';
import { MembershipService } from './membership.service';
import { PointsService } from './points.service';
import { ReferralsService } from './referrals.service';
import {
  ApplyReferralCodeDto,
  CreateMembershipTierDto,
  CreateCouponDto,
  CreateReferralCodeDto,
  RedeemCashbackDto,
  RedeemPointsDto,
  UpdateCouponDto,
  UpsertLoyaltyRewardDto,
  ValidateCouponDto,
} from './dto/rewards.dto';
import { Money } from '../../common/money';

@Controller('coupons')
export class CouponsController {
  constructor(private readonly coupons: CouponsService) {}

  // Customer
  @Get()
  listAvailable(@CurrentUser('id') userId: string) {
    return this.coupons.listAvailable(userId);
  }

  @Post('validate')
  @HttpCode(HttpStatus.OK)
  validate(@CurrentUser('id') userId: string, @Body() dto: ValidateCouponDto) {
    return this.coupons.validate(
      dto.code,
      userId,
      Money.of(dto.subtotal, dto.currency ?? Currency.SYP),
    );
  }

  // Admin / support (read) and admin (write)
  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  @Get('all')
  listAll(@Query() page: PaginationDto) {
    return this.coupons.listAll(page);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@Body() dto: CreateCouponDto) {
    return this.coupons.create(dto);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  @Patch(':id/activate')
  activate(@Param('id', ParseUUIDPipe) id: string) {
    return this.coupons.setActive(id, true);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  @Patch(':id/deactivate')
  deactivate(@Param('id', ParseUUIDPipe) id: string) {
    return this.coupons.setActive(id, false);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  @Patch(':id')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCouponDto,
  ) {
    return this.coupons.update(id, dto);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.coupons.remove(id);
  }
}

@Controller('rewards')
export class RewardsController {
  constructor(
    private readonly points: PointsService,
    private readonly membership: MembershipService,
  ) {}

  @Get()
  balance(@CurrentUser('id') userId: string) {
    return this.membership.summary(userId);
  }

  @Get('history')
  history(@CurrentUser('id') userId: string, @Query() page: PaginationDto) {
    return this.points.history(userId, page);
  }

  @Post('redeem')
  @HttpCode(HttpStatus.OK)
  redeem(@CurrentUser('id') userId: string, @Body() dto: RedeemPointsDto) {
    return this.points.redeem(userId, dto.points);
  }

  @Get('membership')
  membershipSummary(@CurrentUser('id') userId: string) {
    return this.membership.summary(userId);
  }

  @Get('membership/rewards')
  membershipRewards(@CurrentUser('id') userId: string) {
    return this.membership.availableRewards(userId);
  }

  @Post('membership/rewards/:id/redeem')
  @HttpCode(HttpStatus.OK)
  redeemMembershipReward(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.membership.redeemReward(userId, id);
  }

  @Post('cashback/redeem')
  @HttpCode(HttpStatus.OK)
  redeemCashback(
    @CurrentUser('id') userId: string,
    @Body() dto: RedeemCashbackDto,
  ) {
    return this.membership.redeemCashback(userId, dto);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  @Get('admin/loyalty/analytics')
  loyaltyAnalytics() {
    return this.membership.adminAnalytics();
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  @Post('admin/loyalty/tiers')
  @HttpCode(HttpStatus.CREATED)
  upsertTier(@Body() dto: CreateMembershipTierDto) {
    return this.membership.upsertTier(dto);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN)
  @Post('admin/loyalty/rewards')
  @HttpCode(HttpStatus.CREATED)
  upsertReward(@Body() dto: UpsertLoyaltyRewardDto) {
    return this.membership.upsertReward(dto);
  }
}

@Controller('referrals')
export class ReferralsController {
  constructor(private readonly referrals: ReferralsService) {}

  @Get('me')
  overview(@CurrentUser('id') userId: string) {
    return this.referrals.overview(userId);
  }

  @Post('codes')
  @HttpCode(HttpStatus.CREATED)
  createCode(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateReferralCodeDto,
  ) {
    return this.referrals.getOrCreateCode(userId, dto);
  }

  @Post('apply')
  @HttpCode(HttpStatus.OK)
  applyCode(
    @CurrentUser('id') userId: string,
    @Body() dto: ApplyReferralCodeDto,
  ) {
    return this.referrals.applyCode(userId, dto);
  }

  @Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
  @Get('analytics')
  analytics() {
    return this.referrals.analytics();
  }
}
