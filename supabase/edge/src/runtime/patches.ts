import { EventEmitter2 } from '@nestjs/event-emitter';
import { SchedulerOrchestrator } from '@nestjs/schedule/dist/scheduler.orchestrator';
import { trackBackgroundWork } from './background';

let installed = false;

/**
 * The two runtime behaviours of a long-lived server the edge must not inherit.
 * Both are applied to library prototypes before the application is built, so
 * no backend class is touched.
 */
export function installEdgePatches(): void {
  if (installed) return;
  installed = true;

  // 1. Timers. `@nestjs/schedule` would start a cron timer per `@Cron` method
  //    in every isolate — dozens of copies firing at random. pg_cron drives
  //    the same methods through /internal/cron instead (CronRegistry).
  SchedulerOrchestrator.prototype.onApplicationBootstrap = function noTimersOnTheEdge() {
    // Intentionally empty.
  };

  // 2. Work after the response. Domain events are emitted synchronously and
  //    their listeners — notification fan-out, Realtime broadcasts, closet
  //    intake — finish after the handler has answered. `emitAsync` starts the
  //    listeners exactly as `emit` does, and hands back the promise of their
  //    completion, which the isolate is told to wait for.
  const prototype = EventEmitter2.prototype as unknown as {
    emit(event: string | symbol, ...values: unknown[]): boolean;
    emitAsync(event: string | symbol, ...values: unknown[]): Promise<unknown[]>;
    listenerCount(event?: string | symbol): number;
  };
  prototype.emit = function emitAndTrack(this: typeof prototype, event, ...values) {
    const hadListeners = this.listenerCount(event) > 0;
    if (hadListeners) trackBackgroundWork(this.emitAsync(event, ...values));
    return hadListeners;
  };
}
