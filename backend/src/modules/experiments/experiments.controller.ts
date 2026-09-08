import { Body, Controller, Get, Post } from '@nestjs/common';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { RecordExperimentEventDto } from './dto/experiments.dto';
import { ExperimentsService } from './experiments.service';

/**
 * What this customer is in, and what she did about it.
 *
 * Signed-in only. A guest could be bucketed on a session id, but she cannot be
 * followed to a conversion reliably, and an experiment measured on a
 * population half of whom vanish between exposure and purchase reports the
 * survival rate of sessions rather than the effect of the change.
 */
@Controller('experiments')
export class ExperimentsController {
  constructor(private readonly experiments: ExperimentsService) {}

  /** Every running experiment's answer for her, in one round trip. */
  @Get('me')
  mine(@CurrentUser() user: AuthUser) {
    return this.experiments.allFor(user.id);
  }

  /** She saw it. Idempotent. */
  @Post('exposure')
  exposure(
    @CurrentUser() user: AuthUser,
    @Body() dto: RecordExperimentEventDto,
  ) {
    return this.experiments.recordExposure(dto.key, user.id);
  }

  /** She did the thing. Idempotent per metric. */
  @Post('conversion')
  conversion(
    @CurrentUser() user: AuthUser,
    @Body() dto: RecordExperimentEventDto,
  ) {
    return this.experiments.recordConversion(dto.key, user.id, {
      metric: dto.metric,
    });
  }
}
