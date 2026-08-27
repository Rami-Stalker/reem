import assert from 'node:assert/strict';
import test from 'node:test';
import { generateKeyPairSync, createHash, sign, randomUUID } from 'crypto';
import { DeviceKey } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { DeviceProofService } from './device-proof.service';

/**
 * The proof verifier is now the single most valuable thing for an attacker to
 * probe, so the tests that matter are the ones that must FAIL: wrong key,
 * wrong URL, stale clock, replayed jti, truncated signature, forged algorithm.
 * A verifier with only a happy-path test is a verifier nobody has checked.
 */

function makeKeyPair() {
  const { publicKey, privateKey } = generateKeyPairSync('ed25519');
  const raw = publicKey
    .export({ format: 'der', type: 'spki' })
    .subarray(12)
    .toString('base64url');
  return { privateKey, publicKeyBase64Url: raw };
}

const keyPair = makeKeyPair();
const other = makeKeyPair();

const deviceKey = {
  id: '11111111-1111-4111-8111-111111111111',
  publicKey: keyPair.publicKeyBase64Url,
  revokedAt: null,
} as unknown as DeviceKey;

/** In-memory stand-in: the unique (deviceKeyId, jti) constraint is the point. */
function makePrisma(overrides: { deviceKey?: DeviceKey | null } = {}) {
  const seen = new Set<string>();
  return {
    deviceKey: {
      findUnique: async () =>
        overrides.deviceKey === undefined ? deviceKey : overrides.deviceKey,
      update: async () => deviceKey,
    },
    deviceProofJti: {
      create: async ({ data }: { data: { deviceKeyId: string; jti: string } }) => {
        const composite = `${data.deviceKeyId}:${data.jti}`;
        if (seen.has(composite)) throw new Error('unique violation');
        seen.add(composite);
        return data;
      },
    },
  } as unknown as PrismaService;
}

function buildProof(options: {
  privateKey?: ReturnType<typeof makeKeyPair>['privateKey'];
  kid?: string;
  jti?: string;
  iat?: number;
  htm?: string;
  htu?: string;
  ath?: string;
  alg?: string;
  truncateSignature?: boolean;
}) {
  const header = { alg: options.alg ?? 'EdDSA', kid: options.kid ?? deviceKey.id };
  const payload = {
    jti: options.jti ?? randomUUID(),
    iat: options.iat ?? Math.floor(Date.now() / 1000),
    htm: options.htm ?? 'POST',
    htu: options.htu ?? 'https://api.reem.sy/auth/refresh-token',
    ...(options.ath ? { ath: options.ath } : {}),
  };
  const encode = (value: object) =>
    Buffer.from(JSON.stringify(value)).toString('base64url');
  const signingInput = `${encode(header)}.${encode(payload)}`;
  let signature = sign(
    null,
    Buffer.from(signingInput),
    options.privateKey ?? keyPair.privateKey,
  );
  if (options.truncateSignature) signature = signature.subarray(0, 40);
  return `${signingInput}.${signature.toString('base64url')}`;
}

const context = {
  method: 'POST',
  url: 'https://api.reem.sy/auth/refresh-token',
};

test('a well-formed proof from the registered key is accepted', async () => {
  const service = new DeviceProofService(makePrisma());
  const result = await service.verify(buildProof({}), context);
  assert.equal(result.ok, true);
});

test('a proof signed by a different key is rejected', async () => {
  const service = new DeviceProofService(makePrisma());
  const result = await service.verify(
    buildProof({ privateKey: other.privateKey }),
    context,
  );
  assert.deepEqual(result, { ok: false, reason: 'bad_signature' });
});

test('a proof for another URL cannot be replayed here', async () => {
  const service = new DeviceProofService(makePrisma());
  const result = await service.verify(
    buildProof({ htu: 'https://api.reem.sy/auth/logout' }),
    context,
  );
  assert.deepEqual(result, { ok: false, reason: 'wrong_request' });
});

test('a proof for another method cannot be replayed here', async () => {
  const service = new DeviceProofService(makePrisma());
  const result = await service.verify(buildProof({ htm: 'GET' }), context);
  assert.deepEqual(result, { ok: false, reason: 'wrong_request' });
});

test('a stale proof is rejected on both sides of the window', async () => {
  const service = new DeviceProofService(makePrisma());
  const past = Math.floor(Date.now() / 1000) - 120;
  const future = Math.floor(Date.now() / 1000) + 120;
  assert.deepEqual(await service.verify(buildProof({ iat: past }), context), {
    ok: false,
    reason: 'stale',
  });
  assert.deepEqual(await service.verify(buildProof({ iat: future }), context), {
    ok: false,
    reason: 'stale',
  });
});

test('the same jti cannot be used twice', async () => {
  const service = new DeviceProofService(makePrisma());
  const proof = buildProof({ jti: 'fixed-jti' });
  assert.equal((await service.verify(proof, context)).ok, true);
  assert.deepEqual(await service.verify(proof, context), {
    ok: false,
    reason: 'replayed',
  });
});

test('a truncated signature is rejected', async () => {
  const service = new DeviceProofService(makePrisma());
  const result = await service.verify(
    buildProof({ truncateSignature: true }),
    context,
  );
  assert.deepEqual(result, { ok: false, reason: 'bad_signature' });
});

test('a forged algorithm never reaches the payload', async () => {
  const service = new DeviceProofService(makePrisma());
  for (const alg of ['none', 'HS256', 'RS256']) {
    assert.deepEqual(await service.verify(buildProof({ alg }), context), {
      ok: false,
      reason: 'malformed',
    });
  }
});

test('an unknown or revoked key is rejected before any signature work', async () => {
  const unknown = new DeviceProofService(makePrisma({ deviceKey: null }));
  assert.deepEqual(await unknown.verify(buildProof({}), context), {
    ok: false,
    reason: 'unknown_key',
  });

  const revoked = new DeviceProofService(
    makePrisma({ deviceKey: { ...deviceKey, revokedAt: new Date() } }),
  );
  assert.deepEqual(await revoked.verify(buildProof({}), context), {
    ok: false,
    reason: 'revoked_key',
  });
});

test('a proof bound to a different access token is rejected', async () => {
  const service = new DeviceProofService(makePrisma());
  const ath = createHash('sha256').update('the-real-token').digest('base64url');
  const result = await service.verify(buildProof({ ath }), {
    ...context,
    accessToken: 'a-stolen-token',
  });
  assert.deepEqual(result, { ok: false, reason: 'wrong_token' });
});

test('a proof with the matching access-token digest is accepted', async () => {
  const service = new DeviceProofService(makePrisma());
  const token = 'the-real-token';
  const ath = createHash('sha256').update(token).digest('base64url');
  const result = await service.verify(buildProof({ ath }), {
    ...context,
    accessToken: token,
  });
  assert.equal(result.ok, true);
});

test('garbage is rejected without throwing', async () => {
  const service = new DeviceProofService(makePrisma());
  for (const junk of ['', 'a.b', 'a.b.c.d', 'not-base64.$$$.xx']) {
    assert.deepEqual(await service.verify(junk, context), {
      ok: false,
      reason: 'malformed',
    });
  }
});
