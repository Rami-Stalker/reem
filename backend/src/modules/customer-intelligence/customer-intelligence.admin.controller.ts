import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import {
  CustomerBandQueryDto,
  CustomerSweepDto,
} from './dto/customer-intelligence.dto';
import { CustomerIntelligenceService } from './customer-intelligence.service';

/**
 * What the platform has worked out about its customers.
 *
 * Behind `analytics:read`. These are aggregate business readings, not support
 * tooling — nothing here shows a phone number or an address, and the per-
 * customer route returns scores and the reasons behind them, not her history.
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
@Controller('admin/customers/intelligence')
export class CustomerIntelligenceAdminController {
  constructor(private readonly intelligence: CustomerIntelligenceService) {}

  /** How the base sits across the bands, and what is at risk. */
  @Get('distribution')
  distribution() {
    return this.intelligence.distribution();
  }

  @Get('band')
  inBand(@Query() query: CustomerBandQueryDto) {
    return this.intelligence.inBand({
      dimension: query.dimension,
      band: query.band,
      limit: query.limit,
      skip: query.skip,
      minValue: query.min_value,
    });
  }

  /**
   * One customer's cached profile.
   *
   * A customer nobody has scored yet is a 404 rather than a `null`. Returning
   * `null` from a handler is an empty 200 on the wire — no body at all — which
   * no JSON client can read: the console's own `getJson` throws on it. "There
   * is no reading for her yet" is exactly what a 404 says, and `POST
   * :id/refresh` is how one gets made.
   */
  @Get(':id')
  async profile(@Param('id', ParseUUIDPipe) id: string) {
    const profile = await this.intelligence.profile(id);
    if (!profile) throw new NotFoundException('No reading for this customer yet');
    return profile;
  }

  /** Recomputes one customer now, ignoring the cache. */
  @Post(':id/refresh')
  refresh(@Param('id', ParseUUIDPipe) id: string) {
    return this.intelligence.refresh(id);
  }

  @Post('sweep')
  sweep(@Body() dto: CustomerSweepDto) {
    return this.intelligence.sweep({
      sinceDays: dto.since_days ?? 7,
      limit: dto.limit ?? 2000,
    });
  }
}
