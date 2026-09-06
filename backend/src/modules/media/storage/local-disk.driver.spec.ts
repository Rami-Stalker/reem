import assert from 'node:assert/strict';
import test from 'node:test';
import { ConfigService } from '@nestjs/config';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { LocalDiskDriver } from './local-disk.driver';

/**
 * The variant fallback used to be a few lines of `join()` in `main.ts`, and it
 * was the one way into the private bucket that never met an authorisation
 * check. Express neither decodes nor normalises `req.path`, so a client that
 * declines to tidy its own URL — `curl --path-as-is` will do — could ask for
 * `../private/<uuid>@480.webp` and have `join()` collapse it into the sibling
 * directory that holds identity documents and closet photographs.
 *
 * These cases are about that collapse. They are cheap; the thing they prevent
 * is not.
 */

const UUID = '0f8b6c1a-2d3e-4f50-8a9b-1c2d3e4f5061';

function driverOn(root: string): LocalDiskDriver {
  return new LocalDiskDriver(
    new ConfigService({
      media: { localRoot: root, publicBaseUrl: '/media/files' },
    }),
  );
}

/** A root with one real public image and one real private one. */
function seedRoot(): { root: string; publicKey: string } {
  const root = mkdtempSync(join(tmpdir(), 'reem-media-'));
  for (const bucket of ['public', 'private']) {
    mkdirSync(join(root, bucket, '2026', '08'), { recursive: true });
    writeFileSync(join(root, bucket, '2026', '08', `${UUID}.jpg`), 'bytes');
  }
  return { root, publicKey: `/2026/08/${UUID}@480.webp` };
}

test('serves the original when a resized variant was never generated', () => {
  const { root, publicKey } = seedRoot();
  const resolved = driverOn(root).resolvePublicVariantFallback(publicKey);

  assert.equal(resolved, join(root, 'public', '2026', '08', `${UUID}.jpg`));
});

test('refuses to climb out of the public bucket into private media', () => {
  const { root } = seedRoot();

  // The file genuinely exists — only the containment check stands between the
  // caller and a seller's identity document.
  assert.equal(
    driverOn(root).resolvePublicVariantFallback(
      `/../private/2026/08/${UUID}@480.webp`,
    ),
    null,
  );
});

test('refuses a traversal that dresses itself up as a nested path', () => {
  const { root } = seedRoot();

  assert.equal(
    driverOn(root).resolvePublicVariantFallback(
      `/2026/08/../../../private/2026/08/${UUID}@480.webp`,
    ),
    null,
  );
});

test('ignores requests that are not asking for a variant at all', () => {
  const { root, publicKey } = seedRoot();
  const driver = driverOn(root);

  // No `@width` suffix — the static mount already answered, or nothing will.
  assert.equal(
    driver.resolvePublicVariantFallback(`/2026/08/${UUID}.jpg`),
    null,
  );
  // And a variant of something that does not exist stays a miss.
  assert.equal(
    driver.resolvePublicVariantFallback(publicKey.replace(UUID, 'nope')),
    null,
  );
});

test('refuses keys this platform would never have generated', () => {
  const { root } = seedRoot();
  const driver = driverOn(root);

  for (const path of [
    '/etc/passwd@480.webp',
    '/2026/08/not-a-uuid@480.webp',
    '/2026/8/' + UUID + '@480.webp',
  ]) {
    assert.equal(driver.resolvePublicVariantFallback(path), null, path);
  }
});
