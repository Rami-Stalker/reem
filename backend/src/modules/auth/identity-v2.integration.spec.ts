import assert from 'node:assert/strict';
import test from 'node:test';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  AccountRecoveryStatus,
  OtpPurpose,
  PhoneChangeStatus,
  PrismaClient,
  SessionStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from './audit.service';
import { OtpService } from './otp.service';
import { OtpDispatcherService } from './otp/otp-dispatcher.service';
import { PhoneChangeService } from './phone-change/phone-change.service';
import { AccountRecoveryService } from './recovery/account-recovery.service';
import { RegistrationTicketService } from './login/registration-ticket.service';

/**
 * The four properties Identity v2 rests on, tested against a real database.
 *
 * Each of these was a live hole before, and each is the kind of thing a unit
 * test with a mocked client cannot honestly cover — they are about what is
 * *committed*: which sessions survive a phone change, whether two approvals
 * really came from two accounts, whether time alone can complete a hand-over.
 */
const prisma = new PrismaClient();
const db = prisma as unknown as PrismaService;

/** The dev pepper is enough; nothing here checks a production secret. */
const config = new ConfigService({
  security: { otpPepper: 'test-pepper-for-identity-v2-specs' },
  jwt: { accessSecret: 'test-access-secret-for-identity-v2-specs' },
});

/**
 * The real dispatcher seals codes under a 32-byte key we do not need here, and
 * delivery is somebody else's subsystem — these specs care about the state
 * machine, so the outbox is stubbed to a no-op.
 */
const dispatcher = {
  enqueue: async () => undefined,
  shred: async () => undefined,
} as unknown as OtpDispatcherService;

const otp = new OtpService(db, dispatcher, config);
const audit = new AuditService(db);
const phoneChanges = new PhoneChangeService(db, otp, audit);
const recovery = new AccountRecoveryService(db, otp, audit, config);
const tickets = new RegistrationTicketService(new JwtService({}), config);

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

let seq = 0;
const created: string[] = [];

function uniqueDigits(): string {
  seq += 1;
  // 9 digits after the country code, deterministic per run and unlikely to
  // collide with seeded data.
  return String(700_000_000 + ((Date.now() % 1_000_000) * 100 + seq) % 99_999_999);
}

function phone(): string {
  return `+963${uniqueDigits()}`;
}

async function makeUser(role: UserRole = UserRole.CUSTOMER): Promise<{
  id: string;
  phone: string;
}> {
  const number = phone();
  seq += 1;
  const user = await prisma.user.create({
    data: {
      name: `Identity Spec ${seq}`,
      username: `identity_spec_${Date.now()}_${seq}`,
      phone: number,
      role,
      phoneVerifiedAt: new Date(),
      isVerified: true,
    },
  });
  created.push(user.id);
  return { id: user.id, phone: number };
}

/** Reads the plaintext of the challenge just written for a destination. */
async function latestCode(
  destination: string,
  purpose: OtpPurpose,
): Promise<string> {
  // Codes are stored as a peppered HMAC, so a spec cannot read one back. It
  // can, however, search the six-digit space against the same digest the
  // service uses — 10^6 HMACs is well under a second and keeps the test honest
  // about the storage format rather than reaching around it.
  const { createHmac } = await import('crypto');
  const request = await prisma.otpRequest.findFirst({
    where: { destination, purpose, status: 'PENDING' },
    orderBy: { createdAt: 'desc' },
  });
  assert.ok(request, `no pending ${purpose} challenge for ${destination}`);
  for (let candidate = 0; candidate < 1_000_000; candidate++) {
    const code = String(candidate).padStart(6, '0');
    const digest = createHmac('sha256', 'test-pepper-for-identity-v2-specs')
      .update(code)
      .digest('hex');
    if (digest === request.codeHash) return code;
  }
  throw new Error('could not recover the issued code');
}

async function cleanup(userIds: string[]): Promise<void> {
  for (const id of userIds) {
    await prisma.user.delete({ where: { id } }).catch(() => undefined);
  }
}

test.after(async () => {
  if (reachable) await cleanup(created);
});

// ───────────────────────── Two-sided phone change ─────────────────────────

dbTest(
  'a phone change cannot skip the challenge on the number being left',
  async () => {
    const user = await makeUser();
    const target = phone();

    const started = await phoneChanges.start(user.id, target, {});
    assert.equal(started.status, 'awaiting_current');
    // The response never names the number in full — an attacker holding the
    // session must not be able to read it back out.
    assert.ok(!started.masked_current.includes(user.phone.slice(5, 9)));

    // Jumping straight to the final step with a code for the NEW number — the
    // proof a SIM swapper actually has — must not move the account.
    await assert.rejects(
      () => phoneChanges.confirm(user.id, started.id, '000000', {}),
      (error: { response?: { code?: string } }) =>
        error.response?.code === 'PHONE_CHANGE_WRONG_STEP',
    );

    const untouched = await prisma.user.findUnique({ where: { id: user.id } });
    assert.equal(untouched?.phone, user.phone);
  },
);

