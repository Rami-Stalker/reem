import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  OfferStatus,
  PrismaClient,
  UserRole,
} from '@prisma/client';

import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { ExchangeRateService } from '../pricing/exchange-rate.service';
import { FavoritesService } from '../favorites/favorites.service';
import { MediaService } from '../media/media.service';
import { CatalogRollupService } from './catalog-rollup.service';
import { ProductsRepository } from './products.repository';
import { SellerOffersService } from './seller-offers.service';
import { SellerProductsService } from './seller-products.service';
import { CreateProductDto } from './dto/create-product.dto';

/**
 * Listing something, and then running the listing.
 *
 * Every write on this path was broken. The client posted a flat product body
 * with a category *slug* and a JSON-number price to `POST /seller/products`,
 * which wants a leaf category's UUID and a nested offer; and it addressed
 * publishing, restocking and removing to `/seller/products/:id/status`,
 * `/seller/products/:id/stock` and `DELETE /seller/products/:id`, three routes
 * that ceased to exist when offers were split out of the catalogue. A seller
 * could not put a single item in the shop.
 *
 * The bodies below are the exact shapes the repaired client now sends, so this
 * fails if either side of that contract drifts again.
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

function dbTest(name: string, body: (world: World) => Promise<void>): void {
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
        { timeout: 60_000 },
      );
    } catch (error) {
      if (!(error instanceof Rollback)) throw error;
    }
    if (failure) throw failure;
  });
}

/** Nested transactions flattened onto the one the test rolls back. */
function asPrisma(tx: Tx): PrismaService {
  return new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (fn: (inner: Tx) => unknown) => fn(tx);
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
}

interface World {
  tx: Tx;
  db: PrismaService;
  products: SellerProductsService;
  offers: SellerOffersService;
}

/**
 * Blur-hashing reads the uploaded bytes and claiming marks upload rows
 * attached; neither exists for a gallery this test invents, and neither is
 * what is under examination here.
 */
const media = {
  blurHashesFor: async () => new Map<string, string>(),
  markAttached: async () => {},
} as unknown as MediaService;

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const rollup = new CatalogRollupService(db, new ExchangeRateService(db));
  const offers = new SellerOffersService(db, rollup, new FavoritesService(db));
  const products = new SellerProductsService(
    db,
    new ProductsRepository(db),
    rollup,
    offers,
    media,
  );
  return { tx, db, products, offers };
}

async function seller(tx: Tx): Promise<AuthUser> {
  const stamp = Date.now() + Math.floor(Math.random() * 10_000);
  const user = await tx.user.create({
    data: {
      name: 'ريم — بائعة اختبار',
      phone: `+96393${String(stamp).slice(-7)}`,
      username: `catalogue_spec_${stamp}`,
      role: UserRole.SELLER,
      sellerVerifiedAt: new Date(),
    },
  });
  return { id: user.id, role: UserRole.SELLER } as AuthUser;
}

/**
 * A real leaf from the seeded tree, and whatever extra fields it governs.
 *
 * A leaf inherits its attribute schema from the nearest ancestor that declares
 * one — «ملابس» requires `material`, so every shelf beneath it does too — and
 * the endpoint refuses a draft that omits a required key. The form had no idea
 * those fields existed, which is a second way a perfectly filled page was
 * refused; it now reads the schema from `GET /categories/:id` and asks.
 */
async function leafCategory(
  tx: Tx,
): Promise<{ id: string; attributes: Record<string, string> }> {
  const leaf = await tx.category.findFirst({
    where: { level: 2, isActive: true },
    orderBy: { slug: 'asc' },
  });
  assert.ok(leaf, 'the catalogue has no leaf categories seeded');

  // Walk up exactly as the service does, then answer whatever it asks for.
  const attributes: Record<string, string> = {};
  let current: { attributeSchema: unknown; parentId: string | null } | null =
    leaf;
  while (current) {
    const schema = current.attributeSchema as { required?: string[] } | null;
    if (schema && Array.isArray(schema.required)) {
      for (const key of schema.required) attributes[key] = 'حرير';
      break;
    }
    if (!current.parentId) break;
    current = await tx.category.findUnique({
      where: { id: current.parentId },
      select: { attributeSchema: true, parentId: true },
    });
  }

  return { id: leaf.id, attributes };
}

/**
 * Exactly what `ProductDraftRequest.toCreateJson()` builds.
 *
 * The cast goes through `unknown` because `InlineOfferDto` re-declares
 * `product_id` with `declare` — which relaxes the *validator* to optional but
 * leaves the compile-time property required. The endpoint accepts the body
 * without it; the type does not say so.
 */
function draftBody(
  category: { id: string; attributes: Record<string, string> },
): CreateProductDto {
  return {
    title: 'فستان حرير بماء الورد',
    description: 'قطعة مصنوعة بعناية، بقصّة تنسدل على الجسم.',
    category_id: category.id,
    attributes: category.attributes,
    media: [
      { url: '/media/public/spec-1.jpg', type: 'image', sort_order: 0 },
    ],
    variants: [
      { name: 'مقاس M', attributes: { size: 'M' }, sort_order: 0 },
      { name: 'مقاس L', attributes: { size: 'L' }, sort_order: 1 },
    ],
    offer: {
      currency: Currency.SYP,
      // A decimal STRING with an explicit currency. A JSON number here would
      // be free to round a figure that runs into the millions.
      price: '850000',
      compare_at_price: '1000000',
      stock: 12,
      handling_days: 2,
      min_order_qty: 1,
      is_made_to_order: false,
      accepts_returns: true,
    },
  } as unknown as CreateProductDto;
}

