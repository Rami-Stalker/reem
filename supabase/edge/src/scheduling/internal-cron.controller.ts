import {
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Logger,
  NotFoundException,
  Param,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import { ModuleRef } from '@nestjs/core';
import { SkipThrottle } from '@nestjs/throttler';
import { createHash, timingSafeEqual } from 'node:crypto';
import { Public } from '../../../../backend/src/common/decorators/public.decorator';
import { DeliveryProviderBootstrap } from '../../../../backend/src/modules/delivery/dispatch/delivery-provider.bootstrap';
import { MarketScheduler } from '../../../../backend/src/modules/market/market.scheduler';
import { runBootSeeds } from '../runtime/boot-seeds';
import { supabaseRuntime } from '../runtime/env';
import { CronRegistry } from './cron-registry.service';

/**
 * The trigger pg_cron pulls.
 *
 * Public to the user-session guards because no user calls it; authenticated
 * instead by `x-reem-cron-secret`, a value held in two places only — this
 * function's secrets and the database's Vault, where the pg_cron job reads it.
 * Without the secret configured every call is refused.
 */
@Public()
@SkipThrottle()
@Controller('internal/cron')
export class InternalCronController {
  private readonly logger = new Logger(InternalCronController.name);

  constructor(
    private readonly registry: CronRegistry,
    private readonly moduleRef: ModuleRef,
  ) {}

  @Get()
  list(@Headers('x-reem-cron-secret') secret?: string) {
    this.authorise(secret);
    return { jobs: this.registry.list() };
  }

  /** The start-up seeds a server runs once (see runtime/boot-seeds.ts); called after each deploy. */
  @Post('boot-seeds')
  @HttpCode(HttpStatus.OK)
  async bootSeeds(@Headers('x-reem-cron-secret') secret?: string) {
    this.authorise(secret);
    await runBootSeeds({
      market: this.moduleRef.get(MarketScheduler, { strict: false }),
      delivery: this.moduleRef.get(DeliveryProviderBootstrap, { strict: false }),
    });
    return { seeded: true };
  }

  @Post(':id')
  @HttpCode(HttpStatus.OK)
  async run(@Param('id') id: string, @Headers('x-reem-cron-secret') secret?: string) {
    this.authorise(secret);
    const job = this.registry.get(id);
    if (!job) throw new NotFoundException(`No scheduled job named ${id}`);

    const started = Date.now();
    try {
      await job.run();
    } catch (error) {
      this.logger.error(`Scheduled job ${id} failed: ${String(error)}`);
      throw error;
    }
    const result = {
      job: id,
      duration_ms: Date.now() - started,
    };
    this.logger.log(`Scheduled job ${id} finished in ${result.duration_ms}ms`);
    return result;
  }

  private authorise(secret: string | undefined) {
    const expected = supabaseRuntime().cronSecret;
    if (!expected || !secret) throw new UnauthorizedException();
    const a = createHash('sha256').update(secret).digest();
    const b = createHash('sha256').update(expected).digest();
    if (!timingSafeEqual(a, b)) throw new UnauthorizedException();
  }
}
