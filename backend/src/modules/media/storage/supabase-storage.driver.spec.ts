import assert from 'node:assert/strict';
import test from 'node:test';
import { NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MediaVisibility } from '@prisma/client';

import { SupabaseStorageDriver } from './supabase-storage.driver';

/**
 * The Storage driver is the only code holding the project's secret key, and
 * the only thing standing between a private upload — an identity document, a
 * chat photograph — and the public bucket. These cases pin the three things
 * that must not drift: which bucket a visibility lands in, that the key goes
 * to Supabase and nowhere else, and that a key outside the generated shape
 * never reaches a request at all.
 */

const KEY = '2026/09/0f8b6c1a-2d3e-4f50-8a9b-1c2d3e4f5061.jpg';

type Call = { url: string; init: RequestInit };

function driverWith(respond: (call: Call) => Response) {
  const calls: Call[] = [];
  const original = globalThis.fetch;
  globalThis.fetch = (async (url: string, init: RequestInit) => {
    const call = { url: String(url), init };
    calls.push(call);
    return respond(call);
  }) as typeof fetch;
  const driver = new SupabaseStorageDriver(
    new ConfigService({
      supabase: {
        url: 'https://ref.supabase.co/',
        secretKey: 'sb_secret_test',
        publicBucket: 'reem-media-public',
        privateBucket: 'reem-media-private',
      },
      media: { publicBaseUrl: '/storage/v1/object/public/reem-media-public' },
    }),
  );
  return { driver, calls, restore: () => (globalThis.fetch = original) };
}

test('visibility chooses the bucket, and the secret key travels only to the project', async () => {
  const { driver, calls, restore } = driverWith(() => new Response('{}', { status: 200 }));
  try {
    await driver.put(KEY, Buffer.from('bytes'), MediaVisibility.PRIVATE);
    await driver.put(KEY, Buffer.from('bytes'), MediaVisibility.PUBLIC);
  } finally {
    restore();
  }
  assert.equal(calls[0].url, `https://ref.supabase.co/storage/v1/object/reem-media-private/${KEY}`);
  assert.equal(calls[1].url, `https://ref.supabase.co/storage/v1/object/reem-media-public/${KEY}`);
  const headers = calls[0].init.headers as Record<string, string>;
  assert.equal(headers.Authorization, 'Bearer sb_secret_test');
  assert.equal(headers['x-upsert'], 'false');
  assert.equal(headers['Content-Type'], 'image/jpeg');
});

test('public URLs are absolute CDN URLs, so MediaService does not prefix its own origin', () => {
  const { driver, restore } = driverWith(() => new Response(null, { status: 500 }));
  restore();
  assert.equal(
    driver.publicUrl(KEY),
    `https://ref.supabase.co/storage/v1/object/public/reem-media-public/${KEY}`,
  );
});

test('an absent object reads as 404, a failing Storage as 503 without its body', async () => {
  const missing = driverWith(() => new Response('not found', { status: 400 }));
  await assert.rejects(missing.driver.read(KEY, MediaVisibility.PRIVATE), NotFoundException);
  missing.restore();

  const failing = driverWith(() => new Response('bucket reem-media-private: boom', { status: 500 }));
  await assert.rejects(failing.driver.read(KEY, MediaVisibility.PRIVATE), (error: unknown) => {
    assert.ok(error instanceof ServiceUnavailableException);
    assert.doesNotMatch(String((error as Error).message), /reem-media-private/);
    return true;
  });
  failing.restore();
});

test('a key outside the generated shape never becomes a request', async () => {
  const { driver, calls, restore } = driverWith(() => new Response('{}', { status: 200 }));
  try {
    await assert.rejects(
      driver.read('../reem-media-private/2026/09/x.jpg', MediaVisibility.PUBLIC),
      /outside the generated shape/,
    );
    assert.throws(() => driver.publicUrl('2026/09/evil.svg?x'), /outside the generated shape/);
  } finally {
    restore();
  }
  assert.equal(calls.length, 0);
});
