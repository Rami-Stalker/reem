import assert from 'node:assert/strict';
import test from 'node:test';
import * as bcrypt from 'bcryptjs';
import { PasswordService } from './password.service';

test('password service hashes new passwords with argon2id', async () => {
  const service = new PasswordService();

  const hash = await service.hash('Stronger#123');

  assert.equal(hash.startsWith('$argon2id$'), true);
  assert.equal(await service.verify('Stronger#123', hash), true);
  assert.equal(await service.verify('wrong-password', hash), false);
  assert.equal(service.needsRehash(hash), false);
});

test('password service verifies legacy bcrypt hashes for migration', async () => {
  const service = new PasswordService();
  const legacyHash = await bcrypt.hash('Legacy#123', 10);

  assert.equal(await service.verify('Legacy#123', legacyHash), true);
  assert.equal(service.needsRehash(legacyHash), true);
});
