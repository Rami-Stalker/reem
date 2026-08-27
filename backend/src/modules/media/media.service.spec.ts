import assert from 'node:assert/strict';
import test from 'node:test';
import { ImageDerivativesService } from './image-derivatives';
import { MediaService } from './media.service';

// ── Fixtures ────────────────────────────────────────────────────────────────

function png(width = 10, height = 10): Buffer {
  const buffer = Buffer.alloc(24);
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(buffer, 0);
  buffer.writeUInt32BE(13, 8);
  buffer.write('IHDR', 12, 'latin1');
  buffer.writeUInt32BE(width, 16);
  buffer.writeUInt32BE(height, 20);
  return buffer;
}

const DEFAULTS: Record<string, unknown> = {
  'media.maxImageBytes': 12_582_912,
  'media.maxVideoBytes': 67_108_864,
  'media.maxDocumentBytes': 16_777_216,
  'media.maxAudioBytes': 25_165_824,
  'media.dailyUploadsPerUser': 300,
  'media.orphanTtlHours': 24,
  'media.publicBaseUrl': '/media/files',
  'media.publicOrigin': '',
};

const config = (overrides: Record<string, unknown> = {}) => ({
  get: (key: string) => ({ ...DEFAULTS, ...overrides })[key],
});

function storage() {
  const written = new Map<string, Buffer>();
  const removed: string[] = [];
  return {
    written,
    removed,
    name: 'local',
    put: async (key: string, bytes: Buffer) => {
      written.set(key, bytes);
    },
    read: async (key: string) => written.get(key) ?? Buffer.alloc(0),
    remove: async (key: string) => {
      removed.push(key);
      written.delete(key);
    },
    publicUrl: (key: string) => `/media/files/${key}`,
  };
}

/** Only the calls the service makes; each test overrides what it cares about. */
function prisma(overrides: Record<string, unknown> = {}) {
  return {
    messageAttachment: {
      count: async () => 0,
      ...((overrides.messageAttachment as object) ?? {}),
    },
    mediaAsset: {
      findFirst: async () => null,
      findUnique: async () => null,
      findMany: async () => [],
      count: async () => 0,
      create: async ({ data }: { data: Record<string, unknown> }) => ({
        id: 'asset-1',
        ...data,
      }),
      updateMany: async () => ({ count: 0 }),
      delete: async () => ({}),
      ...(overrides.mediaAsset ?? {}),
    },
    /// The RBAC tables `resolvePermissions` reads. No rows by default, which
    /// is the unseeded case: the code-level defaults for the role stand in.
    role: {
      findUnique: async () => null,
      ...((overrides.role as object) ?? {}),
    },
    userRoleAssignment: {
      findMany: async () => [],
      ...((overrides.userRoleAssignment as object) ?? {}),
    },
  };
}

/// An RBAC table that grants exactly these keys to the role being asked about.
const grants = (...keys: string[]) => ({
  role: {
    findUnique: async () => ({
      permissions: keys.map((key) => ({ permission: { key } })),
    }),
  },
  userRoleAssignment: { findMany: async () => [] },
});

/// Real derivatives, not a stub: `sharp` runs happily in a unit test, and a
/// fake would be asserting that the fake was called rather than that a
/// thumbnail exists.
const build = (p: unknown, c: unknown, s: unknown) =>
  new MediaService(
    p as never,
    c as never,
    s as never,
    new ImageDerivativesService(),
  );

// ── Validation ──────────────────────────────────────────────────────────────

test('a file whose bytes are not a supported medium is refused', async () => {
  const store = storage();
  const service = build(prisma(), config(), store);

  await assert.rejects(
    service.upload('user-1', {
      buffer: Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"/>'),
      visibility: 'PUBLIC' as never,
    }),
    /UNSUPPORTED_MEDIA_TYPE/,
  );
  // Nothing reached the disk: the type decision happens before the write.
  assert.equal(store.written.size, 0);
});

test('an empty upload is refused before anything is sniffed', async () => {
  const service = build(prisma(), config(), storage());
  await assert.rejects(
    service.upload('user-1', {
      buffer: Buffer.alloc(0),
      visibility: 'PUBLIC' as never,
    }),
    /EMPTY_UPLOAD/,
  );
});

