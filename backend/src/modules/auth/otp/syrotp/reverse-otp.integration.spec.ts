import assert from 'node:assert/strict';
import test from 'node:test';
import { ConfigService } from '@nestjs/config';
import {
  OtpDeliveryMode,
  OtpPurpose,
  OtpStatus,
  PrismaClient,
  ReverseCeremony,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../../../prisma/prisma.service';
import { OtpService } from '../../otp.service';
import { OtpCipherService } from '../otp-cipher.service';
import { OtpDispatcherService } from '../otp-dispatcher.service';
import { ReverseChallenge, ReverseSmsService, ReverseStatus } from './reverse-sms.service';

/**
 * The reverse rail through the real `OtpService` against real Postgres, with
 * the provider replaced by a stub whose answers the test chooses.
 *
 * What must hold, and each of these was a way to get in for free if it did not:
 * a reverse challenge is not settleable by typing a code; it is settled only
 * by the provider's own `verified`; it is settled at most once; and a provider
 * that cannot be reached at request time quietly becomes the old rail instead
 * of a failed sign-in.
 */
const prisma = new PrismaClient();
const db = prisma as unknown as PrismaService;
const stamp = String(Date.now()).slice(-7);
const phones: string[] = [];
const created: string[] = [];

/** A fresh number per case: `assertRateLimit` allows one request a minute. */
function phone(tag: string) {
  const value = `+96398${stamp}${phones.length}`;
  phones.push(value);
  void tag;
  return value;
}

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
    await prisma.otpRequest.deleteMany({ where: { destination: { in: phones } } });
    await prisma.user.deleteMany({ where: { id: { in: created } } });
  }
  await prisma.$disconnect();
});

/** The provider, as far as `OtpService` can tell. */
class StubReverse {
  started: { phone: string; purpose: OtpPurpose }[] = [];
  constructor(
    private readonly opens: ReverseChallenge | null,
    private answer: ReverseStatus = 'pending',
  ) {}
  isPrimary() {
    return true;
  }
  isUsable() {
    return true;
  }
  async start(input: { phone: string; purpose: OtpPurpose }) {
    this.started.push(input);
    return this.opens;
  }
  async status() {
    return this.answer;
  }
  async cancel() {}
  says(answer: ReverseStatus) {
    this.answer = answer;
  }
}

function challenge(
  ref: string,
  ceremony: ReverseCeremony = ReverseCeremony.VERIFICATION,
) {
  return {
    ceremony,
    ref,
    sendTo: '+963991111111',
    smsBody: ceremony === ReverseCeremony.BINDING ? 'BIND ABCD' : 'VERIFY 763PM5',
    expiresAt: new Date(Date.now() + 10 * 60_000),
  };
}

function service(reverse: StubReverse | null) {
  const config = new ConfigService({
    security: { otpPepper: 'test-pepper-for-reverse-otp-specs-00000' },
    otpDelivery: { testAccounts: '', testAccountsUntil: '' },
  });
  const cipher = new OtpCipherService(
    new ConfigService({ security: { otpDeliveryKey: 'k'.repeat(40) } }),
  );
  return new OtpService(
    db,
    new OtpDispatcherService(db, cipher),
    config,
    reverse as unknown as ReverseSmsService,
  );
}

/** Narrows a challenge response to the reverse rail, failing if it is not. */
function reverse<T extends { delivery_mode: string }>(response: T) {
  assert.equal(response.delivery_mode, 'reverse_sms');
  return response as Extract<T, { delivery_mode: 'reverse_sms' }>;
}

async function row(destination: string) {
  return prisma.otpRequest.findFirst({
    where: { destination },
    orderBy: { createdAt: 'desc' },
    include: { outbox: true },
  });
}

