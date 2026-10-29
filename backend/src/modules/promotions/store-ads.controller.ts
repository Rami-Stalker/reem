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
  CampaignDraftDto,
  LaunchCampaignDto,
  PlanPaymentReferenceDto,
  PlanPurchaseDto,
  SetPromotionStatusDto,
  SubscribePlanDto,
  toAudience,
} from './dto/promotions.dto';
import { AdPlanPaymentsService } from './ad-plan-payments.service';
import { PromotionsService } from './promotions.service';
import { StoreAdsService } from './store-ads.service';

function windowOf(dto: CampaignDraftDto) {
  const startsAt = dto.starts_at ? new Date(dto.starts_at) : new Date();
  const endsAt = new Date(startsAt.getTime() + dto.days * 86_400_000);
  return { startsAt, endsAt };
}

/**
 * «مركز الإعلانات» — a boutique's own advertising: her plan, quotes,
 * suggestions, campaigns and how they did.
 *
 * Sellers only, and always about the caller: there is no seller id in any
 * path or body here, so there is nothing to point at somebody else's shop.
 */
@Authorize({
  action: 'manage',
  resource: 'product',
  roles: [UserRole.SELLER],
  permissions: [AppPermission.productManage],
})
@Controller('ads')
export class StoreAdsController {
  constructor(
    private readonly ads: StoreAdsService,
    private readonly promotions: PromotionsService,
    private readonly payments: AdPlanPaymentsService,
  ) {}

  @Get('plans')
  plans(@CurrentUser() user: AuthUser) {
    return this.ads.plans(user.id);
  }

  /** Paid from her earnings, now; an upgrade carries her unused credit over. */
  @Post('plans/subscribe')
  subscribe(@CurrentUser() user: AuthUser, @Body() dto: SubscribePlanDto) {
    return this.ads.subscribe(user.id, dto.tier);
  }

  /** Her earnings balance and the transfer methods finance accepts. */
  @Get('plans/payment-options')
  paymentOptions(@CurrentUser() user: AuthUser) {
    return this.payments.options(user.id);
  }

  /**
   * Pays for a plan. From earnings it is instant and answers with the plans;
   * by transfer it answers with the purchase and where to send the money.
   */
  @Post('plans/purchases')
  async purchase(@CurrentUser() user: AuthUser, @Body() dto: PlanPurchaseDto) {
    if (dto.method === 'EARNINGS') {
      return { plans: await this.ads.subscribe(user.id, dto.tier), purchase: null };
    }
    return {
      plans: null,
      purchase: await this.payments.request(user.id, dto.tier, dto.method),
    };
  }

  @Get('plans/purchases')
  purchases(@CurrentUser() user: AuthUser) {
    return this.payments.mine(user.id);
  }

  @Post('plans/purchases/:id/reference')
  submitReference(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PlanPaymentReferenceDto,
  ) {
    return this.payments.submitReference(user.id, id, dto.reference);
  }

  @Post('plans/purchases/:id/cancel')
  cancelPurchase(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.payments.cancel(user.id, id);
  }

  @Post('quote')
  quote(@CurrentUser() user: AuthUser, @Body() dto: CampaignDraftDto) {
    return this.ads.quote(user.id, {
      offerId: dto.offer_id,
      placement: dto.placement,
      ...windowOf(dto),
      audience: toAudience(dto.audience),
    });
  }

  @Get('suggestions')
  suggestions(@CurrentUser() user: AuthUser) {
    return this.ads.suggestions(user.id);
  }

  @Get('overview')
  overview(@CurrentUser() user: AuthUser) {
    return this.ads.overview(user.id);
  }

  @Get('audience/governorates')
  governorates() {
    return this.ads.governorates();
  }

  @Get('campaigns')
  campaigns(@CurrentUser() user: AuthUser) {
    return this.promotions.listForSeller(user.id);
  }

  /** Creates the campaign and, unless `launch` is false, takes the fee and starts it. */
  @Post('campaigns')
  async launch(@CurrentUser() user: AuthUser, @Body() dto: LaunchCampaignDto) {
    const created = await this.promotions.create({
      offerId: dto.offer_id,
      placement: dto.placement,
      fee: dto.fee !== undefined ? Money.of(dto.fee, Currency.SYP) : undefined,
      ...windowOf(dto),
      audience: toAudience(dto.audience),
      contentId: dto.content_id,
      actorId: user.id,
      actorRole: user.role,
    });
    if (dto.launch === false) return created;
    return this.promotions.activate(created.id, user.id, user.role);
  }

  @Patch('campaigns/:id/status')
  setStatus(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetPromotionStatusDto,
  ) {
    return this.promotions.setStatus(id, dto.status, user.id, user.role);
  }
}