test('an image is held to the image ceiling, not the video one', async () => {
  // The whole point of sniffing first. Multer admits anything under the video
  // limit, so an oversized image must be caught here or not at all.
  const service = build(
    prisma(),
    config({ 'media.maxImageBytes': 100 }),
    storage(),
  );

  await assert.rejects(
    service.upload('user-1', {
      buffer: Buffer.concat([png(), Buffer.alloc(200)]),
      visibility: 'PUBLIC' as never,
    }),
    /MEDIA_TOO_LARGE/,
  );
});

const pdf = () => Buffer.from('%PDF-1.7\n%\xe2\xe3\xcf\xd3\n1 0 obj\n', 'latin1');

test('a PDF is refused where a photograph was expected', async () => {
  // The seller gallery, the story composer, the avatar. A PDF here renders as
  // a broken tile on every card that shows the product.
  const store = storage();
  const service = build(prisma(), config(), store);

  await assert.rejects(
    service.upload('user-1', {
      buffer: pdf(),
      visibility: 'PUBLIC' as never,
      purpose: 'product',
    }),
    /DOCUMENT_NOT_ALLOWED_HERE/,
  );
  assert.equal(store.written.size, 0);
});

test('a PDF is accepted for a document purpose', async () => {
  // A commercial register arrives as one often enough to matter, and a
  // reviewer would rather have the original than a photograph of a screen.
  const store = storage();
  const service = build(prisma(), config(), store);

  const asset = await service.upload('user-1', {
    buffer: pdf(),
    visibility: 'PRIVATE' as never,
    purpose: 'verification',
    allowedKinds: ['image', 'document'] as never,
  });

  assert.equal(asset.kind, 'document');
  assert.equal(asset.mimeType, 'application/pdf');
  assert.equal(store.written.size, 1);
  assert.ok([...store.written.keys()][0].endsWith('.pdf'));
});

test('a document is held to the document ceiling, not the video one', async () => {
  const service = build(
    prisma(),
    config({ 'media.maxDocumentBytes': 100 }),
    storage(),
  );

  await assert.rejects(
    service.upload('user-1', {
      buffer: Buffer.concat([pdf(), Buffer.alloc(400)]),
      visibility: 'PRIVATE' as never,
      purpose: 'verification',
      allowedKinds: ['image', 'document'] as never,
    }),
    /MEDIA_TOO_LARGE/,
  );
});

const m4a = () => {
  // `....ftypM4A ` — what both phone platforms write a voice note to.
  const buffer = Buffer.alloc(32);
  buffer.writeUInt32BE(32, 0);
  buffer.write('ftyp', 4, 'latin1');
  buffer.write('M4A ', 8, 'latin1');
  return buffer;
};

test('a voice note is accepted in a conversation', async () => {
  const store = storage();
  const service = build(prisma(), config(), store);

  const asset = await service.upload('user-1', {
    buffer: m4a(),
    visibility: 'PRIVATE' as never,
    purpose: 'chat',
    allowedKinds: ['image', 'audio'] as never,
  });

  assert.equal(asset.kind, 'audio');
  assert.equal(asset.mimeType, 'audio/mp4');
  assert.ok([...store.written.keys()][0].endsWith('.m4a'));
});

test('a voice note is refused where a photograph belongs', async () => {
  const store = storage();
  const service = build(prisma(), config(), store);

  await assert.rejects(
    service.upload('user-1', {
      buffer: m4a(),
      visibility: 'PUBLIC' as never,
      purpose: 'product',
      allowedKinds: ['image', 'video'] as never,
    }),
    /AUDIO_NOT_ALLOWED_HERE/,
  );
  assert.equal(store.written.size, 0);
});

test('a caller that names no kinds gets images only', async () => {
  // The safe reading of silence. A purpose added without a line in
  // `acceptedKinds` refuses everything but a photograph rather than
  // accepting whatever arrives.
  const service = build(prisma(), config(), storage());
  await assert.rejects(
    service.upload('user-1', {
      buffer: m4a(),
      visibility: 'PRIVATE' as never,
      purpose: 'chat',
    }),
    /AUDIO_NOT_ALLOWED_HERE/,
  );
});

test('audio is held to its own ceiling', async () => {
  const service = build(
    prisma(),
    config({ 'media.maxAudioBytes': 16 }),
    storage(),
  );
  await assert.rejects(
    service.upload('user-1', {
      buffer: m4a(),
      visibility: 'PRIVATE' as never,
      purpose: 'chat',
      allowedKinds: ['image', 'audio'] as never,
    }),
    /MEDIA_TOO_LARGE/,
  );
});

