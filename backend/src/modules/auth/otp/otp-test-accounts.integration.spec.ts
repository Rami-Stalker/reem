import assert from 'node:assert/strict';
import test from 'node:test';
import { ConfigService } from '@nestjs/config';
import { OtpPurpose, PrismaClient, UserRole } from '@prisma/client';

import { PrismaService } from '../../../prisma/prisma.service';
import { OtpService } from '../otp.service';
import { OtpCipherService } from './otp-cipher.service';
import { OtpDispatcherService } from './otp-dispatcher.service';
import { parseOtpTestAccounts, testAccountsActive } from './otp-test-accounts';

/**
 * Fixed sign-in codes for named test accounts, through the real OtpService
 * against real Postgres. What must hold: the listed, registered number signs in
 * with its configured code and nothing is queued for delivery; every other
 * number — unlisted, or listed but unregistered — gets an ordinary random code
 * through the outbox; and nothing works once the window has closed.
 *
 * Numbers and codes here are fixtures, not the environment's.
 */
const prisma = new PrismaClient();
const db = prisma as unknown as PrismaService;
const stamp = String(Date.now()).slice(-7);
const listed = `+96399${stamp}1`;
const unregistered = `+96399${stamp}2`;
const unlisted = `+96399${stamp}3`;
const created: string[] = [];

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
  if (reachable) {
    await prisma.otpRequest.deleteMany({
      where: { destination: { in: [listed, unregistered, unlisted] } },
    });
    await prisma.user.deleteMany({ where: { id: { in: created } } });
  }
  await prisma.$disconnect();
});

function service(until: Date) {
  const config = new ConfigService({
    security: { otpPepper: 'test-pepper-for-fixed-otp-specs-000000' },
    otpDelivery: {
      testAccounts: `${listed}:111111,${unregistered}:222222`,
      testAccountsUntil: until.toISOString(),
    },
  });
  const cipher = new OtpCipherService(
    new ConfigService({ security: { otpDeliveryKey: 'k'.repeat(40) } }),
  );
  return new OtpService(db, new OtpDispatcherService(db, cipher), config);
}

async function user(phone: string) {
  const row = await prisma.user.create({
    data: {
      name: 'Fixed OTP Spec',
      phone,
      username: `fixed_otp_${phone.slice(-8)}`,
      role: UserRole.CUSTOMER,
    },
  });
  created.push(row.id);
  return row;
}

async function outboxFor(phone: string) {
  const challenge = await prisma.otpRequest.findFirst({
    where: { destination: phone },
    orderBy: { createdAt: 'desc' },
    include: { outbox: true },
  });
  return challenge?.outbox ?? null;
}

test('a listed, registered number signs in with its fixed code, and nothing is sent', async (t) => {
  if (!reachable) return t.skip('no database reachable');
  const owner = await user(listed);
  const otp = service(new Date(Date.now() + 60 * 60_000));

  await otp.request({ phone: listed, purpose: OtpPurpose.LOGIN, userId: owner.id });
  assert.equal(await outboxFor(listed), null, 'no delivery queued for a fixed code');

  // A wrong code is still refused and counted — verification is unchanged.
  await assert.rejects(otp.consume(listed, OtpPurpose.LOGIN, '999999'));
  await assert.doesNotReject(otp.consume(listed, OtpPurpose.LOGIN, '111111'));
});

test('a listed number with no account gets an ordinary code, not the fixed one', async (t) => {
  if (!reachable) return t.skip('no database reachable');
  const otp = service(new Date(Date.now() + 60 * 60_000));
  await otp.request({ phone: unregistered, purpose: OtpPurpose.LOGIN });
  assert.ok(await outboxFor(unregistered), 'a real code is queued for delivery');
  await assert.rejects(otp.consume(unregistered, OtpPurpose.LOGIN, '222222'));
});

test('an unlisted number is untouched', async (t) => {
  if (!reachable) return t.skip('no database reachable');
  const someone = await user(unlisted);
  const otp = service(new Date(Date.now() + 60 * 60_000));
  await otp.request({ phone: unlisted, purpose: OtpPurpose.LOGIN, userId: someone.id });
  assert.ok(await outboxFor(unlisted));
});

test('once the window has closed, the fixed code no longer works', async (t) => {
  if (!reachable) return t.skip('no database reachable');
  const owner = await prisma.user.findFirstOrThrow({ where: { phone: listed } });
  await prisma.otpRequest.deleteMany({ where: { destination: listed } });
  const otp = service(new Date(Date.now() - 1000));
  await otp.request({ phone: listed, purpose: OtpPurpose.LOGIN, userId: owner.id });
  assert.ok(await outboxFor(listed), 'back to a real, queued code');
  await assert.rejects(otp.consume(listed, OtpPurpose.LOGIN, '111111'));
});

test('parsing refuses anything but dated, well-formed entries', () => {
  const until = new Date(Date.now() + 60_000).toISOString();
  assert.throws(() => parseOtpTestAccounts('+963911111111:1234', until), /six-digit/);
  assert.throws(() => parseOtpTestAccounts('0911111111:123456', until), /E\.164/);
  assert.throws(() => parseOtpTestAccounts('+963911111111:123456', undefined), /requires OTP_TEST_ACCOUNTS_UNTIL/);
  assert.equal(testAccountsActive(parseOtpTestAccounts('', undefined)), false);
  assert.equal(testAccountsActive(parseOtpTestAccounts('+963911111111:123456', until)), true);
});
