import assert from 'node:assert/strict';
import test from 'node:test';
import { randomUUID } from 'node:crypto';
import { IdempotencyState, PrismaClient } from '@prisma/client';
import { of, lastValueFrom, throwError } from 'rxjs';

import { PrismaService } from '../../prisma/prisma.service';
import { IdempotencyInterceptor } from './idempotency.interceptor';

/**
 * What a second tap gets.
 *
 * Checkout creates an order, claims stock from every seller in the basket,
 * redeems a coupon and starts a payment — all in one request that can be in
 * flight for seconds on a mobile connection. A woman who cannot tell whether
 * it registered taps again, and before this she got two orders and a courier
 * at her door with two bills.
 *
 * These run against a real database because the guarantee *is* the unique
 * index: the claim is an insert, not a read-then-write, and only a real
 * Postgres can be asked whether two simultaneous inserts produce one winner.
 */
const prisma = new PrismaClient();

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

function dbTest(name: string, body: () => Promise<void>): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    await body();
  });
}

const interceptor = () =>
  new IdempotencyInterceptor(prisma as unknown as PrismaService);

/** The shape the interceptor reads off an Express request. */
function request(options: {
  key?: string;
  method?: string;
  path?: string;
  body?: unknown;
  userId?: string;
}) {
  return {
    method: options.method ?? 'POST',
    path: options.path ?? '/orders/checkout',
    route: { path: options.path ?? '/orders/checkout' },
    headers: options.key ? { 'idempotency-key': options.key } : {},
    body: options.body ?? { total: 100 },
    ip: '10.0.0.1',
    user: options.userId ? { id: options.userId } : undefined,
  };
}

function context(req: ReturnType<typeof request>, statusCode = 201) {
  return {
    getType: () => 'http',
    switchToHttp: () => ({
      getRequest: () => req,
      getResponse: () => ({ statusCode }),
    }),
  } as never;
}

/** A handler that records how many times it actually ran. */
function handler(result: unknown, calls: { count: number }) {
  return {
    handle: () => {
      calls.count += 1;
      return of(result);
    },
  };
}

const run = (req: ReturnType<typeof request>, next: { handle: () => unknown }) =>
  lastValueFrom(
    interceptor().intercept(context(req), next as never) as never,
  ) as Promise<unknown>;

async function cleanup(scope: string) {
  await prisma.idempotencyRecord.deleteMany({ where: { scope } });
}

// ── The clock the claim is stamped with ─────────────────────────────────

dbTest('a claim is stamped in UTC, whatever the database session thinks', async () => {
  // This is not pedantry about zones. The claim's `created_at` was written with
  // SQL `now()`, a `timestamptz`, into a column Prisma declares as `timestamp
  // without time zone` — so PostgreSQL converted it to the *session's* wall
  // clock on the way in, and Prisma read it back as though it were UTC. On a
  // server set to `Europe/Istanbul`, which is where this platform runs, every
  // claim was stamped three hours in the future.
  //
  // What that broke is the sweeper. It reclaims `IN_FLIGHT` claims left behind
  // by a process that died mid-request, and a claim three hours ahead of the
  // clock is not stale for three hours longer than intended — so retrying that
  // request answered `409` all morning, which is the exact state the sweeper
  // exists to prevent.
  //
  // The assertion is deliberately loose in one direction and tight in the
  // other: a few seconds of drift is a slow test, three hours is the bug.
  const userId = randomUUID();
  const key = `k-${randomUUID()}`;
  const calls = { count: 0 };

  const before = Date.now();
  await run(request({ key, userId }), handler({ id: 'order-1' }, calls));

  const record = await prisma.idempotencyRecord.findFirstOrThrow({
    where: { scope: `user:${userId}`, key },
    select: { createdAt: true, expiresAt: true },
  });

  const skewMs = record.createdAt.getTime() - before;
  assert.ok(
    skewMs >= -5_000 && skewMs <= 60_000,
    `created_at is ${Math.round(skewMs / 1000)}s from the app's clock — a ` +
      'timezone conversion, not latency',
  );
  // And it agrees with the neighbouring column, which was always a bound Date.
  assert.ok(
    record.expiresAt > record.createdAt,
    'a record cannot expire before it was created',
  );

  await cleanup(`user:${userId}`);
});

// ── The double tap ──────────────────────────────────────────────────────

