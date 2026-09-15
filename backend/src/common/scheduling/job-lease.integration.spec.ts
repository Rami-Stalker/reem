import assert from 'node:assert/strict';
import test from 'node:test';
import { PrismaClient } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { JobLeaseRepository } from './job-lease.repository';

/**
 * The lease against real Postgres — the only place its guarantee exists.
 *
 * The unit spec proves the runner honours a lease; this proves the lease is a
 * lease: that ten instances racing for one job get exactly one yes from
 * `INSERT … ON CONFLICT … WHERE`, that a lease its holder stops renewing is
 * taken over, and that nobody but the holder can release it.
 *
 * Job names are unique per run and deleted afterwards; nothing else is
 * touched.
 */
const prisma = new PrismaClient();
const leases = new JobLeaseRepository(prisma as unknown as PrismaService);
const prefix = `spec.lease.${Date.now()}.`;

let reachable = false;

test.before(async () => {
  try {
    await prisma.$queryRaw`SELECT 1 FROM scheduled_job_states LIMIT 1`;
    reachable = true;
  } catch {
    reachable = false;
  }
});

test.after(async () => {
  if (reachable) {
    await prisma.scheduledJobState.deleteMany({ where: { name: { startsWith: prefix } } });
  }
  await prisma.$disconnect();
});

function dbTest(name: string, body: () => Promise<void>): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    await body();
  });
}

dbTest('ten instances racing for one job: exactly one gets the lease', async () => {
  const job = `${prefix}race`;
  const results = await Promise.all(
    Array.from({ length: 10 }, (_, i) => leases.acquire(job, `instance-${i}`, 60, 'schedule')),
  );
  assert.equal(results.filter(Boolean).length, 1);
  const state = await leases.one(job);
  assert.equal(state?.lastStatus, 'RUNNING');
  assert.ok(state?.lockedBy?.startsWith('instance-'));
});

dbTest('a held lease is refused; a finished one is free again and records the run', async () => {
  const job = `${prefix}cycle`;
  assert.equal(await leases.acquire(job, 'a', 60, 'schedule'), true);
  assert.equal(await leases.acquire(job, 'b', 60, 'schedule'), false);

  // Only the holder may release it.
  assert.equal(await leases.finish(job, 'b', 'SUCCEEDED', 5), false);
  assert.equal(await leases.finish(job, 'a', 'SUCCEEDED', 5), true);

  const done = await leases.one(job);
  assert.equal(done?.lockedBy, null);
  assert.equal(done?.lastStatus, 'SUCCEEDED');
  assert.equal(done?.runCount, 1);
  assert.ok(done?.lastSucceededAt);
  assert.equal(await leases.acquire(job, 'b', 60, 'manual'), true);
});

dbTest('a lease its holder stopped renewing is taken over', async () => {
  const job = `${prefix}expiry`;
  assert.equal(await leases.acquire(job, 'crashed', 1, 'schedule'), true);
  await new Promise((resolve) => setTimeout(resolve, 1500));
  assert.equal(await leases.acquire(job, 'successor', 60, 'schedule'), true);
  // The crashed holder's late renewal and finish must not clobber the successor.
  assert.equal(await leases.renew(job, 'crashed', 60), false);
  assert.equal(await leases.finish(job, 'crashed', 'FAILED', 1, 'late'), false);
  assert.equal((await leases.one(job))?.lockedBy, 'successor');
});

dbTest('renewal keeps a long run its lease past the original expiry', async () => {
  const job = `${prefix}renew`;
  assert.equal(await leases.acquire(job, 'long-run', 1, 'schedule'), true);
  assert.equal(await leases.renew(job, 'long-run', 60), true);
  await new Promise((resolve) => setTimeout(resolve, 1500));
  assert.equal(await leases.acquire(job, 'intruder', 60, 'schedule'), false);
});

dbTest('consecutive failures count up and reset on success', async () => {
  const job = `${prefix}failures`;
  for (let i = 0; i < 2; i += 1) {
    await leases.acquire(job, 'x', 60, 'schedule');
    await leases.finish(job, 'x', 'FAILED', 1, 'boom');
  }
  assert.equal((await leases.one(job))?.consecutiveFailures, 2);
  await leases.acquire(job, 'x', 60, 'schedule');
  await leases.finish(job, 'x', 'SUCCEEDED', 1);
  const state = await leases.one(job);
  assert.equal(state?.consecutiveFailures, 0);
  assert.equal(state?.lastError, null);
});

dbTest('shutdown releases only its own leases', async () => {
  const mine = `${prefix}mine`;
  const theirs = `${prefix}theirs`;
  await leases.acquire(mine, 'stopping', 60, 'schedule');
  await leases.acquire(theirs, 'other', 60, 'schedule');
  await leases.releaseAll('stopping');
  assert.equal((await leases.one(mine))?.lockedBy, null);
  assert.equal((await leases.one(theirs))?.lockedBy, 'other');
});