dbTest(
  'proving both numbers moves the account, cuts other sessions and freezes payouts',
  async () => {
    const user = await makeUser();
    const target = phone();

    // A session that is not the one performing the change: it must not survive.
    const other = await prisma.session.create({
      data: {
        userId: user.id,
        idleExpiresAt: new Date(Date.now() + 86_400_000),
        absoluteExpiresAt: new Date(Date.now() + 86_400_000),
      },
    });

    const started = await phoneChanges.start(user.id, target, {});
    const currentCode = await latestCode(user.phone, OtpPurpose.PHONE_CHANGE);
    const second = await phoneChanges.verifyCurrent(
      user.id,
      started.id,
      currentCode,
      {},
    );
    assert.equal(second.status, 'awaiting_new');

    const newCode = await latestCode(target, OtpPurpose.PHONE_VERIFICATION);
    const done = await phoneChanges.confirm(user.id, started.id, newCode, {});

    assert.equal(done.status, 'completed');
    assert.equal(done.phone, target);

    const moved = await prisma.user.findUnique({ where: { id: user.id } });
    assert.equal(moved?.phone, target);
    assert.ok(moved?.phoneVerifiedAt);
    // Seven days of stillness on the money, because a phone change is the
    // shape a takeover has.
    assert.ok(moved?.payoutFrozenUntil);
    assert.ok(moved!.payoutFrozenUntil! > new Date());
    assert.equal(moved?.payoutFreezeReason, 'phone_change');

    const survivor = await prisma.session.findUnique({ where: { id: other.id } });
    assert.equal(survivor?.status, SessionStatus.REVOKED);
    assert.equal(survivor?.revokedReason, 'phone_changed');
  },
);

dbTest('a number already in use cannot be claimed by a change', async () => {
  const user = await makeUser();
  const squatter = await makeUser();

  await assert.rejects(
    () => phoneChanges.start(user.id, squatter.phone, {}),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'PHONE_ALREADY_REGISTERED',
  );
});

// ───────────────────────── Dual-control recovery ─────────────────────────

async function openCase(subject: { phone: string }): Promise<string> {
  const contact = phone();
  await otp.request({ phone: contact, purpose: OtpPurpose.ACCOUNT_RECOVERY });
  const code = await latestCode(contact, OtpPurpose.ACCOUNT_RECOVERY);
  const result = await recovery.submit(
    {
      claimed_phone: subject.phone,
      contact_phone: contact,
      contact_code: code,
    },
    {},
  );
  return result.case_id;
}

dbTest('one reviewer cannot approve a recovery case alone', async () => {
  const owner = await makeUser();
  const staff = await makeUser(UserRole.SUPPORT);
  const caseId = await openCase(owner);

  const first = await recovery.approve(caseId, staff.id, undefined, {});
  assert.equal(first.status, 'awaiting_second_approval');
  assert.equal(first.approvals, 1);

  // The same account clicking approve twice is the whole attack dual control
  // exists to stop.
  await assert.rejects(
    () => recovery.approve(caseId, staff.id, undefined, {}),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'DUAL_CONTROL_REQUIRED',
  );

  const stillWaiting = await prisma.accountRecoveryCase.findUnique({
    where: { id: caseId },
  });
  assert.equal(
    stillWaiting?.status,
    AccountRecoveryStatus.AWAITING_SECOND_APPROVAL,
  );
  assert.equal(stillWaiting?.coolOffUntil, null);
});

dbTest(
  'two reviewers start a 72-hour clock, and nothing completes before it runs out',
  async () => {
    const owner = await makeUser();
    const first = await makeUser(UserRole.SUPPORT);
    const second = await makeUser(UserRole.SUPPORT_ADMIN);
    const caseId = await openCase(owner);

    await recovery.approve(caseId, first.id, undefined, {});
    const approved = await recovery.approve(caseId, second.id, undefined, {});
    assert.equal(approved.status, 'cooling_off');
    assert.equal(approved.approvals, 2);

    const row = await prisma.accountRecoveryCase.findUnique({
      where: { id: caseId },
    });
    const hours =
      (row!.coolOffUntil!.getTime() - Date.now()) / 3_600_000;
    assert.ok(hours > 71 && hours < 73, `cool-off was ${hours} hours`);

    // Now, before the clock runs out: nothing happens.
    assert.equal(await recovery.completeMaturedCases(new Date()), 0);
    const untouched = await prisma.user.findUnique({ where: { id: owner.id } });
    assert.equal(untouched?.phone, owner.phone);
  },
);