dbTest('a repeated request is answered, not re-run', async () => {
  const userId = randomUUID();
  const key = `k-${randomUUID()}`;
  const calls = { count: 0 };
  const order = { id: 'order-1', number: 'ORD-1' };

  const first = await run(
    request({ key, userId }),
    handler(order, calls),
  );
  const second = await run(
    request({ key, userId }),
    handler(order, calls),
  );

  assert.deepEqual(first, order);
  assert.deepEqual(second, order, 'she sees her order, not a second one');
  assert.equal(calls.count, 1, 'the handler ran once — one order, one claim');

  await cleanup(`user:${userId}`);
});

dbTest('two taps at once produce one order', async () => {
  const userId = randomUUID();
  const key = `k-${randomUUID()}`;
  const calls = { count: 0 };

  // Genuinely parallel, which is the case the unique index exists for: both
  // read "no record" if the claim were a read-then-write, and both proceed.
  const outcomes = await Promise.allSettled(
    Array.from({ length: 6 }, () =>
      run(request({ key, userId }), handler({ id: 'order-1' }, calls)),
    ),
  );

  assert.equal(calls.count, 1, 'exactly one attempt reached the handler');
  const fulfilled = outcomes.filter((o) => o.status === 'fulfilled');
  assert.ok(fulfilled.length >= 1);
  // The rest are either answered from the record or told it is still running;
  // neither creates a second order, which is the whole point.
  for (const outcome of outcomes) {
    if (outcome.status === 'rejected') {
      const message = String(
        (outcome.reason as { response?: { code?: string } })?.response?.code ??
          outcome.reason,
      );
      assert.match(message, /IDEMPOTENCY_IN_FLIGHT/);
    }
  }

  await cleanup(`user:${userId}`);
});

// ── Refusals that protect her ───────────────────────────────────────────

dbTest('the same key with a different basket is refused', async () => {
  const userId = randomUUID();
  const key = `k-${randomUUID()}`;
  const calls = { count: 0 };

  await run(
    request({ key, userId, body: { total: 100 } }),
    handler({ id: 'a' }, calls),
  );

  await assert.rejects(
    run(
      request({ key, userId, body: { total: 250 } }),
      handler({ id: 'b' }, calls),
    ),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'IDEMPOTENCY_KEY_REUSED',
    'answering this with the first order would silently drop a real second one',
  );
  assert.equal(calls.count, 1);

  await cleanup(`user:${userId}`);
});

dbTest('key order in the body does not change its identity', async () => {
  const userId = randomUUID();
  const key = `k-${randomUUID()}`;
  const calls = { count: 0 };

  await run(
    request({ key, userId, body: { a: 1, b: 2 } }),
    handler({ id: 'a' }, calls),
  );
  // The same request, serialised the other way round. A client that reorders
  // its own JSON must not read as a different basket.
  const again = await run(
    request({ key, userId, body: { b: 2, a: 1 } }),
    handler({ id: 'a' }, calls),
  );

  assert.deepEqual(again, { id: 'a' });
  assert.equal(calls.count, 1);

  await cleanup(`user:${userId}`);
});

dbTest('the same key on a different endpoint is refused', async () => {
  const userId = randomUUID();
  const key = `k-${randomUUID()}`;
  const calls = { count: 0 };

  await run(request({ key, userId }), handler({ id: 'a' }, calls));

  await assert.rejects(
    run(
      request({ key, userId, path: '/orders/:id/cancel' }),
      handler({ id: 'b' }, calls),
    ),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'IDEMPOTENCY_KEY_REUSED',
  );

  await cleanup(`user:${userId}`);
});

// ── Scope ───────────────────────────────────────────────────────────────

dbTest('one customer cannot read another through her key', async () => {
  const key = `k-${randomUUID()}`;
  const mine = randomUUID();
  const stranger = randomUUID();
  const calls = { count: 0 };

  const first = await run(
    request({ key, userId: mine }),
    handler({ id: 'mine' }, calls),
  );
  // The same key, a different account. Scoped by principal, so it is a
  // different claim entirely rather than a read of somebody else's order.
  const second = await run(
    request({ key, userId: stranger }),
    handler({ id: 'hers' }, calls),
  );

  assert.deepEqual(first, { id: 'mine' });
  assert.deepEqual(second, { id: 'hers' });
  assert.equal(calls.count, 2, 'two people, two orders');

  await cleanup(`user:${mine}`);
  await cleanup(`user:${stranger}`);
});

// ── Failure releases the key ────────────────────────────────────────────

