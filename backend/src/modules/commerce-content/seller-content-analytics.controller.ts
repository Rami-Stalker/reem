import { Controller, Get, Param, ParseUUIDPipe, Query } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { AppPermission } from '../../common/permissions';
import { PromotersQueryDto } from './dto/promoters-query.dto';
import { ContentAnalyticsService } from './analytics/content-analytics.service';

/**
 * What a boutique can find out about its own content, and about the women
 * carrying its products around.
 *
 * A seller reaches only her own numbers — `subjectOrThrow` in the service is
 * the check, and it refuses a named `seller_id` that is not hers. Staff may
 * name one, which is what makes the same routes usable from the console.
 */
@Authorize(
  {
    action: 'read',
    resource: 'analytics',
    roles: [UserRole.SELLER],
    permissions: [AppPermission.analyticsRead],
  },
  {
    action: 'read',
    resource: 'analytics',
    roles: [
      UserRole.SUPER_ADMIN,
      UserRole.OPERATIONS_ADMIN,
      UserRole.ADMIN,
      UserRole.CONTENT_MODERATOR,
    ],
    permissions: [AppPermission.analyticsRead],
  },
)
@Controller('seller/content/analytics')
export class SellerContentAnalyticsController {
  constructor(private readonly analytics: ContentAnalyticsService) {}

  /** Posts against reels against stories. */
  @Get('overview')
  overview(
    @CurrentUser() user: AuthUser,
    @Query('seller_id') sellerId?: string,
  ) {
    return this.analytics.overview(user, sellerId);
  }

  /** How far her content has travelled onto other women's pages. */
  @Get('reshares')
  reshares(
    @CurrentUser() user: AuthUser,
    @Query('seller_id') sellerId?: string,
  ) {
    return this.analytics.reshareSummary(user, sellerId);
  }

  /**
   * The women themselves — named only where their own page is open.
   *
   * This is the list a future ambassador programme reads. The columns it will
   * need (`campaign_key`, `coupon_id`) already sit on the reshare row, so that
   * programme is a write path and a join rather than a migration of a live
   * table.
   */
  @Get('promoters')
  promoters(@CurrentUser() user: AuthUser, @Query() query: PromotersQueryDto) {
    return this.analytics.promoters(user, query, query.seller_id);
  }

  @Get('content/:id')
  forContent(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.analytics.forContent(user, id);
  }
}
