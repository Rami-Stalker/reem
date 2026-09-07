import assert from 'node:assert/strict';
import test from 'node:test';
import { ContentTagBasis, UserRole } from '@prisma/client';
import { AuthUser } from '../../../common/decorators/current-user.decorator';
import { ProductTagPolicyService } from './product-tag-policy.service';

// ── Fixtures ────────────────────────────────────────────────────────────────

const SELLER: AuthUser = {
  id: 'seller-1',
  phone: '+963931000101',
  role: UserRole.SELLER,
};
const SHOPPER: AuthUser = {
  id: 'shopper-1',
  phone: '+963931000900',
  role: UserRole.CUSTOMER,
};
const MODERATOR: AuthUser = {
  id: 'staff-1',
  phone: '+963931000001',
  role: UserRole.CONTENT_MODERATOR,
};

interface World {
  /** Product ids the actor holds a live offer on. */
  offers?: string[];
  /** productId -> the delivered order line that proves it. */
  delivered?: Record<string, string>;
}

function prisma(world: World = {}) {
  return {
    sellerOffer: {
      findMany: async () =>
        (world.offers ?? []).map((productId) => ({ productId })),
      count: async () => (world.offers ?? []).length,
    },
    orderItem: {
      findMany: async () =>
        Object.entries(world.delivered ?? {}).map(([productId, id]) => ({
          id,
          productId,
          titleSnapshot: 'فستان',
          imageSnapshot: null,
          sellerOrder: { createdAt: new Date() },
        })),
      count: async () => Object.keys(world.delivered ?? {}).length,
    },
  };
}

function build(world: World = {}, enforcing = true) {
  return new ProductTagPolicyService(
    prisma(world) as never,
    { get: () => enforcing } as never,
  );
}

// ── The boutique's basis ────────────────────────────────────────────────────

test('a seller may tag a product she holds a live offer on', async () => {
  const policy = build({ offers: ['dress'] });
  const verdicts = await policy.verdicts(SELLER, ['dress']);
  assert.equal(verdicts.get('dress')?.basis, ContentTagBasis.SELLER_OFFER);
});

test('a seller may not tag a product she does not sell', async () => {
  const policy = build({ offers: ['dress'] });
  const verdicts = await policy.verdicts(SELLER, ['someone-elses-bag']);
  assert.equal(verdicts.get('someone-elses-bag')?.basis, null);
  assert.equal(
    verdicts.get('someone-elses-bag')?.refusal,
    'PRODUCT_NOT_SOLD_BY_YOU',
  );
});

// ── The shopper's basis ─────────────────────────────────────────────────────

test('a shopper may tag a product that was delivered to her', async () => {
  const policy = build({ delivered: { dress: 'line-9' } });
  const verdicts = await policy.verdicts(SHOPPER, ['dress']);
  assert.equal(verdicts.get('dress')?.basis, ContentTagBasis.PURCHASE);
});

test('the delivered line is recorded as the proof', async () => {
  // Not decoration: a creator-rewards programme pays on tags, and a payout
  // against a tag nobody can justify is a chargeback.
  const policy = build({ delivered: { dress: 'line-9' } });
  const verdicts = await policy.verdicts(SHOPPER, ['dress']);
  assert.equal(verdicts.get('dress')?.sourceOrderItemId, 'line-9');
});

test('a shopper may not tag a product she never received', async () => {
  const policy = build({ delivered: { dress: 'line-9' } });
  const verdicts = await policy.verdicts(SHOPPER, ['coat']);
  assert.equal(verdicts.get('coat')?.basis, null);
  assert.equal(verdicts.get('coat')?.refusal, 'PRODUCT_NOT_PURCHASED');
});

// ── The two bases are OR'd, not switched on ─────────────────────────────────

test('a seller who BOUGHT something elsewhere may still post about it', async () => {
  // The reason the bases are evaluated in parallel rather than by a
  // `switch (role)`. A boutique owner is also a shopper, and a role switch
  // would refuse her forever — a refusal that reads as a bug and never gets
  // traced back to a policy decision nobody wrote down.
  const policy = build({ offers: ['her-own-dress'], delivered: { rival: 'line-3' } });
  const verdicts = await policy.verdicts(SELLER, ['rival']);
  assert.equal(verdicts.get('rival')?.basis, ContentTagBasis.PURCHASE);
});