test('a document is accepted in a conversation', async () => {
  const store = storage();
  const service = build(prisma(), config(), store);

  const asset = await service.upload('user-1', {
    buffer: pdf(),
    visibility: 'PRIVATE' as never,
    purpose: 'chat',
    allowedKinds: ['image', 'audio', 'document'] as never,
  });

  assert.equal(asset.kind, 'document');
  assert.equal(asset.visibility, 'PRIVATE');
  // No thumbnail, no hash — there is nothing to draw.
  assert.deepEqual(asset.variants, []);
  assert.equal(asset.blurHash, null);
});

test('the daily per-account ceiling is enforced independently of the IP throttle', async () => {
  const service = build(
    prisma({ mediaAsset: { count: async () => 300 } }),
    config(),
    storage(),
  );

  await assert.rejects(
    service.upload('user-1', { buffer: png(), visibility: 'PUBLIC' as never }),
    /MEDIA_DAILY_QUOTA_EXCEEDED/,
  );
});

// ── Deduplication ───────────────────────────────────────────────────────────

test('re-uploading identical bytes returns the existing asset without writing again', async () => {
  const store = storage();
  const service = build(
    prisma({
      mediaAsset: { findFirst: async () => ({ id: 'existing', storageKey: 'k' }) },
    }),
    config(),
    store,
  );

  const asset = await service.upload('user-1', {
    buffer: png(),
    visibility: 'PUBLIC' as never,
  });

  assert.equal(asset.id, 'existing');
  assert.equal(store.written.size, 0);
});

test('deduplication is scoped by visibility as well as owner', async () => {
  // A public request must never be answered with a private asset's row — that
  // is how a national ID ends up as a product photograph's URL.
  let seenWhere: Record<string, unknown> | undefined;
  const service = build(
    prisma({
      mediaAsset: {
        findFirst: async ({ where }: { where: Record<string, unknown> }) => {
          seenWhere = where;
          return null;
        },
      },
    }),
    config(),
    storage(),
  );

  await service.upload('user-1', {
    buffer: png(),
    visibility: 'PUBLIC' as never,
  });

  assert.equal(seenWhere?.ownerId, 'user-1');
  assert.equal(seenWhere?.visibility, 'PUBLIC');
});

// ── Failure handling ────────────────────────────────────────────────────────

test('bytes are removed when the row that would point at them cannot be written', async () => {
  const store = storage();
  const service = build(
    prisma({
      mediaAsset: {
        findFirst: async () => null,
        count: async () => 0,
        create: async () => {
          throw new Error('unique constraint');
        },
      },
    }),
    config(),
    store,
  );

  await assert.rejects(
    service.upload('user-1', { buffer: png(), visibility: 'PUBLIC' as never }),
    /unique constraint/,
  );
  // The sweeper works from rows, so a file with no row is invisible to it.
  assert.equal(store.removed.length, 1);
  assert.equal(store.written.size, 0);
});

// ── Attachment ──────────────────────────────────────────────────────────────

test('an asset is claimed by the suffix of its URL, not the origin it was issued under', async () => {
  let seenWhere: Record<string, unknown> | undefined;
  const service = build(
    prisma({
      mediaAsset: {
        updateMany: async ({ where }: { where: Record<string, unknown> }) => {
          seenWhere = where;
          return { count: 1 };
        },
      },
    }),
    config(),
    storage(),
  );

  // Written from the emulator, read back from a phone on the LAN.
  const count = await service.markAttached('user-1', [
    'http://10.0.2.2:3000/media/files/2026/08/abc.jpg',
    'http://192.168.1.9:3000/media/files/2026/09/def.png?v=2',
  ]);

  assert.equal(count, 1);
  const or = seenWhere?.OR as Array<{ storageKey?: { in: string[] } }>;
  assert.deepEqual(or[0].storageKey?.in, ['2026/08/abc.jpg', '2026/09/def.png']);
});

test('the private URL form is claimed by asset id', async () => {
  let seenWhere: Record<string, unknown> | undefined;
  const service = build(
    prisma({
      mediaAsset: {
        updateMany: async ({ where }: { where: Record<string, unknown> }) => {
          seenWhere = where;
          return { count: 1 };
        },
      },
    }),
    config(),
    storage(),
  );

  await service.markAttached('user-1', [
    'https://api.reem.sy/media/3f4a9c1e-1b2d-4e5f-8a90-abcdef012345/file',
  ]);

  const or = seenWhere?.OR as Array<{ id?: { in: string[] } }>;
  assert.deepEqual(or[0].id?.in, ['3f4a9c1e-1b2d-4e5f-8a90-abcdef012345']);
});