test('a reverse challenge is recorded with the provider reference and queues nothing', async (t) => {
  if (!reachable) return t.skip('no database reachable');
  const number = phone('records');
  const stub = new StubReverse(challenge('vrf_records'));

  const response = reverse(
    await service(stub).request({ phone: number, purpose: OtpPurpose.LOGIN }),
  );

  assert.equal(response.send_to, '+963991111111');
  assert.equal(response.sms_body, 'VERIFY 763PM5');
  // No two digits to compare: on this rail the direction of travel is the
  // defence that `match_code` was standing in for.
  assert.equal(response.match_code, null);

  const stored = await row(number);
  assert.equal(stored?.deliveryMode, OtpDeliveryMode.REVERSE_SMS);
  assert.equal(stored?.reverseRef, 'vrf_records');
  assert.equal(stored?.reverseCeremony, ReverseCeremony.VERIFICATION);
  assert.equal(stored?.reverseSendTo, '+963991111111');
  // Nothing to deliver, so nothing is queued — the outbox is for outbound.
  assert.equal(stored?.outbox, null);
});

test('no typed code can settle a reverse challenge', async (t) => {
  if (!reachable) return t.skip('no database reachable');
  const number = phone('no-code');
  const stub = new StubReverse(challenge('vrf_nocode'), 'verified');
  const otp = service(stub);
  await otp.request({ phone: number, purpose: OtpPurpose.LOGIN });

  // Even with the provider saying verified, the code path must not be a way
  // in: it has no code to match and must not improvise one.
  for (const guess of ['000000', '763PM5', '123456']) {
    await assert.rejects(
      otp.verify(number, OtpPurpose.LOGIN, guess),
      (error: { response?: { code?: string } }) =>
        error.response?.code === 'INVALID_OTP',
    );
  }

  const stored = await row(number);
  assert.equal(stored?.status, OtpStatus.PENDING);
});

test('a ceremony she has not completed is pending, and costs her no attempt', async (t) => {
  if (!reachable) return t.skip('no database reachable');
  const number = phone('pending');
  const stub = new StubReverse(challenge('vrf_pending'), 'pending');
  const otp = service(stub);
  await otp.request({ phone: number, purpose: OtpPurpose.LOGIN });

  await assert.rejects(
    otp.consumeReverse(number, OtpPurpose.LOGIN),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'OTP_PENDING',
  );

  assert.deepEqual(await otp.reverseStatus(number, OtpPurpose.LOGIN), {
    status: 'pending',
  });
  // Waiting is the ordinary state of a ceremony in flight; counting it would
  // lock her out for being slow to open her messaging app.
  assert.equal((await row(number))?.attempts, 0);
});

test('the provider saying verified settles it, exactly once', async (t) => {
  if (!reachable) return t.skip('no database reachable');
  const number = phone('once');
  const stub = new StubReverse(challenge('vrf_once'), 'pending');
  const otp = service(stub);
  await otp.request({ phone: number, purpose: OtpPurpose.LOGIN });

  stub.says('verified');
  assert.deepEqual(await otp.reverseStatus(number, OtpPurpose.LOGIN), {
    status: 'verified',
  });
  assert.deepEqual(await otp.consumeReverse(number, OtpPurpose.LOGIN), {
    verified: true,
  });

  const stored = await row(number);
  assert.equal(stored?.status, OtpStatus.VERIFIED);
  assert.ok(stored?.verifiedAt);

  // The provider still says verified. The challenge is spent anyway: a
  // verified ceremony is not a standing permission to mint sessions.
  await assert.rejects(
    otp.consumeReverse(number, OtpPurpose.LOGIN),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'INVALID_OTP',
  );
});

test('an expired or cancelled ceremony expires the challenge', async (t) => {
  if (!reachable) return t.skip('no database reachable');
  const number = phone('unusable');
  const stub = new StubReverse(challenge('vrf_unusable'), 'unusable');
  const otp = service(stub);
  await otp.request({ phone: number, purpose: OtpPurpose.LOGIN });

  await assert.rejects(
    otp.consumeReverse(number, OtpPurpose.LOGIN),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'OTP_EXPIRED',
  );
  assert.equal((await row(number))?.status, OtpStatus.EXPIRED);
});