dbTest(
  'once the cool-off elapses the account moves and everything it could authenticate with is gone',
  async () => {
    const owner = await makeUser();
    const first = await makeUser(UserRole.SUPPORT);
    const second = await makeUser(UserRole.SUPPORT_ADMIN);
    const caseId = await openCase(owner);

    // Give her the full complement: a password, a live session, a device.
    await prisma.user.update({
      where: { id: owner.id },
      data: { passwordHash: 'argon2-placeholder', passwordSetAt: new Date() },
    });
    const session = await prisma.session.create({
      data: {
        userId: owner.id,
        idleExpiresAt: new Date(Date.now() + 86_400_000),
        absoluteExpiresAt: new Date(Date.now() + 86_400_000),
      },
    });
    const deviceKey = await prisma.deviceKey.create({
      data: {
        userId: owner.id,
        publicKey: `spec-key-${Date.now()}-${seq++}`,
        verifiedAt: new Date(),
      },
    });

    await recovery.approve(caseId, first.id, undefined, {});
    await recovery.approve(caseId, second.id, undefined, {});

    const row = await prisma.accountRecoveryCase.findUnique({
      where: { id: caseId },
    });
    // Counted, not asserted on exactly: other specs in this file leave cases
    // cooling off, and a clock wound three days forward matures those too.
    const afterCoolOff = new Date(row!.coolOffUntil!.getTime() + 1000);
    assert.ok((await recovery.completeMaturedCases(afterCoolOff)) >= 1);
    const closed = await prisma.accountRecoveryCase.findUnique({
      where: { id: caseId },
    });
    assert.equal(closed?.status, AccountRecoveryStatus.COMPLETED);

    const handedOver = await prisma.user.findUnique({
      where: { id: owner.id },
    });
    assert.equal(handedOver?.phone, row!.newPhone);
    assert.equal(handedOver?.passwordHash, null);
    assert.equal(handedOver?.passwordSetAt, null);
    assert.ok(handedOver?.payoutFrozenUntil);
    assert.equal(handedOver?.payoutFreezeReason, 'account_recovery');

    const deadSession = await prisma.session.findUnique({
      where: { id: session.id },
    });
    assert.equal(deadSession?.status, SessionStatus.REVOKED);

    const deadDevice = await prisma.deviceKey.findUnique({
      where: { id: deviceKey.id },
    });
    assert.ok(deadDevice?.revokedAt, 'the old handset must lose its key');
  },
);

dbTest('the owner can kill a case from a live session', async () => {
  const owner = await makeUser();
  const staff = await makeUser(UserRole.SUPPORT);
  const caseId = await openCase(owner);
  await recovery.approve(caseId, staff.id, undefined, {});

  const cancelled = await recovery.cancelByOwner(owner.id, caseId, {});
  assert.equal(cancelled.status, 'cancelled');

  // And a cancelled case is inert: time passing does nothing for it.
  assert.equal(
    await recovery.completeMaturedCases(new Date(Date.now() + 30 * 86_400_000)),
    0,
  );
  const untouched = await prisma.user.findUnique({ where: { id: owner.id } });
  assert.equal(untouched?.phone, owner.phone);
});

dbTest(
  'a privileged account is refused this path, and the claimant is told nothing',
  async () => {
    const admin = await makeUser(UserRole.ADMIN);
    const caseId = await openCase(admin);

    const row = await prisma.accountRecoveryCase.findUnique({
      where: { id: caseId },
    });
    assert.equal(row?.status, AccountRecoveryStatus.REJECTED);
    // Not even attached to the account: the queue must not offer it as a
    // reviewable case at all.
    assert.equal(row?.userId, null);
  },
);

// ─────────────────── The OTP-first primitives underneath ───────────────────

dbTest('a challenge bound to a nonce refuses a code without it', async () => {
  const number = phone();
  await otp.request({
    phone: number,
    purpose: OtpPurpose.LOGIN,
    clientNonce: 'the-app-instance-that-asked',
  });
  const code = await latestCode(number, OtpPurpose.LOGIN);

  // The relay attack: the code is correct, the app instance is not hers.
  await assert.rejects(
    () => otp.verify(number, OtpPurpose.LOGIN, code, 'a-different-install'),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'INVALID_OTP',
  );
  await assert.rejects(
    () => otp.verify(number, OtpPurpose.LOGIN, code),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'INVALID_OTP',
  );

  const accepted = await otp.verify(
    number,
    OtpPurpose.LOGIN,
    code,
    'the-app-instance-that-asked',
  );
  assert.equal(accepted.verified, true);
});

dbTest('a registration ticket only vouches for the number it was minted for', async () => {
  const number = phone();
  const { registration_ticket } = await tickets.issue({
    phone: number,
    otp_request_id: '',
  });

  const claims = await tickets.verify(registration_ticket);
  assert.equal(claims?.phone, number);

  assert.equal(await tickets.verify('not-a-ticket'), null);
  assert.equal(await tickets.verify(`${registration_ticket}x`), null);
});

dbTest('an expired phone change cannot be resumed', async () => {
  const user = await makeUser();
  const started = await phoneChanges.start(user.id, phone(), {});

  await prisma.phoneChangeRequest.update({
    where: { id: started.id },
    data: { expiresAt: new Date(Date.now() - 1000) },
  });

  await assert.rejects(
    () => phoneChanges.verifyCurrent(user.id, started.id, '000000', {}),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'PHONE_CHANGE_EXPIRED',
  );

  const row = await prisma.phoneChangeRequest.findUnique({
    where: { id: started.id },
  });
  assert.equal(row?.status, PhoneChangeStatus.EXPIRED);
});