test('URLs that are not ours are skipped rather than raised', async () => {
  let called = false;
  const service = build(
    prisma({
      mediaAsset: {
        updateMany: async () => {
          called = true;
          return { count: 0 };
        },
      },
    }),
    config(),
    storage(),
  );

  // The demo dataset is full of external links; a publish must not fail on one.
  const count = await service.markAttached('user-1', [
    'https://images.unsplash.com/photo-123',
    null,
    undefined,
    '',
  ]);

  assert.equal(count, 0);
  assert.equal(called, false);
});

// ── URLs ────────────────────────────────────────────────────────────────────

test('a configured public origin wins over the origin the request arrived on', async () => {
  const service = build(
    prisma(),
    config({ 'media.publicOrigin': 'https://cdn.reem.sy/' }),
    storage(),
  );

  const url = service.urlFor(
    { visibility: 'PUBLIC', storageKey: '2026/08/a.jpg' } as never,
    'http://10.0.2.2:3000',
  );
  assert.equal(url, 'https://cdn.reem.sy/media/files/2026/08/a.jpg');
});

test('with nothing configured the URL follows the request home', async () => {
  const service = build(prisma(), config(), storage());
  const url = service.urlFor(
    { visibility: 'PUBLIC', storageKey: '2026/08/a.jpg' } as never,
    'http://192.168.1.9:3000',
  );
  assert.equal(url, 'http://192.168.1.9:3000/media/files/2026/08/a.jpg');
});

test('a private asset gets an authorised path, never a file path', async () => {
  const service = build(prisma(), config(), storage());
  const url = service.urlFor(
    { id: 'asset-9', visibility: 'PRIVATE', storageKey: '2026/08/id.jpg' } as never,
    'https://api.reem.sy',
  );
  assert.equal(url, 'https://api.reem.sy/media/asset-9/file');
  assert.ok(!url.includes('2026/08/id.jpg'));
});

// ── Private access ──────────────────────────────────────────────────────────

const privateAsset = {
  id: 'doc-1',
  ownerId: 'seller-1',
  visibility: 'PRIVATE',
  storageKey: '2026/08/id.jpg',
  mimeType: 'image/jpeg',
  // The purpose is what selects the access rule; an asset without one is
  // readable by nobody but its owner, which is the safe direction.
  purpose: 'verification',
};

const withAsset = (asset: unknown, overrides: Record<string, unknown> = {}) =>
  prisma({
    mediaAsset: { findUnique: async () => asset },
    ...overrides,
  });

const chatAsset = {
  id: 'photo-1',
  ownerId: 'buyer-1',
  visibility: 'PRIVATE',
  storageKey: '2026/08/photo.jpg',
  mimeType: 'image/jpeg',
  purpose: 'chat',
};

/// Stands in for `messageAttachment.count`, which is how a chat asset's
/// readers are found.
const withChatMembership = (member: boolean) => ({
  messageAttachment: { count: async () => (member ? 1 : 0) },
});

test('a seller may read her own verification document', async () => {
  const service = build(withAsset(privateAsset), config(), storage());
  const { asset } = await service.readPrivate('doc-1', {
    id: 'seller-1',
    role: 'SELLER',
  } as never);
  assert.equal(asset.id, 'doc-1');
});

test('a verification reviewer may read it', async () => {
  const service = build(
    withAsset(privateAsset, grants('seller_verification:review')),
    config(),
    storage(),
  );
  const { asset } = await service.readPrivate('doc-1', {
    id: 'staff-1',
    role: 'SUPPORT',
  } as never);
  assert.equal(asset.id, 'doc-1');
});

test('a senior admin without the review permission may not', async () => {
  // Deliberately not `assertCanManage`: seniority is not a reason to look at a
  // photograph of somebody's national ID card. The permission decides, and
  // holding the most senior role is not the same as holding it.
  const service = build(
    withAsset(privateAsset, grants('admin:dashboard')),
    config(),
    storage(),
  );
  await assert.rejects(
    service.readPrivate('doc-1', {
      id: 'admin-1',
      role: 'SUPER_ADMIN',
    } as never),
    /MEDIA_FORBIDDEN/,
  );
});

