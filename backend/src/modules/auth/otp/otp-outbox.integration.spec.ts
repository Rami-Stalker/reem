import assert from 'node:assert/strict';
import test from 'node:test';
import { OtpChannel, OtpOutboxStatus, OtpPurpose, OtpStatus, PrismaClient } from '@prisma/client';

import { PrismaService } from '../../../prisma/prisma.service';
import { DeliveryOrchestrator } from './delivery.orchestrator';
import { OtpCipherService } from './otp-cipher.service';
import { OtpDispatcherService } from './otp-dispatcher.service';
import { OtpOutboxCron } from './otp-outbox.cron';

/**
 * `retireExpired` against real Postgres.
 *
 * It used to select every expired PENDING challenge that *had* an outbox row —
 * including the ones it had already retired, because retiring ends the outbox
 * row and leaves the challenge PENDING. So it retired the same challenges every
 * minute for ever, and once 200 had accumulated (its batch size) no newer
 * code's sealed plaintext was ever shredded. These cases pin the fix: a
 * challenge is retired once, and an already-retired one is never picked again.
 */
const prisma = new PrismaClient();
const tag = `+9639${String(Date.now()).slice(-8)}`;

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
    await prisma.otpRequest.deleteMany({ where: { destination: { startsWith: tag } } });
  }
  await prisma.$disconnect();
});

async function expiredChallenge(suffix: string, outbox: { status: OtpOutboxStatus; sealed: string | null }) {
  const challenge = await prisma.otpRequest.create({
    data: {
      destination: `${tag}${suffix}`,
      channel: OtpChannel.WHATSAPP,
      purpose: OtpPurpose.LOGIN,
      codeHash: 'spec',
      status: OtpStatus.PENDING,
      expiresAt: new Date(Date.now() - 60_000),
    },
  });
  await prisma.otpOutbox.create({
    data: { challengeId: challenge.id, status: outbox.status, sealedCode: outbox.sealed },
  });
  return challenge.id;
}

test('an expired code is retired once, and a retired one is never picked again', async (t) => {
  if (!reachable) {
    t.skip('no database reachable');
    return;
  }
  const live = await expiredChallenge('1', { status: OtpOutboxStatus.PENDING, sealed: 'sealed' });
  const alreadyRetired = await expiredChallenge('2', {
    status: OtpOutboxStatus.CANCELLED,
    sealed: null,
  });

  const db = prisma as unknown as PrismaService;
  const dispatcher = new OtpDispatcherService(db, {} as OtpCipherService);
  const shredded: string[] = [];
  const shred = dispatcher.shred.bind(dispatcher);
  dispatcher.shred = async (id, status) => {
    shredded.push(id);
    await shred(id, status);
  };
  const cron = new OtpOutboxCron(db, {} as DeliveryOrchestrator, {} as OtpCipherService, dispatcher);

  await cron.retireExpired();
  assert.ok(shredded.includes(live), 'the live expired code is retired');
  assert.ok(!shredded.includes(alreadyRetired), 'a retired code is not picked');

  const row = await prisma.otpOutbox.findUnique({ where: { challengeId: live } });
  assert.equal(row?.sealedCode, null);
  assert.equal(row?.status, OtpOutboxStatus.CANCELLED);

  shredded.length = 0;
  await cron.retireExpired();
  assert.ok(!shredded.includes(live), 'retired on the first pass, not again on the second');
});
