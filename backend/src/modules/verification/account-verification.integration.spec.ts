import assert from 'node:assert/strict';
import test from 'node:test';
import {
  AccountVerificationStatus,
  PrismaClient,
  UserRole,
} from '@prisma/client';

import { AuditService } from '../auth/audit.service';
import { MediaService } from '../media/media.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AccountVerificationService } from './account-verification.service';

/**
 * The badge, and what it is now allowed to mean.
 *
 * The thing under test is a rule rather than a feature: `users.is_verified` is
 * written in exactly one method, by a reviewer, with a reason. Everything here
 * pins one half of that — that a claim cannot be made without a proved number,
 * that a decision grants or withdraws the badge and records who took it, that
 * «نحتاج توضيح» leaves the account where it was, and that a refusal cannot be
 * resubmitted the same afternoon.
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

interface World {
  tx: Tx;
  verification: AccountVerificationService;
  notified: { userId: string; title: string }[];
}

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

function build(tx: Tx): World {
  const db = new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (arg: unknown) =>
          typeof arg === 'function'
            ? (arg as (inner: Tx) => unknown)(tx)
            : Promise.all(arg as Promise<unknown>[]);
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;

  const notified: { userId: string; title: string }[] = [];
  const notifications = {
    notifyAccount: async (input: { userId: string; title: string }) => {
      notified.push(input);
    },
  } as unknown as NotificationsService;
  const media = {
    markAttached: async () => undefined,
  } as unknown as MediaService;

  return {
    tx,
    notified,
    verification: new AccountVerificationService(
      db,
      new AuditService(db),
      media,
      notifications,
    ),
  };
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;

async function makeUser(
  tx: Tx,
  tag: string,
  options: { phoneVerified?: boolean; role?: UserRole } = {},
) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `ver-${tag}`,
      username: `ver_${u}`,
      phone: `+9638${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role: options.role ?? UserRole.CUSTOMER,
      phoneVerifiedAt: options.phoneVerified === false ? null : new Date(),
    },
  });
}

const claim = {
  legal_name: 'ريم الشامي',
  document_type: 'national_id',
  document_front_url: 'https://media.reem.sy/id-front.jpg',
  selfie_url: 'https://media.reem.sy/selfie.jpg',
};

// ── The badge is granted, never assumed ────────────────────────────────────

dbTest('a new account wears no badge, however it signed in', async (world) => {
  // Registration and every OTP path set `phoneVerifiedAt` and nothing else.
  const user = await makeUser(world.tx, 'a');
  assert.equal(user.isVerified, false);
  assert.equal(user.verifiedAt, null);
  assert.notEqual(user.phoneVerifiedAt, null);
});

dbTest('an approval grants the badge and records who granted it', async (world) => {
  const user = await makeUser(world.tx, 'b');
  const staff = await makeUser(world.tx, 'c', { role: UserRole.SUPER_ADMIN });

  const filed = await world.verification.submit(user.id, claim);
  assert.equal(filed.status, 'pending');

  const decided = await world.verification.decide(staff.id, filed.id, {
    status: AccountVerificationStatus.APPROVED,
    reason: 'الهوية واضحة والاسم مطابق',
  });
  assert.equal(decided.status, 'approved');

  const after = await world.tx.user.findUniqueOrThrow({
    where: { id: user.id },
  });
  assert.equal(after.isVerified, true);
  assert.notEqual(after.verifiedAt, null);

  // Who, when and why — the whole reason this is not a boolean.
  const history = await world.tx.accountVerificationStatusEvent.findMany({
    where: { verificationId: filed.id },
    orderBy: { createdAt: 'asc' },
  });
  assert.deepEqual(
    history.map((event) => event.status),
    [
      AccountVerificationStatus.PENDING,
      AccountVerificationStatus.APPROVED,
    ],
  );
  assert.equal(history[1].actorId, staff.id);
  assert.equal(history[1].reason, 'الهوية واضحة والاسم مطابق');

  const audit = await world.tx.auditLog.findFirst({
    where: { action: 'account_verification_decided', actorId: staff.id },
  });
  assert.ok(audit, 'the decision is in the audit trail');

  // And she is told.
  assert.equal(world.notified.at(-1)?.userId, user.id);
});

dbTest('a revocation takes the badge back', async (world) => {
  const user = await makeUser(world.tx, 'd');
  const staff = await makeUser(world.tx, 'e', { role: UserRole.SUPER_ADMIN });
  const filed = await world.verification.submit(user.id, claim);

  await world.verification.decide(staff.id, filed.id, {
    status: AccountVerificationStatus.APPROVED,
    reason: 'ok',
  });
  await world.verification.decide(staff.id, filed.id, {
    status: AccountVerificationStatus.REVOKED,
    reason: 'الوثيقة تبيّن أنها مزوّرة',
  });

  const after = await world.tx.user.findUniqueOrThrow({
    where: { id: user.id },
  });
  assert.equal(after.isVerified, false);
  assert.equal(after.verifiedAt, null);
});

dbTest('«نحتاج توضيح» is a question, not a decision', async (world) => {
  const user = await makeUser(world.tx, 'f');
  const staff = await makeUser(world.tx, 'g', { role: UserRole.SUPER_ADMIN });
  const filed = await world.verification.submit(user.id, claim);

  const asked = await world.verification.decide(staff.id, filed.id, {
    status: AccountVerificationStatus.NEEDS_MORE_INFO,
    reason: 'الصورة مو واضحة، ابعتي وحدة أوضح',
  });

  assert.equal(asked.status, 'needs_more_info');
  // The reviewer's words reach her, which is what makes it actionable.
  assert.equal(asked.review_note, 'الصورة مو واضحة، ابعتي وحدة أوضح');
  assert.equal(asked.can_resubmit, true);

  // And nothing about the account changed either way.
  const after = await world.tx.user.findUniqueOrThrow({
    where: { id: user.id },
  });
  assert.equal(after.isVerified, false);

  // She sends a clearer photograph, and it reaches the same claim.
  const again = await world.verification.submit(user.id, {
    ...claim,
    document_front_url: 'https://media.reem.sy/id-front-2.jpg',
  });
  assert.equal(again.id, filed.id);
  assert.equal(again.status, 'pending');
  // The old note described a submission that no longer exists.
  assert.equal(again.review_note, null);

  const count = await world.tx.accountVerification.count({
    where: { userId: user.id },
  });
  assert.equal(count, 1);
});

// ── What a claim costs ─────────────────────────────────────────────────────

dbTest('an unproved number cannot ask for a badge', async (world) => {
  const user = await makeUser(world.tx, 'h', { phoneVerified: false });
  await assert.rejects(
    world.verification.submit(user.id, claim),
    /verify your phone/i,
  );
});

dbTest('a refusal stands for a fortnight', async (world) => {
  const user = await makeUser(world.tx, 'i');
  const staff = await makeUser(world.tx, 'j', { role: UserRole.SUPER_ADMIN });
  const filed = await world.verification.submit(user.id, claim);
  await world.verification.decide(staff.id, filed.id, {
    status: AccountVerificationStatus.REJECTED,
    reason: 'الاسم ما بيطابق',
  });

  await assert.rejects(
    world.verification.submit(user.id, claim),
    /apply again after/i,
  );

  // Two weeks later she may try again.
  await world.tx.accountVerification.update({
    where: { id: filed.id },
    data: { reviewedAt: new Date(Date.now() - 15 * 24 * 60 * 60 * 1000) },
  });
  const again = await world.verification.submit(user.id, claim);
  assert.equal(again.status, 'pending');
});

dbTest('an approved account does not queue up again', async (world) => {
  const user = await makeUser(world.tx, 'k');
  const staff = await makeUser(world.tx, 'l', { role: UserRole.SUPER_ADMIN });
  const filed = await world.verification.submit(user.id, claim);
  await world.verification.decide(staff.id, filed.id, {
    status: AccountVerificationStatus.APPROVED,
    reason: 'ok',
  });

  await assert.rejects(
    world.verification.submit(user.id, claim),
    /already verified/i,
  );
});

dbTest('staff cannot push a claim back into the queue themselves', async (world) => {
  const user = await makeUser(world.tx, 'm');
  const staff = await makeUser(world.tx, 'n', { role: UserRole.SUPER_ADMIN });
  const filed = await world.verification.submit(user.id, claim);
  await world.verification.decide(staff.id, filed.id, {
    status: AccountVerificationStatus.UNDER_REVIEW,
    reason: 'أخذتها',
  });

  // Only the account may resubmit; a reviewer returning it to PENDING would
  // erase the fact that somebody had already looked at it.
  await assert.rejects(
    world.verification.decide(staff.id, filed.id, {
      status: AccountVerificationStatus.PENDING,
      reason: 'رجعتها',
    }),
    /only the account/i,
  );
});

// ── The queue ──────────────────────────────────────────────────────────────

dbTest('the queue answers the oldest claim first', async (world) => {
  const first = await makeUser(world.tx, 'o');
  const second = await makeUser(world.tx, 'p');
  await world.verification.submit(first.id, claim);
  await world.verification.submit(second.id, claim);
  // Backdate the first so the order is unambiguous.
  await world.tx.accountVerification.update({
    where: { userId: first.id },
    data: { submittedAt: new Date(Date.now() - 86_400_000) },
  });

  const queue = await world.verification.list({
    status: AccountVerificationStatus.PENDING,
  });
  const ids = queue.items.map((row) => row.user_id);
  assert.ok(ids.indexOf(first.id) < ids.indexOf(second.id));
});

dbTest('a withdrawn claim takes its documents with it', async (world) => {
  const user = await makeUser(world.tx, 'q');
  await world.verification.submit(user.id, claim);
  await world.verification.withdraw(user.id);

  assert.equal(await world.verification.mine(user.id), null);
});
