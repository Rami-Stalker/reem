import { Body, Controller, Get, Header, Post, Query, Res } from '@nestjs/common';
import { Response } from 'express';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { AnalyticsService } from './analytics.service';
import {
  AnalyticsExportQueryDto,
  AnalyticsQueryDto,
  TrackAnalyticsEventDto,
} from './dto/analytics.dto';

const dashboardRoles = [
  UserRole.SUPER_ADMIN,
  UserRole.OPERATIONS_ADMIN,
  UserRole.SUPPORT_ADMIN,
  UserRole.FINANCE_ADMIN,
  UserRole.CONTENT_MODERATOR,
  UserRole.ADMIN,
  UserRole.SUPPORT,
  UserRole.SELLER,
];

/**
 * The event firehose in, the dashboards out.
 *
 * Reading a dashboard is declarative and named below. Writing an event is not:
 * the row is stamped with the caller's own id, and there is no parameter that
 * would let her attribute it to somebody else.
 */
@SelfScoped(
  "a tracked event is written against the caller's own user id, taken from her token and never from the body",
)
@Controller('analytics')
export class AnalyticsController {
  constructor(private readonly analytics: AnalyticsService) {}

  @Post('events')
  track(
    @CurrentUser('id') userId: string,
    @Body() dto: TrackAnalyticsEventDto,
  ) {
    return this.analytics.track(userId, dto);
  }

  @Roles(...dashboardRoles)
  @Get('dashboard')
  dashboard(
    @CurrentUser() user: { id: string; role: UserRole },
    @Query() query: AnalyticsQueryDto,
  ) {
    return this.analytics.dashboard(query, user);
  }

  @Roles(...dashboardRoles)
  @Get('sales')
  sales(
    @CurrentUser() user: { id: string; role: UserRole },
    @Query() query: AnalyticsQueryDto,
  ) {
    return this.analytics.sales(query, user);
  }

  @Roles(...dashboardRoles)
  @Get('revenue')
  revenue(
    @CurrentUser() user: { id: string; role: UserRole },
    @Query() query: AnalyticsQueryDto,
  ) {
    return this.analytics.revenue(query, user);
  }

  @Roles(...dashboardRoles)
  @Get('products')
  products(
    @CurrentUser() user: { id: string; role: UserRole },
    @Query() query: AnalyticsQueryDto,
  ) {
    return this.analytics.productPerformance(query, user);
  }

  @Roles(...dashboardRoles)
  @Get('sellers')
  sellers(
    @CurrentUser() user: { id: string; role: UserRole },
    @Query() query: AnalyticsQueryDto,
  ) {
    return this.analytics.sellerPerformance(query, user);
  }

  @Roles(...dashboardRoles)
  @Get('customers')
  customers(
    @CurrentUser() user: { id: string; role: UserRole },
    @Query() query: AnalyticsQueryDto,
  ) {
    return this.analytics.customerAnalytics(query, user);
  }

  @Roles(...dashboardRoles)
  @Get('conversion')
  conversion(
    @CurrentUser() user: { id: string; role: UserRole },
    @Query() query: AnalyticsQueryDto,
  ) {
    return this.analytics.conversion(query, user);
  }

  @Roles(...dashboardRoles)
  @Get('funnel')
  funnel(
    @CurrentUser() user: { id: string; role: UserRole },
    @Query() query: AnalyticsQueryDto,
  ) {
    return this.analytics.funnel(query, user);
  }

  @Roles(...dashboardRoles)
  @Get('retention')
  retention(
    @CurrentUser() user: { id: string; role: UserRole },
    @Query() query: AnalyticsQueryDto,
  ) {
    return this.analytics.retention(query, user);
  }

  @Roles(...dashboardRoles)
  @Get('cohorts')
  cohorts(
    @CurrentUser() user: { id: string; role: UserRole },
    @Query() query: AnalyticsQueryDto,
  ) {
    return this.analytics.cohorts(query, user);
  }

  @Roles(...dashboardRoles)
  @Get('realtime')
  realtime(@CurrentUser() user: { id: string; role: UserRole }) {
    return this.analytics.realtime(user);
  }

  @Roles(...dashboardRoles)
  @Get('export')
  @Header('Cache-Control', 'no-store')
  async export(
    @CurrentUser() user: { id: string; role: UserRole },
    @Query() query: AnalyticsExportQueryDto,
    @Res() response: Response,
  ) {
    const file = await this.analytics.export(query, user);
    response.setHeader('Content-Type', file.contentType);
    response.setHeader(
      'Content-Disposition',
      `attachment; filename="${file.filename}"`,
    );
    response.send(file.buffer);
  }
}
