import { Controller, Get, Query } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import {
  AdminIntelligenceService,
  BRIEFING_WINDOW_DAYS,
} from './admin-intelligence.service';

class BriefingQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(365)
  window_days?: number;
}

/**
 * The morning briefing.
 *
 * What separates it from the rest of the console is that every row names its
 * evidence and an action. A dashboard that reports a churn rate without saying
 * which customers, worth how much, and what would plausibly help is one people
 * check on Monday and stop checking by March.
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
@Controller('admin/intelligence')
export class AdminIntelligenceController {
  constructor(private readonly intelligence: AdminIntelligenceService) {}

  @Get('briefing')
  briefing(@Query() query: BriefingQueryDto) {
    return this.intelligence.briefing(
      query.window_days ?? BRIEFING_WINDOW_DAYS,
    );
  }

  /** The same numbers without the advice, for a screen that draws its own. */
  @Get('facts')
  facts(@Query() query: BriefingQueryDto) {
    return this.intelligence.gather(query.window_days ?? BRIEFING_WINDOW_DAYS);
  }
}