test('a revoked reviewer is refused even while her token still claims it', async () => {
  // The regression this guards: the rule used to read `actor.permissions`,
  // which is the claim minted at sign-in. Pulling the permission — the one
  // action available when a reviewer should stop seeing identity documents —
  // did nothing until her access token happened to expire.
  const service = build(
    withAsset(privateAsset, grants('support:read')),
    config(),
    storage(),
  );
  await assert.rejects(
    service.readPrivate('doc-1', {
      id: 'staff-1',
      role: 'SUPPORT',
      permissions: ['seller_verification:review'],
    } as never),
    /MEDIA_FORBIDDEN/,
  );
});

test('another seller may not read it', async () => {
  const service = build(withAsset(privateAsset), config(), storage());
  await assert.rejects(
    service.readPrivate('doc-1', { id: 'seller-2', role: 'SELLER' } as never),
    /MEDIA_FORBIDDEN/,
  );
});

test('a public asset is refused here and sent to its cacheable URL instead', async () => {
  const service = build(
    withAsset({ ...privateAsset, visibility: 'PUBLIC' }),
    config(),
    storage(),
  );
  await assert.rejects(
    service.readPrivate('doc-1', { id: 'seller-1', role: 'SELLER' } as never),
    /MEDIA_IS_PUBLIC/,
  );
});

// ── Derivatives ─────────────────────────────────────────────────────────────

