import { Controller, Get, Query } from '@nestjs/common';
import { Currency, UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import { EconomicsQueryDto } from './dto/economics.dto';
import { EconomicsService, EconomicsWindow } from './economics.service';

/** The default window when a console asks without saying: the last 30 days. */
const DEFAULT_DAYS = 30;

/**
 * Marketplace economics.
 *
 * Kept apart from `/analytics`, which answers questions about activity —
 * orders, conversion, retention, cohorts. These answer a different question:
 * what the marketplace is worth to the business. A platform can win on every
 * activity metric while each order costs more to carry than it earns, and
 * until now nothing on the admin side could have told anyone that.
 */
@Authorize({
  action: 'read',
  resource: 'analytics',
  roles: [
    UserRole.SUPER_ADMIN,
    UserRole.OPERATIONS_ADMIN,
    UserRole.FINANCE_ADMIN,
    UserRole.ADMIN,
  ],
  permissions: [AppPermission.analyticsRead],
})
@Controller('admin/economics')
export class EconomicsController {
  constructor(private readonly economics: EconomicsService) {}

  @Get()
  overview(@Query() query: EconomicsQueryDto) {
    return this.economics.overview(this.window(query));
  }

  @Get('sellers')
  bySeller(@Query() query: EconomicsQueryDto) {
    return this.economics.bySeller(this.window(query), query.limit ?? 20);
  }

  @Get('categories')
  byCategory(@Query() query: EconomicsQueryDto) {
    return this.economics.byCategory(this.window(query), query.limit ?? 20);
  }

  /**
   * `to` is exclusive, and defaults to now rather than to midnight: a
   * half-finished day belongs in the figure, and rounding it away made
   * yesterday's report and today's disagree about the same orders.
   */
  private window(query: EconomicsQueryDto): EconomicsWindow {
    const to = query.to ? new Date(query.to) : new Date();
    const from = query.from
      ? new Date(query.from)
      : new Date(to.getTime() - DEFAULT_DAYS * 24 * 60 * 60 * 1000);

    return {
      from,
      to,
      currency: query.currency ?? Currency.SYP,
    };
  }
}
