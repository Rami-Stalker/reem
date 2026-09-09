import assert from 'node:assert/strict';
import test from 'node:test';
import { randomUUID } from 'node:crypto';
import { AuditSeverity, PrismaClient, UserRole } from '@prisma/client';
import { lastValueFrom, of, throwError } from 'rxjs';

import { PrismaService } from '../../prisma/prisma.service';
import { AdminAuditInterceptor } from './admin-audit.interceptor';

/**
 * Whether the trail can actually answer the question asked after an incident.
 *
 * Twelve services wrote audit entries by hand. The admin write surface is
 * several times that — delivery providers, experiments, flash sales, search
 * synonyms, value policies, notification campaigns, commission rules — and
 * every one was a place somebody had to remember. A trail with holes is worse
 * than no trail, because it gets read as complete.
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
  new AdminAuditInterceptor(prisma as unknown as PrismaService);

function request(options: {
  method?: string;
  route?: string;
  path?: string;
  params?: Record<string, string>;
  body?: unknown;
  role?: UserRole;
  actorId?: string;
}) {
  return {
    method: options.method ?? 'PATCH',
    path: options.path ?? options.route ?? '/admin/sellers/abc',
    route: { path: options.route ?? '/admin/sellers/:id' },
    params: options.params ?? { id: 'abc' },
    body: options.body ?? {},
    headers: { 'user-agent': 'test-agent' },
    ip: '10.0.0.7',
    user: options.role
      ? { id: options.actorId ?? randomUUID(), role: options.role }
      : undefined,
  };
}

const context = (req: ReturnType<typeof request>) =>
  ({
    getType: () => 'http',
    switchToHttp: () => ({ getRequest: () => req }),
  }) as never;

const run = (req: ReturnType<typeof request>, handler: { handle: () => unknown }) =>
  lastValueFrom(interceptor().intercept(context(req), handler as never) as never);

const ok = { handle: () => of({ done: true }) };

/** Staff need to exist for the actor foreign key. */
async function makeStaff(role: UserRole) {
  const u = `${Date.now()}${Math.floor(Math.random() * 1e6)}`;
  return prisma.user.create({
    data: {
      name: 'aud',
      username: `aud_${u}`,
      phone: `+9639${Math.floor(10_000_000 + Math.random() * 89_999_999)}`,
      passwordHash: 'x',
      role,
    },
  });
}

async function entriesFor(actorId: string) {
  return prisma.auditLog.findMany({
    where: { actorId },
    orderBy: { createdAt: 'desc' },
  });
}

/**
 * Waits for the entry to land.
 *
 * The interceptor writes the trail **without awaiting it**, on purpose: an
 * audit record that costs a support agent her action would be switched off
 * within a week. So the test waits for the write rather than the production
 * path blocking on it — the alternative would be distorting the thing under
 * test to make it easier to assert.
 */
async function awaitEntry(actorId: string, timeoutMs = 3000) {
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    const entries = await entriesFor(actorId);
    if (entries.length > 0) return entries;
    if (Date.now() > deadline) return entries;
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
}

/** The opposite: proves nothing lands, after giving it a fair chance to. */
async function expectNoEntry(actorId: string) {
  await new Promise((resolve) => setTimeout(resolve, 200));
  return entriesFor(actorId);
}

async function cleanup(actorId: string) {
  await prisma.auditLog.deleteMany({ where: { actorId } });
  await prisma.user.deleteMany({ where: { id: actorId } });
}

// ── Coverage without anyone remembering ─────────────────────────────────

dbTest('a staff write is recorded even though no service asked', async () => {
  const staff = await makeStaff(UserRole.OPERATIONS_ADMIN);

  await run(
    request({
      role: UserRole.OPERATIONS_ADMIN,
      actorId: staff.id,
      route: '/admin/delivery/providers/:id',
      params: { id: 'prov-1' },
      body: { display_name: 'شركة', is_enabled: true },
    }),
    ok,
  );

  const [entry] = await awaitEntry(staff.id);
  assert.ok(entry, 'the route wrote no audit line of its own, and is covered');
  assert.equal(entry.action, 'PATCH /admin/delivery/providers/:id');
  assert.equal(entry.outcome, 'SUCCESS');
  assert.equal(entry.category, 'admin');

  await cleanup(staff.id);
});