/// A real 600×400 PNG, large enough that a 480px copy is worth making and a
/// 1080px one is not.
function wideImage(): Buffer {
  const zlib = require('node:zlib') as typeof import('node:zlib');
  const chunk = (type: string, data: Buffer) => {
    const body = Buffer.concat([Buffer.from(type, 'latin1'), data]);
    const length = Buffer.alloc(4);
    length.writeUInt32BE(data.length);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(body));
    return Buffer.concat([length, body, crc]);
  };
  const width = 600;
  const height = 400;
  const rows: Buffer[] = [];
  for (let y = 0; y < height; y++) {
    const row = Buffer.alloc(1 + width * 3);
    for (let x = 0; x < width; x++) {
      row[1 + x * 3] = x % 256;
      row[2 + x * 3] = y % 256;
      row[3 + x * 3] = 180;
    }
    rows.push(row);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(Buffer.concat(rows))),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function crc32(buffer: Buffer): number {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) {
      crc = crc & 1 ? (crc >>> 1) ^ 0xedb88320 : crc >>> 1;
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

test('an image gets a resized copy and a blur hash', async () => {
  const store = storage();
  const service = build(prisma(), config(), store);

  const asset = await service.upload('user-1', {
    buffer: wideImage(),
    visibility: 'PUBLIC' as never,
    purpose: 'product',
    allowedKinds: ['image', 'video'] as never,
  });

  // 600px wide: worth a 480 copy, nothing to gain from a 1080 one.
  assert.deepEqual(asset.variants, [480]);
  assert.ok(asset.blurHash && asset.blurHash.length > 6);

  const keys = [...store.written.keys()];
  assert.equal(keys.length, 2);
  assert.ok(keys.some((key) => key.endsWith('@480.webp')));
  // The whole point: the copy is smaller than what it replaces.
  const original = store.written.get(keys.find((k) => !k.includes('@'))!)!;
  const thumb = store.written.get(keys.find((k) => k.includes('@'))!)!;
  assert.ok(thumb.length < original.length);
});

test('nothing is upscaled', async () => {
  const store = storage();
  const service = build(prisma(), config(), store);

  // The 10×10 fixture is smaller than every variant width.
  const asset = await service.upload('user-1', {
    buffer: png(),
    visibility: 'PUBLIC' as never,
    purpose: 'product',
    allowedKinds: ['image', 'video'] as never,
  });

  assert.deepEqual(asset.variants, []);
  assert.equal(store.written.size, 1);
});

test('a voice note gets no derivatives', async () => {
  const store = storage();
  const service = build(prisma(), config(), store);

  const asset = await service.upload('user-1', {
    buffer: m4a(),
    visibility: 'PRIVATE' as never,
    purpose: 'chat',
    allowedKinds: ['image', 'audio'] as never,
  });

  assert.deepEqual(asset.variants, []);
  assert.equal(asset.blurHash, null);
  assert.equal(store.written.size, 1);
});

test('a width that was never generated falls back to the original URL', async () => {
  const service = build(prisma(), config(), storage());
  const asset = {
    id: 'a1',
    visibility: 'PUBLIC',
    storageKey: '2026/08/a.jpg',
    variants: [480],
  } as never;

  assert.equal(
    service.variantUrlFor(asset, 'http://host', 480),
    'http://host/media/files/2026/08/a@480.webp',
  );
  // 1080 was never made — the original, not a URL that would 404.
  assert.equal(
    service.variantUrlFor(asset, 'http://host', 1080),
    'http://host/media/files/2026/08/a.jpg',
  );
});

test('a private variant is addressed by width, not by path', async () => {
  const service = build(prisma(), config(), storage());
  const asset = {
    id: 'doc-1',
    visibility: 'PRIVATE',
    storageKey: '2026/08/a.jpg',
    variants: [480],
  } as never;

  // Never a file path: the bytes stay behind the authorised handler.
  assert.equal(
    service.variantUrlFor(asset, 'http://host', 480),
    'http://host/media/doc-1/file?w=480',
  );
});

test('the sweeper takes the resized copies with it', async () => {
  const removed: string[] = [];
  const store = storage();
  store.remove = async (key: string) => {
    removed.push(key);
  };

  const service = build(
    prisma({
      mediaAsset: {
        findMany: async () => [
          {
            id: 'a',
            storageKey: '2026/08/a.jpg',
            visibility: 'PUBLIC',
            variants: [480, 1080],
          },
        ],
      },
    }),
    config(),
    store,
  );

  await service.sweepOrphans();

  // Nothing but the original has a row, so the copies are invisible to the
  // sweep unless it is told about them.
  assert.deepEqual(removed, [
    '2026/08/a.jpg',
    '2026/08/a@480.webp',
    '2026/08/a@1080.webp',
  ]);
});

// ── Chat media ──────────────────────────────────────────────────────────────

test('someone in the conversation may open a photograph sent to it', async () => {
  const service = build(
    withAsset(chatAsset, withChatMembership(true)),
    config(),
    storage(),
  );
  const { asset } = await service.readPrivate('photo-1', {
    id: 'seller-9',
    role: 'SELLER',
  } as never);
  assert.equal(asset.id, 'photo-1');
});

test('someone outside the conversation may not', async () => {
  const service = build(
    withAsset(chatAsset, withChatMembership(false)),
    config(),
    storage(),
  );
  await assert.rejects(
    service.readPrivate('photo-1', { id: 'nosy-1', role: 'SELLER' } as never),
    /MEDIA_FORBIDDEN/,
  );
});

test('a verification reviewer has no business in a conversation', async () => {
  // The rules are per purpose on purpose. There is no blanket "staff may read
  // private media": the people who review identity documents are not thereby
  // readers of everyone's messages.
  const service = build(
    withAsset(chatAsset, withChatMembership(false)),
    config(),
    storage(),
  );
  await assert.rejects(
    service.readPrivate('photo-1', {
      id: 'staff-1',
      role: 'SUPPORT',
      permissions: ['seller_verification:review'],
    } as never),
    /MEDIA_FORBIDDEN/,
  );
});

test('a purpose with no rule fails closed', async () => {
  const service = build(
    withAsset({ ...chatAsset, purpose: 'something_new' }),
    config(),
    storage(),
  );
  await assert.rejects(
    service.readPrivate('photo-1', { id: 'anyone', role: 'SELLER' } as never),
    /MEDIA_FORBIDDEN/,
  );
});

// ── Resolving ───────────────────────────────────────────────────────────────

test('an asset id is resolved from a private URL, scoped to its owner', async () => {
  let seenWhere: Record<string, unknown> | undefined;
  const service = build(
    prisma({
      mediaAsset: {
        findFirst: async ({ where }: { where: Record<string, unknown> }) => {
          seenWhere = where;
          return { id: 'asset-7' };
        },
      },
    }),
    config(),
    storage(),
  );

  const id = await service.resolveAssetId(
    'http://host/media/3f4a9c1e-1b2d-4e5f-8a90-abcdef012345/file',
    'user-1',
  );

  assert.equal(id, 'asset-7');
  // Scoped to the sender: quoting somebody else's upload URL into a chat must
  // not make it readable by that chat's participants.
  assert.equal(seenWhere?.ownerId, 'user-1');
  assert.equal(seenWhere?.id, '3f4a9c1e-1b2d-4e5f-8a90-abcdef012345');
});

test('a public URL resolves by storage key', async () => {
  let seenWhere: Record<string, unknown> | undefined;
  const service = build(
    prisma({
      mediaAsset: {
        findFirst: async ({ where }: { where: Record<string, unknown> }) => {
          seenWhere = where;
          return { id: 'asset-8' };
        },
      },
    }),
    config(),
    storage(),
  );

  assert.equal(
    await service.resolveAssetId(
      'http://host/media/files/2026/08/a.png',
      'user-1',
    ),
    'asset-8',
  );
  assert.equal(seenWhere?.storageKey, '2026/08/a.png');
});

test('a URL that is not ours resolves to nothing', async () => {
  const service = build(prisma(), config(), storage());
  assert.equal(
    await service.resolveAssetId('https://images.unsplash.com/x', 'user-1'),
    null,
  );
});

test('blur hashes come back keyed by the URL that was asked about', async () => {
  // The caller holds URLs, not storage keys — it is denormalising onto its own
  // rows and needs to know which hash belongs to which photograph.
  const service = build(
    prisma({
      mediaAsset: {
        findMany: async () => [
          { id: 'a1', storageKey: '2026/08/a.jpg', blurHash: 'LDHV' },
          {
            id: '3f4a9c1e-1b2d-4e5f-8a90-abcdef012345',
            storageKey: '2026/08/b.jpg',
            blurHash: 'LKO2',
          },
        ],
      },
    }),
    config(),
    storage(),
  );

  const hashes = await service.blurHashesFor(
    [
      'http://host/media/files/2026/08/a.jpg',
      'http://other/media/3f4a9c1e-1b2d-4e5f-8a90-abcdef012345/file',
      'https://images.unsplash.com/photo-1',
    ],
    'user-1',
  );

  assert.equal(hashes.get('http://host/media/files/2026/08/a.jpg'), 'LDHV');
  assert.equal(
    hashes.get('http://other/media/3f4a9c1e-1b2d-4e5f-8a90-abcdef012345/file'),
    'LKO2',
  );
  // An external link has no hash and no row; it is simply absent.
  assert.equal(hashes.has('https://images.unsplash.com/photo-1'), false);
});

test('asking about nothing does not hit the database', async () => {
  let queried = false;
  const service = build(
    prisma({
      mediaAsset: {
        findMany: async () => {
          queried = true;
          return [];
        },
      },
    }),
    config(),
    storage(),
  );

  assert.equal((await service.blurHashesFor([], 'user-1')).size, 0);
  assert.equal(
    (await service.blurHashesFor(['https://elsewhere/x.jpg'], 'user-1')).size,
    0,
  );
  assert.equal(queried, false);
});

// ── Sweeping ────────────────────────────────────────────────────────────────

test('the sweeper deletes the bytes before the row that finds them', async () => {
  const order: string[] = [];
  const store = storage();
  store.remove = async (key: string) => {
    order.push(`bytes:${key}`);
  };

  const service = build(
    prisma({
      mediaAsset: {
        findMany: async () => [
          {
            id: 'a',
            storageKey: '2026/08/a.jpg',
            visibility: 'PUBLIC',
            variants: [],
          },
        ],
        delete: async () => {
          order.push('row');
          return {};
        },
      },
    }),
    config(),
    store,
  );

  assert.equal(await service.sweepOrphans(), 1);
  // A row pointing at missing bytes reads as a 404 and the next sweep clears
  // it; bytes with no row are invisible to the sweeper forever.
  assert.deepEqual(order, ['bytes:2026/08/a.jpg', 'row']);
});

test('one unremovable file does not abandon the rest of the sweep', async () => {
  const store = storage();
  store.remove = async (key: string) => {
    if (key.includes('locked')) throw new Error('EBUSY');
  };

  const service = build(
    prisma({
      mediaAsset: {
        findMany: async () => [
          {
            id: 'a',
            storageKey: '2026/08/locked.jpg',
            visibility: 'PUBLIC',
            variants: [],
          },
          {
            id: 'b',
            storageKey: '2026/08/b.jpg',
            visibility: 'PUBLIC',
            variants: [],
          },
        ],
      },
    }),
    config(),
    store,
  );

  assert.equal(await service.sweepOrphans(), 1);
});
