import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { DiscoveryService, MetadataScanner, Reflector } from '@nestjs/core';
import { SCHEDULE_CRON_OPTIONS } from '@nestjs/schedule/dist/schedule.constants';

export interface CronJob {
  /** `ClassName.methodName` — stable, and the name pg_cron calls it by. */
  id: string;
  cronTime: string;
  run: () => Promise<unknown>;
}

/**
 * Every `@Cron` method in the backend, runnable on demand.
 *
 * On a server `@nestjs/schedule` starts a timer per job when the application
 * boots. An edge isolate is short-lived and there may be dozens of them, so
 * timers would fire at random, repeatedly, or not at all. `main.ts` therefore
 * stops the scheduler from mounting anything, and this registry finds the
 * same methods by the same metadata so pg_cron can call each one exactly
 * once, on schedule, through `POST /internal/cron/:id`.
 */
@Injectable()
export class CronRegistry implements OnApplicationBootstrap {
  private readonly logger = new Logger(CronRegistry.name);
  private readonly jobs = new Map<string, CronJob>();

  constructor(
    private readonly discovery: DiscoveryService,
    private readonly scanner: MetadataScanner,
    private readonly reflector: Reflector,
  ) {}

  onApplicationBootstrap() {
    for (const wrapper of this.discovery.getProviders()) {
      const instance = wrapper.instance as Record<string, unknown> | undefined;
      if (!instance || !wrapper.isDependencyTreeStatic()) continue;
      const prototype = Object.getPrototypeOf(instance);
      if (!prototype) continue;

      for (const method of this.scanner.getAllMethodNames(prototype)) {
        const handler = prototype[method];
        const options = this.reflector.get<{ cronTime: string | Date }>(SCHEDULE_CRON_OPTIONS, handler);
        if (!options) continue;

        const id = `${instance.constructor.name}.${method}`;
        this.jobs.set(id, {
          id,
          cronTime: String(options.cronTime),
          run: () => Promise.resolve((instance[method] as () => unknown).call(instance)),
        });
      }
    }
    this.logger.log(`${this.jobs.size} scheduled jobs registered for pg_cron`);
  }

  get(id: string): CronJob | undefined {
    return this.jobs.get(id);
  }

  list(): Array<Pick<CronJob, 'id' | 'cronTime'>> {
    return [...this.jobs.values()]
      .map(({ id, cronTime }) => ({ id, cronTime }))
      .sort((a, b) => a.id.localeCompare(b.id));
  }
}
