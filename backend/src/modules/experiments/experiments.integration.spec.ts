import assert from 'node:assert/strict';
import test from 'node:test';
import { ExperimentStatus, PrismaClient } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { ExperimentsService } from './experiments.service';
import { CONTROL } from './kernel/assignment';

/**
 * The experiment framework against real rows.
 *
 * The kernel tests prove the split and the statistics. These prove the things
 * that only go wrong once there is a database: that an exposure recorded twice
 * is one exposure, that a stopped experiment stops, and that a variant nobody
 * reached reports nothing rather than a rate of zero.
 */
const prisma = new PrismaClient();

class Rollback extends Error {}
type Tx = Parameters<Parameters<typeof prisma.$transaction>[0]>[0];

let reachable = false;

test.before(async () => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    reachable = true;
  } catch {
    reachable = false;
  }
});

test.after(async () => {
  await prisma.$disconnect();
});

function dbTest(name: string, body: (world: World) => Promise<void>): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    let failure: unknown;
    try {
      await prisma.$transaction(
        async (tx) => {
          try {
            await body(build(tx));
          } catch (error) {
            failure = error;
          }
          throw new Rollback();
        },
        { timeout: 60_000 },
      );
    } catch (error) {
      if (!(error instanceof Rollback)) throw error;
    }
    if (failure) throw failure;
  });
}

function asPrisma(tx: Tx): PrismaService {
  return new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (fn: (inner: Tx) => unknown) => fn(tx);
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
}

interface World {
  tx: Tx;
  experiments: ExperimentsService;
}

function build(tx: Tx): World {
  return { tx, experiments: new ExperimentsService(asPrisma(tx)) };
}

let seq = 0;
const uniq = () => `${Date.now()}${(seq += 1)}`;

const SPLIT = [
  { key: CONTROL, weight: 50 },
  { key: 'treatment', weight: 50 },
];

async function startExperiment(world: World, over: { key?: string } = {}) {
  const key = over.key ?? `exp_${uniq()}`;
  const created = await world.experiments.create({
    key,
    name: 'اختبار',
    metric: 'checkout',
    variants: SPLIT,
    startsAt: new Date(Date.now() - 60_000),
    actorId: (
      await world.tx.user.create({
        data: {
          name: 'مسؤولة',
          username: `ex_${uniq()}`,
          phone: `+96391${uniq().slice(-7)}`,
          passwordHash: 'x',
        },
      })
    ).id,
  });
  await world.experiments.setStatus(created.id, ExperimentStatus.RUNNING);
  return { id: created.id, key };
}

dbTest('a draft experiment shows everybody the control', async (world) => {
  const key = `exp_${uniq()}`;
  const admin = await world.tx.user.create({
    data: {
      name: 'مسؤولة',
      username: `ex_${uniq()}`,
      phone: `+96391${uniq().slice(-7)}`,
      passwordHash: 'x',
    },
  });
  await world.experiments.create({
    key,
    name: 'اختبار',
    metric: 'checkout',
    variants: SPLIT,
    startsAt: new Date(Date.now() - 60_000),
    actorId: admin.id,
  });

  for (let i = 0; i < 20; i += 1) {
    assert.equal(await world.experiments.variantFor(key, `u${i}`), CONTROL);
  }
});

dbTest('a running experiment splits, and remembers', async (world) => {
  const { key } = await startExperiment(world);

  const first = await world.experiments.variantFor(key, 'user-abc');
  assert.equal(await world.experiments.variantFor(key, 'user-abc'), first);

  const arms = new Set<string>();
  for (let i = 0; i < 60; i += 1) {
    arms.add(await world.experiments.variantFor(key, `u${i}`));
  }
  assert.equal(arms.size, 2, 'both arms are being served');
});

dbTest('an exposure recorded twice is one exposure', async (world) => {
  const { id, key } = await startExperiment(world);

  await world.experiments.recordExposure(key, 'user-1');
  await world.experiments.recordExposure(key, 'user-1');
  await world.experiments.recordExposure(key, 'user-1');

  const count = await world.tx.experimentEvent.count({
    where: { experimentId: id, subjectKey: 'user-1', kind: 'EXPOSURE' },
  });
  assert.equal(count, 1, 'a screen that renders three times is one exposure');
});

dbTest('a conversion recorded twice is one conversion', async (world) => {
  const { id, key } = await startExperiment(world);

  await world.experiments.recordExposure(key, 'user-1');
  await world.experiments.recordConversion(key, 'user-1');
  await world.experiments.recordConversion(key, 'user-1');

  const count = await world.tx.experimentEvent.count({
    where: { experimentId: id, subjectKey: 'user-1', kind: 'CONVERSION' },
  });
  assert.equal(count, 1, 'a reloaded confirmation page converts once');
});