// ── The journey ─────────────────────────────────────────────────────────────

dbTest('a seller can list something new, and gets her own offer back', async (
  world,
) => {
  const user = await seller(world.tx);
  const category = await leafCategory(world.tx);

  const created = (await world.products.create(
    user,
    draftBody(category),
  )) as Record<string, unknown> & { my_offer: Record<string, unknown> };

  // The response is the catalogue entry with HER listing under `my_offer` —
  // the mirror image of every other seller-catalogue payload, and the shape
  // `ManagedProductModel.fromCreateResponse` unwraps.
  assert.ok(created.id, 'the catalogue entry was written');
  assert.ok(created.my_offer, 'the seller got a listing on it');
  assert.equal(created.my_offer.stock, 12);
  assert.equal(created.my_offer.currency, Currency.SYP);
  assert.equal(
    (created.my_offer.price as { amount: string }).amount.startsWith('850000'),
    true,
    'the price survived the round trip as a decimal, unrounded',
  );

  // A new listing is born a draft: Q39 reviews a new seller's goods before
  // customers see them, so publishing is a second, deliberate act.
  assert.equal(created.my_offer.status, OfferStatus.DRAFT.toLowerCase());
});

dbTest('the option axes come back with ids her offer can be priced against', async (
  world,
) => {
  const user = await seller(world.tx);
  const created = (await world.products.create(
    user,
    draftBody(await leafCategory(world.tx)),
  )) as Record<string, unknown> & {
    my_offer: { id: string };
    variants: { id: string; name: string }[];
  };

  // Canonical variants only receive ids when the product row is written, which
  // is why per-option price and stock cannot ride along on the create call.
  // The client attaches them immediately afterwards, matching by name.
  assert.equal(created.variants.length, 2);
  const medium = created.variants.find((v) => v.name === 'مقاس M');
  assert.ok(medium, 'the option kept the name the form gave it');

  const priced = (await world.offers.update(user, created.my_offer.id, {
    variants: [
      { variant_id: medium.id, stock: 5, price: '870000' },
    ],
  })) as Record<string, unknown> & {
    variants: { variant_id: string; stock: number }[];
  };

  assert.equal(priced.variants.length, 1);
  assert.equal(priced.variants[0].variant_id, medium.id);
  assert.equal(priced.variants[0].stock, 5);
});

dbTest('publishing, restocking and removing all land on the offer', async (
  world,
) => {
  const user = await seller(world.tx);
  const created = (await world.products.create(
    user,
    draftBody(await leafCategory(world.tx)),
  )) as { my_offer: { id: string } };
  const offerId = created.my_offer.id;

  // Publish — `PATCH /seller/offers/:id`, not the `/status` route the client
  // used to call, which had been answering 404.
  const live = (await world.offers.update(user, offerId, {
    status: OfferStatus.ACTIVE,
  })) as { status: string };
  assert.equal(live.status, OfferStatus.ACTIVE.toLowerCase());

  // Restock by a signed DELTA, so two deliveries booked at once add up rather
  // than one overwriting the other.
  const restocked = (await world.offers.adjustStock(user, offerId, {
    delta: 8,
  })) as { stock: number };
  assert.equal(restocked.stock, 20);

  const drawnDown = (await world.offers.adjustStock(user, offerId, {
    delta: -20,
  })) as { stock: number; status: string };
  assert.equal(drawnDown.stock, 0);
  assert.equal(
    drawnDown.status,
    OfferStatus.OUT_OF_STOCK.toLowerCase(),
    'a live listing that empties goes out of stock on its own',
  );

  // Removing archives rather than deletes: an order placed against this
  // listing still has to be explainable in a dispute.
  await world.offers.remove(user, offerId);
  const archived = await world.tx.sellerOffer.findUnique({
    where: { id: offerId },
  });
  assert.equal(archived?.status, OfferStatus.ARCHIVED);
  assert.equal(archived?.isActive, false);
});

dbTest('her own listing is what the catalogue list hands back', async (world) => {
  const user = await seller(world.tx);
  await world.products.create(user, draftBody(await leafCategory(world.tx)));

  const page = (await world.offers.listMine(user, {
    page: 1,
    limit: 20,
    skip: 0,
  } as never)) as {
    data: { id: string; stock: number; product: { title: string } }[];
  };

  assert.equal(page.data.length, 1);
  // The row is an OFFER with its product nested — `id` is the offer's, which
  // is the handle every seller-side mutation is addressed by.
  assert.equal(page.data[0].product.title, 'فستان حرير بماء الورد');
  assert.equal(page.data[0].stock, 12);
});

dbTest('a category above the leaves is refused', async (world) => {
  const user = await seller(world.tx);
  const root = await world.tx.category.findFirst({
    where: { level: 0, isActive: true },
  });
  assert.ok(root, 'the catalogue has no root categories seeded');
  const leaf = await leafCategory(world.tx);

  await assert.rejects(
    () =>
      world.products.create(
        user,
        draftBody({ id: root.id, attributes: leaf.attributes }),
      ),
    'a department is not a shelf, and the form must not offer one',
  );
});
