import { Module } from '@nestjs/common';
import { ExperimentsAdminController } from './experiments.admin.controller';
import { ExperimentsController } from './experiments.controller';
import { ExperimentsService } from './experiments.service';

/**
 * A/B testing.
 *
 * Exported so any module can ask which arm a customer is in. Nothing here
 * depends on anything else, deliberately — an experiment framework that can
 * take a page down with it is worse than no experiments, and `variantFor`
 * answers `control` for every failure it can meet.
 */
@Module({
  controllers: [ExperimentsController, ExperimentsAdminController],
  providers: [ExperimentsService],
  exports: [ExperimentsService],
})
export class ExperimentsModule {}
