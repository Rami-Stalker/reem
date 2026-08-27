import assert from 'node:assert/strict';
import { promises as fs } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { LocalDiskDriver } from './local-disk.driver';

const MEDIA_ROOT = join(tmpdir(), 'reem-media-driver-spec');

const driver = () =>
  new LocalDiskDriver({
    get: (key: string) =>
      ({
        'media.localRoot': MEDIA_ROOT,
        'media.publicBaseUrl': '/media/files',
      })[key],
  } as never);

const PUBLIC = 'PUBLIC' as never;
const PRIVATE = 'PRIVATE' as never;
const KEY = '2026/08/3f4a9c1e-1b2d-4e5f-8a90-abcdef012345.jpg';

test.after(() => fs.rm(MEDIA_ROOT, { recursive: true, force: true }));

test('public and private assets land in separate roots', async () => {
  const local = driver();
  await local.put(KEY, Buffer.from('public bytes'), PUBLIC);
  await local.put(KEY, Buffer.from('private bytes'), PRIVATE);

  // The same key in both trees, holding different bytes. That is the invariant
  // the reverse proxy relies on: it serves `public/` and can reach nothing else.
  assert.equal(
    (await fs.readFile(join(MEDIA_ROOT, 'public', KEY))).toString(),
    'public bytes',
  );
  assert.equal(
    (await fs.readFile(join(MEDIA_ROOT, 'private', KEY))).toString(),
    'private bytes',
  );
  assert.equal(local.publicRoot, join(MEDIA_ROOT, 'public'));
});

test('a key is never overwritten', async () => {
  const local = driver();
  const key = '2026/08/11111111-2222-3333-4444-555555555555.png';
  await local.put(key, Buffer.from('first'), PUBLIC);

  // Keys are random, so a collision means something upstream is broken.
  // Silently replacing another woman's photograph is the worst way to learn it.
  await assert.rejects(local.put(key, Buffer.from('second'), PUBLIC));
  assert.equal((await local.read(key, PUBLIC)).toString(), 'first');
});

test('traversal in a key is refused rather than resolved', async () => {
  const local = driver();
  for (const key of [
    '../../../etc/passwd',
    '2026/08/../../../secrets.env',
    '2026/08/%2e%2e%2fsecrets.jpg',
    '/etc/passwd',
    '2026/08/id.jpg/../../../root.jpg',
  ]) {
    await assert.rejects(
      local.put(key, Buffer.from('x'), PUBLIC),
      /Unsafe media storage key/,
      `expected refusal for ${key}`,
    );
  }
});

test('a key that is not the shape this platform generates is refused', async () => {
  const local = driver();
  // An allow-list, not a `..` blocklist — an allow-list cannot be talked around
  // by an encoding trick nobody thought of.
  await assert.rejects(
    local.put('shell.php', Buffer.from('x'), PUBLIC),
    /Unsafe media storage key/,
  );
  assert.throws(() => local.publicUrl('../../evil'), /Unsafe media storage key/);
});

test('reading bytes that are gone is a 404, not a crash', async () => {
  const local = driver();
  await assert.rejects(
    local.read('2026/01/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg', PUBLIC),
    /MEDIA_BYTES_MISSING/,
  );
});

test('removing an absent key is not an error', async () => {
  const local = driver();
  await local.remove('2026/01/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg', PUBLIC);
});

test('the public URL is the base path plus the key', async () => {
  assert.equal(driver().publicUrl(KEY), `/media/files/${KEY}`);
});