test('purchase wins over offer when both hold, so the proof is kept', async () => {
  const policy = build({ offers: ['dress'], delivered: { dress: 'line-1' } });
  const verdicts = await policy.verdicts(SELLER, ['dress']);
  assert.equal(verdicts.get('dress')?.basis, ContentTagBasis.PURCHASE);
  assert.equal(verdicts.get('dress')?.sourceOrderItemId, 'line-1');
});

// ── Staff ───────────────────────────────────────────────────────────────────

test('a moderator may tag anything, and it is recorded as such', async () => {
  const policy = build();
  const verdicts = await policy.verdicts(MODERATOR, ['anything']);
  assert.equal(verdicts.get('anything')?.basis, ContentTagBasis.ADMIN);
});

// ── The gate ────────────────────────────────────────────────────────────────

test('assert refuses when enforcing, naming the rule and the products', async () => {
  const policy = build({ delivered: {} });
  await assert.rejects(
    () => policy.assert(SHOPPER, ['not-hers']),
    (error: { response?: { code?: string; product_ids?: string[] } }) => {
      assert.equal(error.response?.code, 'PRODUCT_NOT_PURCHASED');
      assert.deepEqual(error.response?.product_ids, ['not-hers']);
      return true;
    },
  );
});

test('assert only warns while the policy is not yet enforcing', async () => {
  // The old check read a product's offers with no status filter, so boutiques
  // with a draft or archived listing can tag today. Refusing them in one
  // release would break sellers who have done nothing wrong, so the first
  // release logs instead.
  const policy = build({ delivered: {} }, false);
  const verdicts = await policy.assert(SHOPPER, ['not-hers']);
  assert.equal(verdicts.get('not-hers')?.basis, ContentTagBasis.SELLER_OFFER);
  assert.equal(verdicts.get('not-hers')?.refusal, undefined);
});

test('an empty tag list asks the database nothing', async () => {
  const policy = new ProductTagPolicyService(
    {
      sellerOffer: {
        findMany: () => assert.fail('queried offers for zero products'),
      },
      orderItem: {
        findMany: () => assert.fail('queried orders for zero products'),
      },
    } as never,
    { get: () => true } as never,
  );
  assert.equal((await policy.verdicts(SHOPPER, [])).size, 0);
});

test('a repeated product id is asked about once', async () => {
  let calls = 0;
  const policy = new ProductTagPolicyService(
    {
      sellerOffer: {
        findMany: async () => {
          calls += 1;
          return [];
        },
      },
      orderItem: { findMany: async () => [{ id: 'l', productId: 'dress' }] },
    } as never,
    { get: () => true } as never,
  );
  const verdicts = await policy.verdicts(SHOPPER, ['dress', 'dress', 'dress']);
  assert.equal(calls, 1);
  assert.equal(verdicts.size, 1);
});

// ── The picker ──────────────────────────────────────────────────────────────

test('the shopper picker lists a delivered line once, with its snapshot', async () => {
  // The snapshot rather than the live title: it is what her receipt says, and
  // it survives the boutique renaming or delisting the piece.
  const policy = build({ delivered: { dress: 'line-9' } });
  const page = await policy.listTaggable(SHOPPER, {
    page: 1,
    limit: 20,
    skip: 0,
  } as never);
  assert.equal(page.data.length, 1);
  assert.equal(page.data[0].title, 'فستان');
  assert.equal(page.data[0].basis, ContentTagBasis.PURCHASE);
});

test('the seller picker offers what she actually lists', async () => {
  const policy = new ProductTagPolicyService(
    {
      sellerOffer: {
        findMany: async () => [
          { product: { id: 'dress', title: 'فستان سهرة', media: [] } },
        ],
        count: async () => 1,
      },
      orderItem: { findMany: async () => [], count: async () => 0 },
    } as never,
    { get: () => true } as never,
  );
  const page = await policy.listTaggable(SELLER, {
    page: 1,
    limit: 20,
    skip: 0,
  } as never);
  assert.equal(page.data[0].product_id, 'dress');
  assert.equal(page.data[0].basis, ContentTagBasis.SELLER_OFFER);
});
