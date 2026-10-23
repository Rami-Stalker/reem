import assert from 'node:assert/strict';
import test from 'node:test';
import { PrismaClient, SessionStatus, UserRole } from '@prisma/client';

import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../audit.service';
import {
  AccountDeletionService,
  DELETED_ACCOUNT_NAME,
} from './account-deletion.service';

/**
 * Deleting an account, against a real database.
 *
 * What matters is what is gone, what is left, and what stops it — so each
 * case reads the rows back rather than trusting the return value.
 */

const prisma = new PrismaClient();
const db = prisma as unknown as PrismaService;
const deletion = new AccountDeletionService(db, new AuditService(db));

let reachable = false;
const created: string[] = [];
let seq = 0;

test.before(async () => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    reachable = true;
  } catch {
    reachable = false;
  }
});

test.after(async () => {
  if (reachable && created.length > 0) {
    await prisma.wallet.deleteMany({ where: { userId: { in: created } } });
    await prisma.user.deleteMany({ where: { id: { in: created } } });
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

async function makeUser(role: UserRole = UserRole.CUSTOMER) {
  seq += 1;
  const stamp = `${Date.now()}${seq}`;
  const user = await prisma.user.create({
    data: {
      name: `Deletion Spec ${seq}`,
      username: `deletion_spec_${stamp}`,
      phone: `+9639${stamp.slice(-8)}`,
      email: `deletion_${stamp}@example.test`,
      bio: 'a bio that names her',
      role,
    },
  });
  created.push(user.id);
  return user;
}

dbTest('the account is emptied, signed out everywhere, and its number freed', async () => {
  const user = await makeUser();
  const friend = await makeUser();
  const later = new Date(Date.now() + 86_400_000);

  const session = await prisma.session.create({
    data: { userId: user.id, idleExpiresAt: later, absoluteExpiresAt: later },
  });
  await prisma.pushToken.create({
    data: {
      userId: user.id,
      tokenHash: `deletion-spec-${user.id}`,
      token: 'device-token',
      provider: 'fcm',
      sessionId: session.id,
    },
  });
  await prisma.address.create({
    data: {
      userId: user.id,
      recipientName: 'her name',
      recipientPhone: user.phone!,
      governorate: 'Damascus',
      city: 'Damascus',
      addressLine: 'her street',
    },
  });
  await prisma.follow.create({
    data: { followerId: user.id, followingId: friend.id },
  });
  await prisma.user.update({
    where: { id: friend.id },
    data: { followersCount: 1 },
  });

  assert.deepEqual((await deletion.preflight(user.id)).blockers, []);
  await deletion.deleteAccount(user.id, 'moving on');

  const after = await prisma.user.findUniqueOrThrow({ where: { id: user.id } });
  assert.equal(after.name, DELETED_ACCOUNT_NAME);
  assert.equal(after.phone, null);
  assert.equal(after.email, null);
  assert.equal(after.bio, null);
  assert.ok(after.disabledAt);
  assert.ok(after.deletedAt);

  const revoked = await prisma.session.findUniqueOrThrow({
    where: { id: session.id },
  });
  assert.equal(revoked.status, SessionStatus.REVOKED);
  assert.equal(await prisma.pushToken.count({ where: { userId: user.id } }), 0);
  assert.equal(await prisma.address.count({ where: { userId: user.id } }), 0);
  assert.equal(
    await prisma.follow.count({ where: { followerId: user.id } }),
    0,
  );
  const friendAfter = await prisma.user.findUniqueOrThrow({
    where: { id: friend.id },
  });
  assert.equal(friendAfter.followersCount, 0);

  // Her number can open a new account straight away.
  const again = await prisma.user.create({
    data: {
      name: 'New account',
      username: `deletion_spec_again_${Date.now()}`,
      phone: user.phone,
    },
  });
  created.push(again.id);

  const audit = await prisma.auditLog.findFirst({
    where: { actorId: user.id, action: 'account_deleted' },
  });
  assert.ok(audit);
});

dbTest('a deleted account cannot be deleted twice', async () => {
  const user = await makeUser();
  await deletion.deleteAccount(user.id, undefined);
  await assert.rejects(
    () => deletion.deleteAccount(user.id, undefined),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'ACCOUNT_ALREADY_DELETED',
  );
});

dbTest('money still held for her blocks deletion', async () => {
  const user = await makeUser();
  await prisma.wallet.create({ data: { userId: user.id, balance: 2500 } });

  const preflight = await deletion.preflight(user.id);
  assert.equal(preflight.can_delete, false);
  assert.deepEqual(
    preflight.blockers.map((blocker) => blocker.code),
    ['WALLET_BALANCE'],
  );
  await assert.rejects(
    () => deletion.deleteAccount(user.id, undefined),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'ACCOUNT_DELETION_BLOCKED',
  );
  const untouched = await prisma.user.findUniqueOrThrow({
    where: { id: user.id },
  });
  assert.equal(untouched.deletedAt, null);
});

dbTest('a staff account is closed by an admin, not by itself', async () => {
  const user = await makeUser(UserRole.SUPPORT);
  const preflight = await deletion.preflight(user.id);
  assert.deepEqual(
    preflight.blockers.map((blocker) => blocker.code),
    ['STAFF_ACCOUNT'],
  );
});
