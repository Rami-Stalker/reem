import assert from 'node:assert/strict';
import test from 'node:test';
import { ConfigService } from '@nestjs/config';
import { OtpCipherService } from './otp-cipher.service';

const cipher = new OtpCipherService({
  get: () => 'a-test-delivery-key-that-is-long-enough-32',
} as unknown as ConfigService);

test('a sealed code opens back to the same digits', () => {
  const sealed = cipher.seal('123456');
  assert.notEqual(sealed, '123456');
  assert.equal(cipher.open(sealed), '123456');
});

test('sealing the same code twice produces different ciphertext', () => {
  // Otherwise two rows holding the same code would be visibly identical, and
  // the outbox would leak which challenges share a code.
  assert.notEqual(cipher.seal('123456'), cipher.seal('123456'));
});

test('tampered or malformed ciphertext opens to null, never to a wrong code', () => {
  const sealed = cipher.seal('123456');
  const [iv, body, tag] = sealed.split('.');
  assert.equal(cipher.open(`${iv}.${body}.${tag.slice(0, -2)}AA`), null);
  assert.equal(cipher.open('not-sealed'), null);
  assert.equal(cipher.open(null), null);
});

test('a different key cannot open the seal', () => {
  const other = new OtpCipherService({
    get: () => 'a-different-delivery-key-also-long-enough',
  } as unknown as ConfigService);
  assert.equal(other.open(cipher.seal('123456')), null);
});