dbTest('the entry names what was acted on', async () => {
  const staff = await makeStaff(UserRole.ADMIN);

  await run(
    request({
      role: UserRole.ADMIN,
      actorId: staff.id,
      route: '/admin/sellers/:id',
      params: { id: 'seller-42' },
    }),
    ok,
  );

  const [entry] = await awaitEntry(staff.id);
  assert.equal(entry.targetType, 'seller');
  assert.equal(
    entry.targetId,
    'seller-42',
    '"show me everything that happened to this seller" is now a query',
  );

  await cleanup(staff.id);
});

dbTest('a nested route reports the thing that actually changed', async () => {
  const staff = await makeStaff(UserRole.SUPER_ADMIN);

  await run(
    request({
      method: 'DELETE',
      role: UserRole.SUPER_ADMIN,
      actorId: staff.id,
      route: '/admin/search/synonyms/:id/terms/:termId',
      params: { id: 'group-1', termId: 'term-9' },
    }),
    ok,
  );

  const [entry] = await awaitEntry(staff.id);
  assert.equal(entry.targetType, 'term');
  assert.equal(entry.targetId, 'term-9');

  await cleanup(staff.id);
});

// ── What it refuses to store ────────────────────────────────────────────

dbTest('field names are kept, values are not', async () => {
  const staff = await makeStaff(UserRole.SUPPORT_ADMIN);

  await run(
    request({
      role: UserRole.SUPPORT_ADMIN,
      actorId: staff.id,
      body: { note: 'her home address, in full', status: 'RESOLVED' },
    }),
    ok,
  );

  const [entry] = await awaitEntry(staff.id);
  const metadata = entry.metadata as { fields?: string[] };
  assert.deepEqual(metadata.fields, ['note', 'status']);
  assert.ok(
    !JSON.stringify(entry.metadata).includes('her home address'),
    'the trail must not become a second, unguarded copy of customer data',
  );

  await cleanup(staff.id);
});

dbTest('anything that looks like a credential is dropped by name too', async () => {
  const staff = await makeStaff(UserRole.SUPER_ADMIN);

  await run(
    request({
      role: UserRole.SUPER_ADMIN,
      actorId: staff.id,
      body: {
        new_password: 'x',
        webhookSecret: 'y',
        apiKey: 'z',
        otp_code: '1',
        label: 'safe',
      },
    }),
    ok,
  );

  const [entry] = await awaitEntry(staff.id);
  const metadata = entry.metadata as { fields?: string[] };
  assert.deepEqual(
    metadata.fields,
    ['label'],
    'a field called `new_password` in a log is itself a hint worth not giving',
  );

  await cleanup(staff.id);
});

// ── Refusals are the interesting entries ────────────────────────────────

dbTest('a refused staff write is recorded, and louder', async () => {
  const staff = await makeStaff(UserRole.SUPPORT);

  await assert.rejects(
    run(
      request({ role: UserRole.SUPPORT, actorId: staff.id }),
      {
        handle: () =>
          throwError(() => Object.assign(new Error('nope'), { status: 403 })),
      },
    ),
    /nope/,
  );

  const [entry] = await awaitEntry(staff.id);
  assert.equal(entry.outcome, 'FAILED_403');
  assert.equal(
    entry.severity,
    AuditSeverity.WARNING,
    'a refused reach for a privileged screen is worth more than a successful one',
  );

  await cleanup(staff.id);
});

// ── What it deliberately ignores ────────────────────────────────────────

dbTest('a customer editing her own data is not an audit event', async () => {
  const customer = await makeStaff(UserRole.CUSTOMER);

  await run(
    request({
      role: UserRole.CUSTOMER,
      actorId: customer.id,
      route: '/addresses/:id',
      path: '/addresses/a1',
    }),
    ok,
  );

  assert.equal(
    (await expectNoEntry(customer.id)).length,
    0,
    'her data, her right — and logging every one would bury what matters',
  );

  await cleanup(customer.id);
});

dbTest('a read is never recorded', async () => {
  const staff = await makeStaff(UserRole.FINANCE_ADMIN);

  await run(
    request({ method: 'GET', role: UserRole.FINANCE_ADMIN, actorId: staff.id }),
    ok,
  );

  assert.equal((await expectNoEntry(staff.id)).length, 0);

  await cleanup(staff.id);
});

// ── It must never cost an action ────────────────────────────────────────

dbTest('a failing audit write does not fail the request', async () => {
  // An actor id with no user behind it violates the foreign key, which is the
  // simplest way to make the insert fail for real rather than by mocking.
  const orphan = randomUUID();

  const answer = await run(
    request({ role: UserRole.ADMIN, actorId: orphan }),
    ok,
  );

  assert.deepEqual(
    answer,
    { done: true },
    'a dropped audit line is a gap; a support agent who cannot act is an outage',
  );
});
