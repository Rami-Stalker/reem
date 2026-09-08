import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { AppPermission } from '../../common/permissions';
import {
  CreateExperimentDto,
  SetExperimentStatusDto,
} from './dto/experiments.dto';
import { ExperimentsService } from './experiments.service';

/**
 * Running experiments.
 *
 * Behind `analytics:read` rather than a product permission: what these change
 * is what the business believes, and the people who read the results are the
 * people who should be able to start one.
 */
@Authorize({
  action: 'read',
  resource: 'analytics',
  roles: [UserRole.SUPER_ADMIN, UserRole.OPERATIONS_ADMIN, UserRole.ADMIN],
  permissions: [AppPermission.analyticsRead],
})
@Controller('admin/experiments')
export class ExperimentsAdminController {
  constructor(private readonly experiments: ExperimentsService) {}

  @Get()
  list() {
    return this.experiments.list();
  }

  @Get(':id/results')
  results(@Param('id', ParseUUIDPipe) id: string) {
    return this.experiments.results(id);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateExperimentDto) {
    return this.experiments.create({
      key: dto.key,
      name: dto.name,
      hypothesis: dto.hypothesis,
      metric: dto.metric,
      variants: dto.variants,
      startsAt: new Date(dto.starts_at),
      endsAt: dto.ends_at ? new Date(dto.ends_at) : null,
      actorId: user.id,
    });
  }

  /** Starting and stopping. A stopped experiment cannot be restarted. */
  @Patch(':id/status')
  setStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetExperimentStatusDto,
  ) {
    return this.experiments.setStatus(id, dto.status);
  }
}
