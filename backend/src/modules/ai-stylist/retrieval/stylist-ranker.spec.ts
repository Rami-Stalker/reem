import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  MediaType,
  ModestyLevel,
  OfferStatus,
  OutfitSlot,
  Prisma,
  ProductStatus,
} from '@prisma/client';
import { emptyStyleProfile } from '../preferences/style-profile';
import { emptyBrief } from '../understanding/style-brief';
import { StylistCandidate } from './product-retrieval.service';
import { productColourKeys, rankProducts, renderReason, scoreProduct } from './stylist-ranker';

/**
 * Builds a candidate shaped exactly like `PRODUCT_CARD_INCLUDE` produces.
 *
 * Hand-built rather than fixture-loaded so the ranker can be tested without a
 * database — which is the property that lets a scoring rule be changed with
 * confidence.
 */
function product(overrides: {
  id: string;
  title?: string;
  categorySlug?: string;
  priceSyp?: number;
  rating?: number;
  ordersCount?: number;
  sellerId?: string;
  attributes?: Record<string, unknown> | null;
  variantColour?: string;
  variantSizes?: Array<{ size: string; stock: number }>;
  handlingDays?: number;
  isMadeToOrder?: boolean;
}): StylistCandidate {
  const price = new Prisma.Decimal(overrides.priceSyp ?? 600_000);
  const sellerId = overrides.sellerId ?? 'seller-1';

  const variants = [
    ...(overrides.variantColour
      ? [
          {
            id: `${overrides.id}-v-colour`,
            productId: overrides.id,
            name: overrides.variantColour,
            attributes: { colour: overrides.variantColour } as Prisma.JsonValue,
            imageUrl: null,
            sortOrder: 0,
          },
        ]
      : []),
    ...(overrides.variantSizes ?? []).map((entry, index) => ({
      id: `${overrides.id}-v-${entry.size}`,
      productId: overrides.id,
      name: entry.size,
      attributes: { size: entry.size } as Prisma.JsonValue,
      imageUrl: null,
      sortOrder: index,
    })),
  ];

  return {
    id: overrides.id,
    slug: overrides.id,
    title: overrides.title ?? 'فستان سهرة',
    description: 'وصف المنتج',
    categoryId: 'cat-1',
    brandId: null,
    attributes: (overrides.attributes ?? null) as Prisma.JsonValue,
    gtin: null,
    createdBySellerId: null,
    status: ProductStatus.ACTIVE,
    moderationStatus: 'OPEN',
    isFeatured: false,
    showInFeed: true,
    offersCount: 1,
    minPriceSyp: price,
    maxPriceSyp: price,
    rating: overrides.rating ?? 4,
    reviewsCount: 10,
    viewsCount: 100,
    likesCount: 5,
    ordersCount: overrides.ordersCount ?? 10,
    favoritesCount: 5,
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
    category: {
      id: 'cat-1',
      parentId: null,
      level: 2,
      slug: overrides.categorySlug ?? 'dresses',
      nameAr: 'فساتين',
      nameEn: 'Dresses',
      iconUrl: null,
      imageUrl: null,
      attributeSchema: null,
      isSensitive: false,
      returnsAllowed: true,
      sizeChartId: null,
      sortOrder: 0,
      isActive: true,
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-01'),
    },
    brand: null,
    media: [
      {
        id: `${overrides.id}-m`,
        productId: overrides.id,
        url: 'https://example.test/image.jpg',
        type: MediaType.image,
        sortOrder: 0,
        blurHash: null,
      },
    ],
    variants,
    offers: [
      {
        id: `${overrides.id}-offer`,
        productId: overrides.id,
        sellerId,
        currency: Currency.SYP,
        price,
        compareAtPrice: null,
        wholesalePrice: null,
        wholesaleMinQty: null,
        stock: 5,
        minOrderQty: 1,
        maxOrderQty: null,
        sku: null,
        handlingDays: overrides.handlingDays ?? 1,
        isMadeToOrder: overrides.isMadeToOrder ?? false,
        requiresDeposit: false,
        depositPercent: null,
        acceptsReturns: true,
        status: OfferStatus.ACTIVE,
        isActive: true,
        createdAt: new Date('2026-01-01'),
        updatedAt: new Date('2026-01-01'),
        seller: { id: sellerId, name: 'بوتيك شام' } as never,
        variants: (overrides.variantSizes ?? []).map((entry) => ({
          id: `${overrides.id}-ov-${entry.size}`,
          offerId: `${overrides.id}-offer`,
          variantId: `${overrides.id}-v-${entry.size}`,
          price: null,
          stock: entry.stock,
          sku: null,
          variant: {
            id: `${overrides.id}-v-${entry.size}`,
            productId: overrides.id,
            name: entry.size,
            attributes: { size: entry.size } as Prisma.JsonValue,
            imageUrl: null,
            sortOrder: 0,
          },
        })),
      },
    ],
  } as unknown as StylistCandidate;
}

test('a sleeveless dress is removed from a modest request, not merely demoted', () => {
  // The failure that would cost the assistant her trust outright.
  const brief = { ...emptyBrief(), modesty: ModestyLevel.MODEST };
  const sleeveless = product({
    id: 'p1',
    title: 'فستان كوكتيل بدون أكمام',
    categorySlug: 'dresses',
  });

  const scored = scoreProduct(sleeveless, { brief, profile: emptyStyleProfile() });

  assert.equal(Number.isFinite(scored.score), false);
});