test('the nonce is demanded on this rail too', async (t) => {
  if (!reachable) return t.skip('no database reachable');
  const number = phone('nonce');
  const stub = new StubReverse(challenge('vrf_nonce'), 'verified');
  const otp = service(stub);
  await otp.request({
    phone: number,
    purpose: OtpPurpose.LOGIN,
    clientNonce: 'the-install-that-asked',
  });

  // A verified ceremony presented by an install that cannot produce the nonce
  // is the relay attack, and it is refused and counted.
  await assert.rejects(
    otp.consumeReverse(number, OtpPurpose.LOGIN, 'some-other-install'),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'INVALID_OTP',
  );
  assert.equal((await row(number))?.attempts, 1);

  // The poll stays quiet rather than counting, for the same reason as above.
  assert.deepEqual(
    await otp.reverseStatus(number, OtpPurpose.LOGIN, 'some-other-install'),
    { status: 'pending' },
  );
  assert.equal((await row(number))?.attempts, 1);

  assert.deepEqual(
    await otp.consumeReverse(
      number,
      OtpPurpose.LOGIN,
      'the-install-that-asked',
    ),
    { verified: true },
  );
});

test('a binding ceremony proves the number as well as a verification does', async (t) => {
  if (!reachable) return t.skip('no database reachable');
  const number = phone('binding');
  const stub = new StubReverse(
    challenge('pbn_binding', ReverseCeremony.BINDING),
    'verified',
  );
  const otp = service(stub);

  const response = reverse(
    await otp.request({
      phone: number,
      purpose: OtpPurpose.PHONE_VERIFICATION,
    }),
  );
  assert.equal(response.ceremony, 'binding');
  assert.equal(response.sms_body, 'BIND ABCD');

  const user = await prisma.user.create({
    data: {
      name: 'Reverse OTP Spec',
      phone: number,
      username: `reverse_otp_${number.slice(-8)}`,
      role: UserRole.CUSTOMER,
    },
  });
  created.push(user.id);

  // `verifyAny`, so the purpose's side effect applies on this rail exactly as
  // it does on the other one.
  await otp.verifyAny(number, OtpPurpose.PHONE_VERIFICATION);
  const refreshed = await prisma.user.findUnique({ where: { id: user.id } });
  assert.equal(refreshed?.isVerified, true);
  assert.ok(refreshed?.phoneVerifiedAt);
});

test('a provider that cannot open a ceremony falls back to the old rail', async (t) => {
  if (!reachable) return t.skip('no database reachable');
  const number = phone('fallback');
  const stub = new StubReverse(null);
  const otp = service(stub);

  const response = await otp.request({ phone: number, purpose: OtpPurpose.LOGIN });

  // She gets a code and a queued delivery, not an error: an outage on the
  // primary rail is a slower sign-in, never a refused one.
  assert.equal(response.delivery_mode, 'code_to_handset');
  assert.ok(response.match_code);
  const stored = await row(number);
  assert.equal(stored?.deliveryMode, OtpDeliveryMode.CODE_TO_HANDSET);
  assert.equal(stored?.reverseRef, null);
  assert.ok(stored?.outbox, 'the classic rail queues a delivery');
  assert.equal(stub.started.length, 1, 'the reverse rail was tried first');
});

test('with no reverse rail at all, nothing about the old one changes', async (t) => {
  if (!reachable) return t.skip('no database reachable');
  const number = phone('classic');
  const response = await service(null).request({
    phone: number,
    purpose: OtpPurpose.LOGIN,
  });

  assert.ok(response.match_code);
  const stored = await row(number);
  assert.equal(stored?.deliveryMode, OtpDeliveryMode.CODE_TO_HANDSET);
  assert.ok(stored?.outbox);
});
