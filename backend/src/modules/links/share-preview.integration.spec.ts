import assert from 'node:assert/strict';
import test from 'node:test';
import type { ConfigService } from '@nestjs/config';
import {
  CommerceAuthorKind,
  CommerceContentStatus,
  CommerceContentVisibility,
  PrismaClient,
  ProductStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { SharePreviewService } from './share-preview.service';

/**
 * What a link hands to a stranger, against the real database.
 *
 * `links.spec.ts` proves the shapes and the escaping without a database. This
 * proves the half that cannot be proven without one: **what a resolver
 * refuses**.
 *
 * That distinction is the whole reason this file exists. Every other read in
 * this API answers a request from somebody; these answer WhatsApp's crawler,
 * which is nobody, and whatever they return is copied into a preview card that
 * is then cached by a third party and forwarded by people who never visited
 * the link. There is no undoing it and no privacy setting that reaches into
 * it. So a draft product, a followers-only post, a closed profile and an
 * expired story must all come back as nothing — and a rule that is only
 * asserted by reading the `where` clause is a rule nobody has tested.
 *
 * Every case runs inside a transaction that is rolled back.
 */
const prisma = new PrismaClient();

class Rollback extends Error {}
type Tx = Parameters<Parameters<typeof prisma.$transaction>[0]>[0];

let reachable = false;

test.before(async () => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    reachable = true;
  } catch {
    reachable = false;
  }
});

test.after(() => prisma.$disconnect());

function dbTest(
  name: string,
  body: (world: { db: PrismaService; previews: SharePreviewService }) => Promise<void>,
): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    let failure: unknown;
    try {
      await prisma.$transaction(
        async (tx) => {
          try {
            await body(build(tx));
          } catch (error) {
            failure = error;
          }
          throw new Rollback();
        },
        { timeout: 120_000 },
      );
    } catch (error) {
      if (!(error instanceof Rollback)) throw error;
    }
    if (failure) throw failure;
  });
}

function build(tx: Tx) {
  const db = tx as unknown as PrismaService;
  const config = {
    get: (key: string) =>
      key === 'links.publicOrigin' ? 'https://links.test' : '',
  } as unknown as ConfigService;
  return { db, previews: new SharePreviewService(db, config) };
}

// ── Fixtures ────────────────────────────────────────────────────────────────

async function aLiveProduct(db: PrismaService) {
  const product = await db.product.findFirst({
    where: {
      status: ProductStatus.ACTIVE,
      offers: { some: { status: 'ACTIVE', isActive: true, stock: { gt: 0 } } },
    },
    select: { id: true, title: true },
  });
  assert.ok(product, 'the seeded shop has no purchasable product');
  return product;
}

async function aPublicPost(db: PrismaService) {
  const content = await db.commerceContent.findFirst({
    where: {
      contentType: 'product_post',
      status: CommerceContentStatus.PUBLISHED,
      visibility: CommerceContentVisibility.PUBLIC,
      authorIsPublic: true,
      authorKind: CommerceAuthorKind.SELLER,
    },
    select: { id: true, authorId: true },
  });
  assert.ok(content, 'the seeded shop has no public boutique post');
  return content;
}

// ── A link that should resolve ──────────────────────────────────────────────

dbTest('a live product resolves with its price and its boutique', async ({ db, previews }) => {
  const product = await aLiveProduct(db);

  const preview = await previews.resolve('product', { id: product.id });

  assert.ok(preview, 'a purchasable product resolved to nothing');
  assert.equal(preview.title, product.title);
  assert.equal(preview.path, `/product/${product.id}`);
  assert.equal(preview.appRoute, `/product-details?id=${product.id}`);
  // The five things the client asked a shared product to carry.
  assert.ok(preview.price, 'no price');
  assert.ok(preview.byline, 'no boutique');
  assert.equal(preview.unavailableNote, null);
  // The figure a machine reads must be present beside the one a human reads,
  // or Facebook and Google render the product as an article.
  assert.ok(preview.priceAmount);
  assert.ok(preview.priceCurrency);
});

dbTest('a public post resolves with its author', async ({ db, previews }) => {
  const post = await aPublicPost(db);

  const preview = await previews.resolve('content', { id: post.id });

  assert.ok(preview, 'a public post resolved to nothing');
  assert.equal(preview.path, `/p/${post.id}`);
  assert.equal(preview.appRoute, `/content/${post.id}`);
  assert.ok(preview.byline);
});

// ── Links that must not ─────────────────────────────────────────────────────

dbTest('a product that is not live is not previewable', async ({ db, previews }) => {
  const product = await aLiveProduct(db);
  await db.product.update({
    where: { id: product.id },
    data: { status: ProductStatus.DRAFT },
  });

  assert.equal(await previews.resolve('product', { id: product.id }), null);
});