dbTest('rates are over exposures, not over assignments', async (world) => {
  const { id, key } = await startExperiment(world);

  // Twenty subjects assigned by the hash, but only six ever reached the
  // screen. If the report counted assignments, the rate would be a third of
  // what it is.
  const exposed: string[] = [];
  for (let i = 0; exposed.length < 6 && i < 200; i += 1) {
    const subject = `u${i}`;
    if ((await world.experiments.variantFor(key, subject)) === CONTROL) {
      await world.experiments.recordExposure(key, subject);
      exposed.push(subject);
    }
  }
  for (const subject of exposed.slice(0, 3)) {
    await world.experiments.recordConversion(key, subject);
  }

  const results = await world.experiments.results(id);
  const control = results.arms.find((a) => a.variant === CONTROL)!;

  assert.equal(control.exposed, 6);
  assert.equal(control.converted, 3);
  assert.equal(control.rate, 0.5);
});

dbTest('an arm nobody reached reports nothing, not zero', async (world) => {
  const { id, key } = await startExperiment(world);
  await world.experiments.recordExposure(key, 'user-1');

  const results = await world.experiments.results(id);
  const empty = results.arms.find((arm) => arm.exposed === 0);

  assert.ok(empty, 'one arm has had nobody');
  assert.equal(
    empty.rate,
    null,
    'averaging an unreached arm in as zero makes the other look worse than it is',
  );
  assert.equal(empty.readable, false);
});

dbTest('a thin result refuses to declare a winner', async (world) => {
  const { id, key } = await startExperiment(world);
  for (let i = 0; i < 20; i += 1) {
    await world.experiments.recordExposure(key, `u${i}`);
    if (i % 2 === 0) await world.experiments.recordConversion(key, `u${i}`);
  }

  const results = await world.experiments.results(id);
  for (const arm of results.arms) {
    assert.equal(arm.p_value, null, 'twenty subjects is not a result');
    assert.equal(arm.readable, false);
  }
  assert.ok(
    results.reading_guidance.length > 0,
    'and the screen says so in words, not just by omitting a number',
  );
});

dbTest('stopping an experiment stops it', async (world) => {
  const { id, key } = await startExperiment(world);

  const before = new Set<string>();
  for (let i = 0; i < 40; i += 1) {
    before.add(await world.experiments.variantFor(key, `u${i}`));
  }
  assert.equal(before.size, 2);

  await world.experiments.setStatus(id, ExperimentStatus.STOPPED);

  for (let i = 0; i < 40; i += 1) {
    assert.equal(
      await world.experiments.variantFor(key, `u${i}`),
      CONTROL,
      'a half-rolled-out change must not keep running because nobody noticed',
    );
  }
});

dbTest('a stopped experiment cannot be restarted', async (world) => {
  const { id } = await startExperiment(world);
  await world.experiments.setStatus(id, ExperimentStatus.STOPPED);

  await assert.rejects(
    world.experiments.setStatus(id, ExperimentStatus.RUNNING),
    /cannot be restarted/,
    'two runs under different conditions reported as one is not a result',
  );
});

dbTest('events for a stopped experiment are not recorded', async (world) => {
  const { id, key } = await startExperiment(world);
  await world.experiments.setStatus(id, ExperimentStatus.STOPPED);

  const result = await world.experiments.recordExposure(key, 'user-9');
  assert.equal(result.recorded, false);

  const count = await world.tx.experimentEvent.count({
    where: { experimentId: id },
  });
  assert.equal(count, 0);
});

dbTest('a misconfigured experiment serves the control rather than breaking', async (world) => {
  const admin = await world.tx.user.create({
    data: {
      name: 'مسؤولة',
      username: `ex_${uniq()}`,
      phone: `+96391${uniq().slice(-7)}`,
      passwordHash: 'x',
    },
  });
  const key = `exp_${uniq()}`;

  // Written straight to the table, bypassing the validation `create` does —
  // this is the state a bad migration or a hand-edited row leaves behind.
  await world.tx.experiment.create({
    data: {
      key,
      name: 'مكسور',
      metric: 'checkout',
      variants: [{ key: 'only', weight: 100 }],
      status: ExperimentStatus.RUNNING,
      startsAt: new Date(Date.now() - 60_000),
      createdById: admin.id,
    },
  });

  const experiments = new ExperimentsService(asPrisma(world.tx));
  assert.equal(
    await experiments.variantFor(key, 'user-1'),
    CONTROL,
    'a feature flag that can break the page it flags is worse than no flag',
  );
});
