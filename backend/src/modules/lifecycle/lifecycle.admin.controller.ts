import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import {
  LifecycleStageQueryDto,
  ReengagementRunDto,
  ReengagementReportDto,
} from './dto/lifecycle.dto';
import { CustomerSegmentsService } from './customer-segments.service';
import { ReengagementService } from './reengagement.service';
import { LIFECYCLE_STAGES, SEGMENT_RULES } from './customer-segments';

/**
 * Who the customers are, and reaching the ones worth reaching.
 *
 * The sends are POSTs a person triggers rather than a schedule that runs
 * itself. A cron that pushes notifications to a few hundred women every hour
 * is the kind of thing that should be turned on deliberately, by somebody who
 * has read what it says — so the jobs exist and the scheduling is left to be
 * configured rather than assumed.
 */
@Authorize({
  action: 'read',
  resource: 'analytics',
  roles: [
    UserRole.SUPER_ADMIN,
    UserRole.OPERATIONS_ADMIN,
    UserRole.ADMIN,
  ],
  permissions: [AppPermission.analyticsRead],
})
@Controller('admin/lifecycle')
export class LifecycleAdminController {
  constructor(
    private readonly segments: CustomerSegmentsService,
    private readonly reengagement: ReengagementService,
  ) {}

  /** How the customer base sits across the lifecycle. */
  @Get('distribution')
  distribution() {
    return this.segments.distribution();
  }

  /** The thresholds behind every figure on this screen. */
  @Get('rules')
  rules() {
    return { stages: LIFECYCLE_STAGES, thresholds: SEGMENT_RULES };
  }

  @Get('stage')
  async stage(@Query() query: LifecycleStageQueryDto) {
    const rows = await this.segments.stage(query.stage, query.limit);
    return {
      data: rows.map((row) => ({
        user_id: row.userId,
        stage: row.stage,
        orders: row.orders,
        last_order_at: row.lastOrderAt?.toISOString() ?? null,
      })),
    };
  }

  @Get('abandoned-carts')
  async abandoned(@Query() query: ReengagementRunDto) {
    const baskets = await this.segments.abandonedBaskets(query.limit ?? 100);
    return {
      data: baskets.map((basket) => ({
        user_id: basket.userId,
        items: basket.items,
        lead_title: basket.leadTitle,
        last_touched_at: basket.lastTouchedAt.toISOString(),
      })),
    };
  }

  @Get('reengagement/report')
  report(@Query() query: ReengagementReportDto) {
    return this.reengagement.report(query.days ?? 30);
  }

  @Post('reengagement/abandoned-carts')
  nudgeCarts(@Body() dto: ReengagementRunDto) {
    return this.reengagement.nudgeAbandonedBaskets(dto.limit ?? 200);
  }

  @Post('reengagement/win-back')
  winBack(@Body() dto: ReengagementRunDto) {
    return this.reengagement.winBack(dto.stage ?? 'lapsed', dto.limit ?? 200, {
      minProjectedValue: dto.min_projected_value,
    });
  }

  /** Marks the touches an order followed. Safe to re-run. */
  @Post('reengagement/attribute')
  attribute(@Body() dto: ReengagementReportDto) {
    return this.reengagement.attribute(dto.days ?? 7);
  }
}
