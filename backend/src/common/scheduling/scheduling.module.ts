import { Global, Module } from '@nestjs/common';
import { DiscoveryModule as NestDiscoveryModule } from '@nestjs/core';
import { JobLeaseRepository } from './job-lease.repository';
import { JobRunner } from './job-runner.service';
import { JobsHealthController, JobTriggerController } from './scheduling.controller';

/**
 * Scheduled jobs: discovery, leases, the run record and its health report.
 *
 * Replaces `ScheduleModule.forRoot()`. Jobs keep living beside the code they
 * sweep, declared with `@ScheduledJob`; this module finds them.
 *
 * (`NestDiscoveryModule` is Nest's provider discovery, aliased because this
 * application has a product `DiscoveryModule` of its own.)
 */
@Global()
@Module({
  imports: [NestDiscoveryModule],
  controllers: [JobsHealthController, JobTriggerController],
  providers: [JobLeaseRepository, JobRunner],
  exports: [JobRunner],
})
export class SchedulingModule {}
