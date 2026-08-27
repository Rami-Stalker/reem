import assert from 'node:assert/strict';
import test from 'node:test';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../../prisma/prisma.service';
import { TotpService } from './totp.service';

const service = new TotpService({} as unknown as PrismaService, {
  get: () => 'a-test-totp-encryption-key-long-enough',
} as unknown as ConfigService);

/**
 * RFC 6238 Appendix B, SHA-1 vectors. The secret there is the ASCII string
 * `12345678901234567890`; here it is base32-encoded because that is the form
 * an authenticator app is given.
 */
const RFC_SECRET = service.base32Encode(
  Buffer.from('12345678901234567890', 'ascii'),
);

test('matches the RFC 6238 SHA-1 test vectors', () => {
  const vectors: [number, string][] = [
    [59, '287082'],
    [1111111109, '081804'],
    [1111111111, '050471'],
    [1234567890, '005924'],
    [2000000000, '279037'],
  ];

  for (const [seconds, expected] of vectors) {
    const counter = Math.floor(seconds / 30);
    assert.equal(
      service.codeFor(RFC_SECRET, counter),
      expected,
      `t=${seconds}`,
    );
  }
});

test('base32 round-trips', () => {
  const raw = Buffer.from('12345678901234567890', 'ascii');
  assert.deepEqual(service.base32Decode(service.base32Encode(raw)), raw);
});

test('rejects base32 that is not base32', () => {
  assert.throws(() => service.base32Decode('nope!!'), /Invalid base32/);
});

test('consecutive steps produce different codes', () => {
  const counter = Math.floor(Date.now() / 1000 / 30);
  assert.notEqual(
    service.codeFor(RFC_SECRET, counter),
    service.codeFor(RFC_SECRET, counter + 1),
  );
});

test('every code is six digits, including leading zeros', () => {
  for (let counter = 0; counter < 500; counter += 1) {
    const code = service.codeFor(RFC_SECRET, counter);
    assert.match(code, /^\d{6}$/, `counter ${counter} produced "${code}"`);
  }
});