dbTest('a followers-only post has no public preview', async ({ db, previews }) => {
  const post = await aPublicPost(db);
  await db.commerceContent.update({
    where: { id: post.id },
    data: { visibility: CommerceContentVisibility.FOLLOWERS },
  });

  // The viewer here is always anonymous, so the followers branch of the feed's
  // visibility rule can never apply — a preview for one would be visible to
  // everybody the link reaches.
  assert.equal(await previews.resolve('content', { id: post.id }), null);
});

dbTest('a post awaiting review is not previewable', async ({ db, previews }) => {
  const post = await aPublicPost(db);
  await db.commerceContent.update({
    where: { id: post.id },
    data: { status: CommerceContentStatus.IN_REVIEW },
  });

  assert.equal(await previews.resolve('content', { id: post.id }), null);
});

dbTest('an expired story is gone, not merely labelled', async ({ db, previews }) => {
  const post = await aPublicPost(db);
  await db.commerceContent.update({
    where: { id: post.id },
    data: {
      contentType: 'story',
      expiresAt: new Date(Date.now() - 60_000),
    },
  });

  // The 24 hours are the promise. A page saying «انتهت صلاحية القصة» above her
  // photograph and her caption would leak precisely what expiry was there to
  // take away, to anyone holding a forwarded link, indefinitely.
  assert.equal(await previews.resolve('content', { id: post.id }), null);
});

dbTest('a closed page has no preview at all', async ({ db, previews }) => {
  const shopper = await db.user.findFirst({
    where: { role: UserRole.CUSTOMER },
    select: { id: true },
  });
  assert.ok(shopper, 'the seeded shop has no shopper');

  await db.user.update({
    where: { id: shopper.id },
    data: { profileIsPublic: false },
  });
  assert.equal(await previews.resolve('profile', { id: shopper.id }), null);

  // And the same id resolves once she opens it — so the null above is the rule
  // firing, not the fixture being wrong.
  await db.user.update({
    where: { id: shopper.id },
    data: { profileIsPublic: true },
  });
  assert.ok(await previews.resolve('profile', { id: shopper.id }));
});

dbTest('a disabled account is not previewable', async ({ db, previews }) => {
  const shopper = await db.user.findFirst({
    where: { role: UserRole.CUSTOMER },
    select: { id: true },
  });
  assert.ok(shopper);

  await db.user.update({
    where: { id: shopper.id },
    data: { profileIsPublic: true, disabledAt: new Date() },
  });
  assert.equal(await previews.resolve('profile', { id: shopper.id }), null);
});

// ── Not-found is not an error ───────────────────────────────────────────────

dbTest('an id that is not a UUID resolves to nothing rather than throwing', async ({
  previews,
}) => {
  // The controller renders the branded 404 for a null. A throw would reach
  // `AllExceptionsFilter` and answer with the JSON error envelope — which is
  // exactly the "page" this whole feature exists to remove.
  assert.equal(await previews.resolve('product', { id: 'not-a-uuid' }), null);
  assert.equal(await previews.resolve('content', { id: '../../etc/passwd' }), null);
  assert.equal(await previews.resolve('profile', { id: '' }), null);
});

dbTest('an unknown collection key resolves to nothing', async ({ previews }) => {
  assert.ok(await previews.resolve('collection', { key: 'trending' }));
  assert.equal(await previews.resolve('collection', { key: 'made_up' }), null);
});

dbTest('a revoked room invite stops resolving', async ({ previews }) => {
  // Rotating the slug is the only revocation a link-shared room can honestly
  // offer, so a slug nobody holds must resolve to nothing.
  assert.equal(
    await previews.resolve('room-invite', { slug: 'no-such-slug-here' }),
    null,
  );
});

// ── Media ───────────────────────────────────────────────────────────────────

dbTest('a stored media path becomes an absolute URL', async ({ db, previews }) => {
  const product = await aLiveProduct(db);
  await db.productMedia.updateMany({
    where: { productId: product.id },
    data: { url: '/media/files/2026/09/photo.jpg' },
  });

  const preview = await previews.resolve('product', { id: product.id });

  // Open Graph accepts only absolute URLs: a crawler has no origin to resolve
  // a path against, and would simply render no picture.
  assert.equal(
    preview?.imageUrl,
    'https://links.test/media/files/2026/09/photo.jpg',
  );
});

dbTest('a CDN URL is passed through untouched', async ({ db, previews }) => {
  const product = await aLiveProduct(db);
  const url = 'https://cdn.example.com/storage/v1/object/public/x/photo.jpg';
  await db.productMedia.updateMany({
    where: { productId: product.id },
    data: { url },
  });

  const preview = await previews.resolve('product', { id: product.id });
  assert.equal(preview?.imageUrl, url);
});
