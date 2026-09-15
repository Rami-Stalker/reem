import 'reflect-metadata';
import assert from 'node:assert/strict';
import test from 'node:test';
import { ConfigService } from '@nestjs/config';
import { DiscoveryService, MetadataScanner, Reflector } from '@nestjs/core';

import { JobLeaseRepository, JobOutcome, JobTrigger } from './job-lease.repository';
import { catchesUp, isDueForCatchUp, isOverdue, JobRunner } from './job-runner.service';
import { ScheduledJob } from './scheduled-job.decorator';

/**
 * The runner's promise is "exactly one instance runs each tick, and every run
 * is recorded". These cases hold it to that without a database: a lease store
 * shared between two runners stands in for `scheduled_job_states`, with the
 * same take-if-free-or-expired rule the SQL applies atomically.
 */

class SharedLeases {
  holders = new Map<string, { holder: string; until: number }>();
  finished: Array<{ name: string; holder: string; outcome: JobOutcome; error?: string }> = [];
  failAcquire = false;

  repositoryFor(): JobLeaseRepository {
    return {
      acquire: async (name: string, holder: string, seconds: number, _t: JobTrigger) => {
        if (this.failAcquire) throw new Error('database unreachable');
        const current = this.holders.get(name);
        if (current && current.until > Date.now()) return false;
        this.holders.set(name, { holder, until: Date.now() + seconds * 1000 });
        return true;
      },
      renew: async (name: string, holder: string) => this.holders.get(name)?.holder === holder,
      finish: async (name: string, holder: string, outcome: JobOutcome, _ms: number, error?: string) => {
        if (this.holders.get(name)?.holder !== holder) return false;
        this.holders.delete(name);
        this.finished.push({ name, holder, outcome, error });
        return true;
      },
      releaseAll: async (holder: string) => {
        let released = 0;
        for (const [name, lease] of this.holders) {
          if (lease.holder === holder) {
            this.holders.delete(name);
            released += 1;
          }
        }
        return released;
      },
      all: async () => [],
      one: async () => null,
    } as unknown as JobLeaseRepository;
  }
}

class Sweeps {
  calls = 0;
  release?: () => void;

  @ScheduledJob({ cron: '0 */10 * * * *', staleAfterMinutes: 30, critical: true })
  async expireOrders(): Promise<void> {
    this.calls += 1;
    await new Promise<void>((resolve) => {
      this.release = resolve;
      setTimeout(resolve, 20);
    });
  }

  @ScheduledJob({ cron: '0 * * * * *' })
  async broken(): Promise<void> {
    throw new Error('boom');
  }

  outboxCalls = 0;
  @ScheduledJob({ cron: '*/10 * * * * *', lease: false })
  async drainOutbox(): Promise<void> {
    this.outboxCalls += 1;
  }
}

function runnerFor(instance: object, leases: JobLeaseRepository): JobRunner {
  const discovery = {
    getProviders: () => [{ instance, isDependencyTreeStatic: () => true }],
  } as unknown as DiscoveryService;
  const runner = new JobRunner(
    discovery,
    new MetadataScanner(),
    new Reflector(),
    leases,
    // Timers off: the cases drive `run` directly.
    new ConfigService({ scheduler: { enabled: false } }),
  );
  runner.onApplicationBootstrap();
  return runner;
}

test('jobs are discovered under ClassName.method', () => {
  const runner = runnerFor(new Sweeps(), new SharedLeases().repositoryFor());
  assert.deepEqual(runner.names(), ['Sweeps.broken', 'Sweeps.drainOutbox', 'Sweeps.expireOrders']);
});

test('two instances firing the same tick run the job once', async () => {
  const store = new SharedLeases();
  const sweeps = new Sweeps();
  const a = runnerFor(sweeps, store.repositoryFor());
  const b = runnerFor(sweeps, store.repositoryFor());

  const [first, second] = await Promise.all([
    a.run('Sweeps.expireOrders', 'schedule'),
    b.run('Sweeps.expireOrders', 'schedule'),
  ]);

  assert.equal(sweeps.calls, 1);
  const statuses = [first.status, second.status].sort();
  assert.deepEqual(statuses, ['skipped', 'succeeded']);
  assert.equal(store.finished.length, 1);
  assert.equal(store.finished[0].outcome, 'SUCCEEDED');
  // Released on finish, so the next tick can take it.
  assert.equal(store.holders.size, 0);
});

test('a tick that arrives while the same instance is still running is skipped', async () => {
  const sweeps = new Sweeps();
  const runner = runnerFor(sweeps, new SharedLeases().repositoryFor());
  const long = runner.run('Sweeps.expireOrders', 'schedule');
  const overlap = await runner.run('Sweeps.expireOrders', 'schedule');
  assert.deepEqual(overlap, { status: 'skipped', reason: 'running' });
  await long;
  assert.equal(sweeps.calls, 1);
});

test('a failing job is recorded as FAILED and never throws into the timer', async () => {
  const store = new SharedLeases();
  const runner = runnerFor(new Sweeps(), store.repositoryFor());
  const result = await runner.run('Sweeps.broken', 'schedule');
  assert.equal(result.status, 'failed');
  assert.equal(store.finished[0].outcome, 'FAILED');
  assert.equal(store.finished[0].error, 'boom');
});