dbTest('a failed request can be retried', async () => {
  const userId = randomUUID();
  const key = `k-${randomUUID()}`;
  const calls = { count: 0 };

  await assert.rejects(
    run(request({ key, userId }), {
      handle: () => {
        calls.count += 1;
        return throwError(() => new Error('gateway down'));
      },
    }),
    /gateway down/,
  );

  // The key exists to stop a *successful* action happening twice, never to
  // make a failure permanent. She taps again and it runs.
  const retried = await run(
    request({ key, userId }),
    handler({ id: 'order-1' }, calls),
  );
  assert.deepEqual(retried, { id: 'order-1' });
  assert.equal(calls.count, 2);

  await cleanup(`user:${userId}`);
});

// ── Passing through ─────────────────────────────────────────────────────

dbTest('a request with no key is untouched', async () => {
  const calls = { count: 0 };
  const first = await run(request({}), handler({ id: 'a' }, calls));
  const second = await run(request({}), handler({ id: 'a' }, calls));

  assert.deepEqual(first, { id: 'a' });
  assert.deepEqual(second, { id: 'a' });
  assert.equal(
    calls.count,
    2,
    'opt-in: nothing that exists today changes behaviour',
  );
});

dbTest('a GET is never claimed', async () => {
  const userId = randomUUID();
  const key = `k-${randomUUID()}`;
  const calls = { count: 0 };

  await run(
    request({ key, userId, method: 'GET' }),
    handler({ id: 'a' }, calls),
  );
  await run(
    request({ key, userId, method: 'GET' }),
    handler({ id: 'a' }, calls),
  );

  assert.equal(calls.count, 2, 'a safe method needs no protection');
  const record = await prisma.idempotencyRecord.findFirst({
    where: { scope: `user:${userId}`, key },
  });
  assert.equal(record, null, 'and leaves nothing behind');
});

// ── The record itself ───────────────────────────────────────────────────

dbTest('a completed record carries the status it answered', async () => {
  const userId = randomUUID();
  const key = `k-${randomUUID()}`;
  const calls = { count: 0 };

  await run(request({ key, userId }), handler({ id: 'order-1' }, calls));

  const record = await prisma.idempotencyRecord.findUniqueOrThrow({
    where: { scope_key: { scope: `user:${userId}`, key } },
  });
  assert.equal(record.state, IdempotencyState.COMPLETED);
  assert.equal(record.statusCode, 201);
  assert.deepEqual(record.response, { id: 'order-1' });
  assert.ok(record.expiresAt > new Date(), 'and a window it answers within');

  await cleanup(`user:${userId}`);
});

// ── Demanding a key ─────────────────────────────────────────────────────
//
// Off by default, because turning it on refuses every install still running
// the previous version — a woman on an old build could not buy anything. Once
// the update has landed, this closes the gap for good rather than depending on
// the client to remember.

const enforcing = (routes: string[]) =>
  new IdempotencyInterceptor(prisma as unknown as PrismaService, {
    get: () => routes,
  } as never);

const runWith = (
  interceptorInstance: IdempotencyInterceptor,
  req: ReturnType<typeof request>,
  next: { handle: () => unknown },
) =>
  lastValueFrom(
    interceptorInstance.intercept(context(req), next as never) as never,
  ) as Promise<unknown>;

dbTest('a guarded route refuses a request with no key', async () => {
  const calls = { count: 0 };
  const guard = enforcing(['POST /orders/checkout']);

  // A thunk, not the promise: the refusal is thrown synchronously from
  // `intercept` — before any observable exists — so evaluating the call
  // directly would throw past the assertion rather than into it.
  await assert.rejects(
    async () =>
      runWith(guard, request({ userId: randomUUID() }), handler({}, calls)),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'IDEMPOTENCY_KEY_REQUIRED',
  );
  assert.equal(calls.count, 0, 'and no order is placed on the way to refusing');
});

dbTest('an unguarded route still passes without one', async () => {
  const calls = { count: 0 };
  const guard = enforcing(['POST /orders/checkout']);

  await runWith(
    guard,
    request({ userId: randomUUID(), path: '/cart/items' }),
    handler({ ok: true }, calls),
  );
  assert.equal(calls.count, 1);
});

dbTest('a guarded route with a key behaves exactly as before', async () => {
  const userId = randomUUID();
  const key = `k-${randomUUID()}`;
  const calls = { count: 0 };
  const guard = enforcing(['POST /orders/checkout']);

  await runWith(guard, request({ key, userId }), handler({ id: 'o' }, calls));
  const again = await runWith(
    guard,
    request({ key, userId }),
    handler({ id: 'o' }, calls),
  );

  assert.deepEqual(again, { id: 'o' });
  assert.equal(calls.count, 1);

  await cleanup(`user:${userId}`);
});