test('a long-sleeved dress scores the modesty match and says so', () => {
  const brief = { ...emptyBrief(), modesty: ModestyLevel.MODEST };
  const covered = product({
    id: 'p2',
    title: 'فستان ماكسي',
    attributes: { sleeve_length: 'كم طويل' },
  });

  const scored = scoreProduct(covered, { brief, profile: emptyStyleProfile() });

  assert.ok(Number.isFinite(scored.score));
  assert.ok(scored.reasons.includes('MODESTY_MATCH'));
  assert.match(renderReason(scored, brief), /محتشم/);
});

test('over budget always ranks below in budget', () => {
  const brief = { ...emptyBrief(), budgetMax: 500_000 };
  const profile = emptyStyleProfile();

  // The dear one is better on every quality signal and must still lose.
  const affordable = product({ id: 'cheap', priceSyp: 400_000, rating: 3.5, ordersCount: 2 });
  const dear = product({ id: 'dear', priceSyp: 1_500_000, rating: 5, ordersCount: 500 });

  const ranked = rankProducts([dear, affordable], { brief, profile, diversity: null }, 2);

  assert.equal(ranked[0].product.id, 'cheap');
  assert.ok(ranked[0].reasons.includes('BUDGET_FIT'));
});

test('a dismissed product never comes back', () => {
  const profile = emptyStyleProfile('user-1');
  profile.dismissedProductIds.add('p3');

  const scored = scoreProduct(product({ id: 'p3' }), {
    brief: emptyBrief(),
    profile,
  });

  assert.equal(Number.isFinite(scored.score), false);
});

test('a colour she asked for beats one that merely harmonises', () => {
  const brief = { ...emptyBrief(), colours: ['black'] };
  const profile = emptyStyleProfile();

  const exact = product({ id: 'black', title: 'فستان بلون الأسود اللامع' });
  const harmonising = product({ id: 'gold', title: 'فستان بلون الشامبانيا' });

  const ranked = rankProducts([harmonising, exact], { brief, profile, diversity: null }, 2);

  assert.equal(ranked[0].product.id, 'black');
  assert.ok(ranked[0].reasons.includes('COLOUR_MATCH'));
  assert.ok(ranked[1].reasons.includes('COLOUR_HARMONY'));
});

test('her size in stock is what scores, not merely that the size exists', () => {
  const brief = {
    ...emptyBrief(),
    slots: [OutfitSlot.DRESS],
    sizes: { clothing: 'M' },
  };
  const profile = emptyStyleProfile();

  const inStock = product({
    id: 'has-m',
    variantSizes: [{ size: 'M', stock: 3 }, { size: 'L', stock: 1 }],
  });
  const soldOut = product({
    id: 'no-m',
    variantSizes: [{ size: 'M', stock: 0 }, { size: 'L', stock: 9 }],
  });

  const withStock = scoreProduct(inStock, { brief, profile });
  const without = scoreProduct(soldOut, { brief, profile });

  assert.ok(withStock.reasons.includes('SIZE_AVAILABLE'));
  assert.equal(without.reasons.includes('SIZE_AVAILABLE'), false);
  assert.ok(withStock.score > without.score);
});

test('one boutique cannot take over the whole list', () => {
  const brief = emptyBrief();
  const profile = emptyStyleProfile();

  // Four strong candidates from one seller, one weaker from another.
  const candidates = [
    product({ id: 'a', sellerId: 's1', rating: 5, ordersCount: 300 }),
    product({ id: 'b', sellerId: 's1', rating: 5, ordersCount: 290 }),
    product({ id: 'c', sellerId: 's1', rating: 5, ordersCount: 280 }),
    product({ id: 'd', sellerId: 's2', rating: 3, ordersCount: 4 }),
  ];

  const ranked = rankProducts(
    candidates,
    { brief, profile, diversity: { perCategory: 5, perSeller: 2 } },
    3,
  );

  const sellers = ranked.map((entry) => entry.product.offers[0].sellerId);
  assert.equal(sellers.filter((id) => id === 's1').length, 2);
  assert.ok(sellers.includes('s2'));
});

test('a look does not clash: an anchor colour penalises what fights it', () => {
  const brief = emptyBrief();
  const profile = emptyStyleProfile();

  const harmonising = product({ id: 'gold-bag', title: 'حقيبة ذهبية', categorySlug: 'handbags' });
  const clashing = product({ id: 'green-bag', title: 'حقيبة خضراء', categorySlug: 'handbags' });

  const withGold = scoreProduct(harmonising, {
    brief,
    profile,
    anchorColour: 'burgundy',
    slot: OutfitSlot.BAG,
  });
  const withGreen = scoreProduct(clashing, {
    brief,
    profile,
    anchorColour: 'burgundy',
    slot: OutfitSlot.BAG,
  });

  assert.ok(withGold.score > withGreen.score);
});

test('colour is read from a variant attribute in preference to the title', () => {
  const withVariant = product({
    id: 'v',
    title: 'فستان سهرة',
    variantColour: 'كحلي',
  });

  assert.deepEqual(productColourKeys(withVariant), ['navy']);
});

test('a reason only ever states what actually scored', () => {
  // The whole point of rendering prose from codes: no clause can appear
  // without the component that justifies it having fired.
  const brief = { ...emptyBrief(), budgetMax: 800_000, colours: ['black'] };
  const scored = scoreProduct(
    product({ id: 'p', title: 'فستان بلون الأسود اللامع', priceSyp: 500_000 }),
    { brief, profile: emptyStyleProfile() },
  );

  const reason = renderReason(scored, brief);

  assert.match(reason, /أسود/);
  assert.match(reason, /ميزانيتك/);
  // No size was asked for, so no size clause may appear.
  assert.doesNotMatch(reason, /مقاس/);
});