test('without a database there is no lease, and without a lease the job does not run', async () => {
  const store = new SharedLeases();
  store.failAcquire = true;
  const sweeps = new Sweeps();
  const runner = runnerFor(sweeps, store.repositoryFor());
  const result = await runner.run('Sweeps.expireOrders', 'schedule');
  assert.deepEqual(result, { status: 'skipped', reason: 'unavailable' });
  assert.equal(sweeps.calls, 0);
});

test('a lease-free job runs without touching the lease store', async () => {
  const store = new SharedLeases();
  store.failAcquire = true; // would make any leased job skip
  const sweeps = new Sweeps();
  const runner = runnerFor(sweeps, store.repositoryFor());
  assert.equal((await runner.run('Sweeps.drainOutbox', 'schedule')).status, 'succeeded');
  assert.equal(sweeps.outboxCalls, 1);
});

test('after shutdown begins no new run starts, and held leases are given back', async () => {
  const store = new SharedLeases();
  const runner = runnerFor(new Sweeps(), store.repositoryFor());
  store.holders.set('Sweeps.expireOrders', {
    holder: (runner as unknown as { holder: string }).holder,
    until: Date.now() + 60_000,
  });
  await runner.beforeApplicationShutdown();
  assert.equal(store.holders.size, 0);
  assert.deepEqual(await runner.run('Sweeps.expireOrders', 'manual'), {
    status: 'skipped',
    reason: 'shutting-down',
  });
});

test('overdue is measured from the last success, or from start-up when never run', () => {
  const minute = 60_000;
  const now = Date.now();
  const meta = { staleAfterMinutes: 30 };
  assert.equal(isOverdue(meta, { lastSucceededAt: new Date(now - 10 * minute) }, now, now), false);
  assert.equal(isOverdue(meta, { lastSucceededAt: new Date(now - 31 * minute) }, now, now), true);
  // Never run, instance just started: not an alarm yet.
  assert.equal(isOverdue(meta, undefined, now, now - minute), false);
  // Never run, and this instance has been up past the window: it is.
  assert.equal(isOverdue(meta, undefined, now, now - 45 * minute), true);
  // No window declared: never overdue.
  assert.equal(isOverdue({}, undefined, now, 0), false);
});

test('any job with a staleness window catches up unless it opts out', () => {
  assert.equal(catchesUp({ staleAfterMinutes: 30 }), true);
  assert.equal(catchesUp({ staleAfterMinutes: 30, catchUp: false }), false);
  assert.equal(catchesUp({}), false);
  assert.equal(catchesUp({ catchUp: true }), true);
});

test('after a sleep, overdue jobs catch up shortest window first', async () => {
  class Clocks {
    order: string[] = [];
    @ScheduledJob({ cron: '0 30 2 * * *', staleAfterMinutes: 1560 })
    async nightly() {
      this.order.push('nightly');
    }
    @ScheduledJob({ cron: '0 */10 * * * *', staleAfterMinutes: 30 })
    async holds() {
      this.order.push('holds');
    }
    @ScheduledJob({ cron: '0 * * * * *', staleAfterMinutes: 10 })
    async codes() {
      this.order.push('codes');
    }
    @ScheduledJob({ cron: '0 0 * * * *' })
    async unwatched() {
      this.order.push('unwatched');
    }
  }
  const clocks = new Clocks();
  const store = new SharedLeases();
  const leases = store.repositoryFor();
  // Every job last succeeded two days ago: the instance slept through them.
  const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60_000);
  (leases as unknown as { all: () => Promise<unknown[]> }).all = async () =>
    ['Clocks.nightly', 'Clocks.holds', 'Clocks.codes', 'Clocks.unwatched'].map((name) => ({
      name,
      lastSucceededAt: twoDaysAgo,
    }));
  const runner = runnerFor(clocks, leases);
  await (runner as unknown as { catchUp(): Promise<void> }).catchUp();
  assert.deepEqual(clocks.order, ['codes', 'holds', 'nightly']);
});

test('a job that has never succeeded is due for catch-up however recently the process started', () => {
  // A host that restarts after every sleep always has a short uptime; measured
  // from boot, a never-run nightly job would never be caught up.
  const now = Date.now();
  const nightly = { staleAfterMinutes: 1560 };
  assert.equal(isDueForCatchUp(nightly, undefined, now), true);
  assert.equal(isDueForCatchUp(nightly, { lastSucceededAt: null }, now), true);
  assert.equal(isDueForCatchUp(nightly, { lastSucceededAt: new Date(now - 60_000) }, now), false);
  assert.equal(isDueForCatchUp(nightly, { lastSucceededAt: new Date(now - 27 * 3_600_000) }, now), true);
  // …while the health report still does not alarm on a fresh deploy.
  assert.equal(isOverdue(nightly, undefined, now, now - 60_000), false);
});

test('a fresh instance catches up jobs that have never run', async () => {
  class Fresh {
    ran: string[] = [];
    @ScheduledJob({ cron: '0 30 2 * * *', staleAfterMinutes: 1560 })
    async escrow() {
      this.ran.push('escrow');
    }
  }
  const fresh = new Fresh();
  const runner = runnerFor(fresh, new SharedLeases().repositoryFor()); // no run records at all
  await (runner as unknown as { catchUp(): Promise<void> }).catchUp();
  assert.deepEqual(fresh.ran, ['escrow']);
});
