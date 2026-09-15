import {
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  NotFoundException,
  Param,
  Post,
  Res,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Throttle } from '@nestjs/throttler';
import type { Response } from 'express';
import { createHash, timingSafeEqual } from 'node:crypto';
import { Public } from '../decorators/public.decorator';
import { JobRunner } from './job-runner.service';

/**
 * Whether the scheduled jobs are actually running.
 *
 * A scheduler fails quietly by nature: nothing errors when a timer never
 * fires. So the one thing an uptime monitor must be able to ask, from outside,
 * is "has escrow been released, have stale orders been expired, is the OTP
 * outbox moving" — and be told no with a status code it can alert on.
 *
 * 200 while every critical job has succeeded within its window, 503 when one
 * has not or keeps failing. **Do not use this as the host's health check**: a
 * deploy must not be refused because a nightly job ran yesterday. That is
 * `/health/ready`. Point an external monitor here instead.
 *
 * Carries names, times and statuses — never error text, which can include
 * row data and belongs in the logs.
 */
@Controller('health')
export class JobsHealthController {
  constructor(private readonly runner: JobRunner) {}

  @Public()
  @Get('jobs')
  async jobs(@Res({ passthrough: true }) res: Response) {
    const jobs = await this.runner.report();
    const failing = jobs.filter(
      (job) => job.critical && (job.overdue || job.consecutive_failures >= 3),
    );
    const degraded = failing.length > 0;
    res.status(degraded ? HttpStatus.SERVICE_UNAVAILABLE : HttpStatus.OK);
    return {
      status: degraded ? 'degraded' : 'ok',
      scheduler_enabled_here: this.runner.schedulingHere,
      failing: failing.map((job) => job.name),
      overdue: jobs.filter((job) => job.overdue).map((job) => job.name),
      jobs,
      timestamp: new Date().toISOString(),
    };
  }
}

/**
 * Runs a job on demand — for an external scheduler, or an operator.
 *
 * Off unless `JOBS_TRIGGER_SECRET` is set: without it the route answers 404,
 * as if it did not exist. With it, the caller sends the secret in
 * `X-Reem-Job-Secret` and the job runs **under the same lease** as a scheduled
 * run, so an external cron firing while the in-process timer also fires still
 * runs it once.
 *
 * Answers 202 at once and runs in the background: a nightly sweep takes
 * minutes, and an HTTP caller that times out must not be what cuts it short.
 */
@Controller('internal/jobs')
export class JobTriggerController {
  constructor(
    private readonly runner: JobRunner,
    private readonly config: ConfigService,
  ) {}

  @Public()
  @Post(':name/run')
  @HttpCode(HttpStatus.ACCEPTED)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  trigger(
    @Param('name') name: string,
    @Headers('x-reem-job-secret') secret: string | undefined,
  ) {
    const expected = this.config.get<string>('scheduler.triggerSecret') ?? '';
    if (!expected) throw new NotFoundException();
    if (!secret || !sameSecret(secret, expected)) {
      throw new UnauthorizedException('Invalid job trigger secret');
    }
    if (!this.runner.has(name)) {
      throw new NotFoundException({ message: 'Unknown job', jobs: this.runner.names() });
    }
    void this.runner.run(name, 'manual');
    return { accepted: true, name };
  }
}

/** Constant-time, and length-independent: both sides are hashed first. */
function sameSecret(given: string, expected: string): boolean {
  const a = createHash('sha256').update(given).digest();
  const b = createHash('sha256').update(expected).digest();
  return timingSafeEqual(a, b);
}
