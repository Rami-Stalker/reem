import assert from 'node:assert/strict';
import test from 'node:test';
import {
  AuditSeverity,
  PrismaClient,
  ProductStatus,
  ReportStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../auth/audit.service';
import { AuthService } from '../auth/auth.service';
import { TotpService } from '../auth/totp/totp.service';
import { AdminService } from './admin.service';
import { AdminListQueryDto } from './dto/admin.dto';

/**
 * The console's governance writes, against real Postgres.
 *
 * Every one of these used to be an endpoint with no screen behind it, so the
 * behaviour that mattered — that a suspension is recorded, that a settings
 * change names who made it, that a queue can be paged past its first page —
 * had never been exercised by anything. Each case runs inside a transaction
 * that is rolled back, so the database is left as it was found.
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

function dbTest(name: string, body: () => Promise<void>): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    await body();
  });
}

class Rollback extends Error {}

type Tx = Parameters<Parameters<typeof prisma.$transaction>[0]>[0];

async function inRolledBackTx(body: (tx: Tx) => Promise<void>): Promise<void> {
  let failure: unknown;
  try {
    await prisma.$transaction(
      async (tx) => {
        try {
          await body(tx);
        } catch (error) {
          failure = error;
        }
        throw new Rollback();
      },
      { timeout: 30000 },
    );
  } catch (error) {
    if (!(error instanceof Rollback)) throw error;
  }
  if (failure) throw failure;
}

/**
 * The service under test, bound to the transaction.
 *
 * `AuthService` is only reached by the seller-review passthrough, which has
 * its own suite; TOTP only by the privileged-role guard, which is asserted
 * here through the role it refuses.
 */
function serviceFor(tx: Tx): AdminService {
  const prismaLike = tx as unknown as PrismaService;
  return new AdminService(
    prismaLike,
    {} as unknown as AuthService,
    { isConfirmed: async () => false } as unknown as TotpService,
    new AuditService(prismaLike),
  );
}

let sequence = 0;
function unique(tag: string): string {
  sequence += 1;
  return `${Date.now()}${sequence}${Math.floor(Math.random() * 1000)}${tag}`;
}

async function makeUser(tx: Tx, tag: string, role: UserRole = UserRole.CUSTOMER) {
  const u = unique(tag);
  return tx.user.create({
    data: {
      name: `adm-${tag}`,
      username: `adm_${u}`,
      phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role,
    },
  });
}

async function auditEntries(tx: Tx, actorId: string) {
  return tx.auditLog.findMany({
    where: { actorId, category: 'admin' },
    orderBy: { createdAt: 'desc' },
  });
}

dbTest('suspending an account is recorded against the administrator', () =>
  inRolledBackTx(async (tx) => {
    const admin = await makeUser(tx, 'actor', UserRole.ADMIN);
    const shopper = await makeUser(tx, 'subject');
    const service = serviceFor(tx);

    const updated = await service.updateUser(admin.id, shopper.id, {
      disabled: true,
      reason: 'Repeated chargebacks',
    });

    assert.equal(updated.is_disabled, true);
    assert.ok(updated.disabled_at);

    const entries = await auditEntries(tx, admin.id);
    assert.equal(entries.length, 1);
    assert.equal(entries[0].action, 'user_access_changed');
    // Locking someone out is the entry an incident review looks for, so it
    // must not be filed at the same weight as a routine read.
    assert.equal(entries[0].severity, AuditSeverity.WARNING);

    const metadata = entries[0].metadata as Record<string, unknown>;
    assert.equal(metadata.user_id, shopper.id);
    assert.equal(metadata.disabled_from, false);
    assert.equal(metadata.disabled_to, true);
    assert.equal(metadata.reason, 'Repeated chargebacks');
  }),
);

dbTest('restoring an account clears the suspension', () =>
  inRolledBackTx(async (tx) => {
    const admin = await makeUser(tx, 'actor2', UserRole.ADMIN);
    const shopper = await makeUser(tx, 'subject2');
    const service = serviceFor(tx);

    await service.updateUser(admin.id, shopper.id, {
      disabled: true,
      reason: 'Under investigation',
    });
    const restored = await service.updateUser(admin.id, shopper.id, {
      disabled: false,
      reason: 'Cleared',
    });

    assert.equal(restored.is_disabled, false);
    assert.equal(restored.disabled_at, null);
  }),
);

dbTest('an administrator cannot suspend or demote herself', () =>
  inRolledBackTx(async (tx) => {
    const admin = await makeUser(tx, 'self', UserRole.ADMIN);
    const service = serviceFor(tx);

    await assert.rejects(
      () => service.updateUser(admin.id, admin.id, { disabled: true }),
      /another administrator/i,
    );
  }),
);

dbTest('a privileged role is refused until an authenticator exists', () =>
  inRolledBackTx(async (tx) => {
    const admin = await makeUser(tx, 'granter', UserRole.SUPER_ADMIN);
    const staff = await makeUser(tx, 'grantee');
    const service = serviceFor(tx);

    await assert.rejects(
      () =>
        service.updateUser(admin.id, staff.id, {
          role: UserRole.FINANCE_ADMIN,
          reason: 'Joins the finance team',
        }),
      /authenticator/i,
    );

    // A refused grant is not an action, so it leaves no entry behind either.
    assert.equal((await auditEntries(tx, admin.id)).length, 0);
  }),
);

dbTest('a settings change is attributed and does not leak a secret', () =>
  inRolledBackTx(async (tx) => {
    const admin = await makeUser(tx, 'settings', UserRole.SUPER_ADMIN);
    const service = serviceFor(tx);
    const key = `test.${unique('k')}`;

    await service.upsertSystemSetting(admin.id, {
      key,
      value: { token: 'super-secret' },
      sensitive: true,
    });

    const entries = await auditEntries(tx, admin.id);
    assert.equal(entries[0].action, 'system_setting_changed');
    const metadata = entries[0].metadata as Record<string, unknown>;
    assert.equal(metadata.key, key);
    assert.equal(metadata.created, true);
    // The audit log is read by more people than the setting is.
    assert.equal('value' in metadata, false);

    // And the list masks it too.
    const listed = await service.systemSettings();
    const row = listed.items.find((item) => item.key === key);
    assert.ok(row);
    assert.equal(row.sensitive, true);
    assert.equal(row.value, null);
  }),
);

dbTest('a non-sensitive setting keeps its value visible', () =>
  inRolledBackTx(async (tx) => {
    const admin = await makeUser(tx, 'settings2', UserRole.SUPER_ADMIN);
    const service = serviceFor(tx);
    const key = `test.${unique('k')}`;

    await service.upsertSystemSetting(admin.id, {
      key,
      value: { enabled: true },
      sensitive: false,
    });

    const listed = await service.systemSettings();
    const row = listed.items.find((item) => item.key === key);
    assert.ok(row);
    assert.deepEqual(row.value, { enabled: true });
    assert.equal(row.updated_by, admin.id);
  }),
);

dbTest('a report decision is recorded and stamps the resolution time', () =>
  inRolledBackTx(async (tx) => {
    const admin = await makeUser(tx, 'reporter', UserRole.ADMIN);
    const service = serviceFor(tx);
    const report = await tx.adminReport.create({
      data: { title: 'Weekly sales', type: 'sales', payload: {} },
    });

    const decided = await service.updateReport(admin.id, report.id, {
      status: ReportStatus.RESOLVED,
    });

    assert.equal(decided.status, ReportStatus.RESOLVED);
    // `resolved_at`, because this queue answers in the same snake_case as the
    // rest of the console now. It used to hand the console a raw Prisma row.
    assert.ok(decided.resolved_at);
    const entries = await auditEntries(tx, admin.id);
    assert.equal(entries[0].action, 'report_decided');
  }),
);

dbTest('the users list pages and counts the whole table', () =>
  inRolledBackTx(async (tx) => {
    const service = serviceFor(tx);
    const marker = unique('page');
    for (let i = 0; i < 3; i += 1) {
      await tx.user.create({
        data: {
          name: `pager ${marker}`,
          username: `pager_${marker}_${i}`,
          phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
          passwordHash: 'x',
        },
      });
    }

    const query = new AdminListQueryDto();
    query.q = `pager ${marker}`;
    query.limit = 2;

    const first = await service.users(query);
    assert.equal(first.items.length, 2);
    assert.equal(first.total, 3);
    assert.equal(first.has_more, true);

    query.page = 2;
    const second = await service.users(query);
    assert.equal(second.items.length, 1);
    assert.equal(second.has_more, false);
    // The second page is different rows, not the same ones again.
    const ids = new Set([
      ...first.items.map((item) => item.id),
      ...second.items.map((item) => item.id),
    ]);
    assert.equal(ids.size, 3);
  }),
);

dbTest('searching products asks the database, not the current page', () =>
  inRolledBackTx(async (tx) => {
    const service = serviceFor(tx);
    const category = await tx.category.findFirst();
    if (!category) return; // A catalogue with no categories has no products.

    const marker = unique('sku');
    await tx.product.create({
      data: {
        slug: `probe-${marker}`,
        title: `Probe ${marker}`,
        description: 'A product created only to be searched for.',
        categoryId: category.id,
        status: ProductStatus.DRAFT,
      },
    });

    const query = new AdminListQueryDto();
    query.q = marker;
    const found = await service.products(query);

    assert.equal(found.total, 1);
    assert.equal(found.items.length, 1);

    // And the status filter narrows it rather than being ignored.
    query.status = ProductStatus.ACTIVE;
    const filtered = await service.products(query);
    assert.equal(filtered.total, 0);
  }),
);
