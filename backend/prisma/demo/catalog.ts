import {
  Currency,
  MediaType,
  OfferStatus,
  Prisma,
  ProductStatus,
} from '@prisma/client';
import {
  BABY_SHOE_SIZES,
  BRANDS,
  CLOTHING_SIZES,
  COLOURS,
  LEAVES,
  SHADES,
  SHOE_SIZES,
  VOLUMES,
  VariantKind,
} from './data';
import { productImage } from './media';
import { Rng, roundSyp } from './rng';
import { DemoContext, DemoOffer, DemoProduct, SYP_PER_USD } from './context';

const D = Prisma.Decimal;

/** Products created per leaf category — 27 leaves × 6 ≈ 160 canonical products. */
const PRODUCTS_PER_LEAF = 6;
const MEDIA_PER_PRODUCT = 3;

function variantNames(kind: VariantKind): string[] {
  switch (kind) {
    case 'clothing':
      return CLOTHING_SIZES;
    case 'shoes':
      return SHOE_SIZES;
    case 'baby-shoes':
      return BABY_SHOE_SIZES;
    case 'shade':
      return SHADES;
    case 'volume':
      return VOLUMES;
    case 'colour':
      return COLOURS.slice(0, 4);
    case 'none':
      return [];
  }
}

/**
 * Splits an offer's stock across its variants.
 *
 * Drawing each variant's stock independently produced offers that looked in
 * stock but whose every size was zero — checkout then refused a cart the seed
 * itself had built. Distributing the offer total instead keeps the two
 * consistent: the variants sum to the offer, and a size only shows as sold out
 * when there is enough stock elsewhere for that to be believable.
 */
function distributeStock(total: number, count: number, rng: Rng): number[] {
  if (count === 0) return [];
  if (total <= 0) return Array.from<number>({ length: count }).fill(0);

  const shares = Array.from({ length: count }, () => rng.float(0.4, 1.6, 3));
  const weight = shares.reduce((sum, share) => sum + share, 0);
  const stocks = shares.map((share) =>
    Math.max(0, Math.round((share / weight) * total)),
  );

  // One sold-out size is realistic; every size sold out on an in-stock offer
  // is not, so the largest bucket always keeps at least one unit.
  if (!stocks.some((value) => value > 0)) {
    stocks[rng.int(0, count - 1)] = total;
  }
  return stocks;
}

function variantAttribute(kind: VariantKind, name: string): Prisma.InputJsonValue {
  switch (kind) {
    case 'clothing':
      return { size: name };
    case 'shoes':
    case 'baby-shoes':
      return { size: name, system: 'EU' };
    case 'shade':
      return { shade: name };
    case 'volume':
      return { volume: name };
    case 'colour':
      return { colour: name };
    case 'none':
      return {};
  }
}

/**
 * Builds the canonical catalog and the per-seller offers on top of it.
 *
 * The central-catalog rule (Q23 P2) is what makes this non-trivial: one
 * `Product` row is the single description of an item, and price, stock and
 * currency live on `SellerOffer`. So the generator picks a "home" boutique for
 * each product and then lets one or two rival boutiques list the same product a
 * few percent cheaper — which is exactly what the price-comparison UI needs to
 * have anything to show.
 */
export async function seedCatalog(ctx: DemoContext): Promise<DemoProduct[]> {
  const { prisma, rng } = ctx;

  const brandIds = [...ctx.brandIds];
  for (const brand of BRANDS) {
    const row = await prisma.brand.create({
      data: {
        ...brand,
        description: `علامة ${brand.nameAr} — منتقاة بعناية على ريم.`,
        logoUrl: productImage('logo,boutique', `brand-${brand.slug}`),
      },
    });
    brandIds.push(row.id);
  }
  ctx.brandIds = brandIds;

  const products: DemoProduct[] = [];
  let sequence = 0;

  for (const [leaf, spec] of Object.entries(LEAVES)) {
    const categoryId = ctx.leafBySlug.get(leaf);
    if (!categoryId) continue;

    // Boutiques that actually stock this leaf, so storefronts stay coherent.
    const specialists = ctx.sellers.filter((seller) =>
      seller.categories.includes(leaf),
    );
    const pool = specialists.length ? specialists : ctx.sellers;

    // Every base × qualifier pair, sampled without replacement — guarantees
    // distinct titles inside a leaf however small the dictionaries are.
    const combinations = spec.bases.flatMap((base) =>
      spec.qualifiers.map((qualifier) => `${base} ${qualifier}`),
    );
    const titles = rng.sample(combinations, PRODUCTS_PER_LEAF);

    for (const [index, title] of titles.entries()) {
      sequence += 1;
      const slug = `${spec.stem}-${String(sequence).padStart(3, '0')}`;
      const owner = pool[index % pool.length];

      const attributes: Record<string, string> = {};
      for (const [key, values] of Object.entries(spec.attributes ?? {})) {
        attributes[key] = rng.pick(values);
      }

      // Popularity is correlated, not independent: a product with many orders
      // also has many views and favourites, so the "trending" and "most loved"
      // collections do not return unrelated noise.
      const popularity = rng.float(0.05, 1, 3);
      const viewsCount = Math.round(400 + popularity * 9_000);
      const ordersCount = Math.round(popularity * rng.int(10, 90));
      const favoritesCount = Math.round(popularity * rng.int(20, 260));
      const likesCount = Math.round(favoritesCount * rng.float(1.2, 2.4));

      const status = rng.weighted<ProductStatus>([
        [ProductStatus.ACTIVE, 24],
        [ProductStatus.DRAFT, 2],
        [ProductStatus.ARCHIVED, 1],
      ]);

      const product = await prisma.product.create({
        data: {
          slug,
          title,
          description: `${title}. ${spec.note}`,
          categoryId,
          brandId: rng.bool(0.85) ? rng.pick(brandIds) : null,
          attributes: attributes as Prisma.InputJsonValue,
          createdBySellerId: owner.id,
          status,
          isFeatured: rng.bool(0.14),
          showInFeed: true,
          viewsCount,
          likesCount,
          ordersCount,
          favoritesCount,
          createdAt: rng.pastDate(240, 1),
          media: {
            create: Array.from({ length: MEDIA_PER_PRODUCT }, (_, i) => ({
              url: productImage(spec.topic, `${slug}-${i}`),
              type: MediaType.image,
              sortOrder: i,
            })),
          },
          variants: {
            create: variantNames(spec.variants).map((name, i) => ({
              name,
              attributes: variantAttribute(spec.variants, name),
              sortOrder: i,
            })),
          },
        },
        include: { media: true, variants: true },
      });

      // ── Offers: the home boutique plus up to two rivals ────────────────
      const basePrice = roundSyp(rng.int(spec.price[0], spec.price[1]));
      const rivals = rng
        .sample(
          ctx.sellers.filter((seller) => seller.id !== owner.id),
          rng.weighted([
            [0, 3],
            [1, 4],
            [2, 2],
          ]),
        )
        .map((seller) => seller);

      const offers: DemoOffer[] = [];
      for (const [offerIndex, seller] of [owner, ...rivals].entries()) {
        // Rivals undercut or overcharge slightly — never by the same amount.
        const factor = offerIndex === 0 ? 1 : rng.float(0.88, 1.12, 3);
        const priceSyp = roundSyp(basePrice * factor);

        // A handful of boutiques price in USD; the SYP roll-up is what the
        // catalog sorts and filters on, so it is normalised here.
        const inUsd = rng.bool(0.07);
        const currency = inUsd ? Currency.USD : Currency.SYP;
        const price = inUsd
          ? Math.round((priceSyp / SYP_PER_USD) * 2) / 2
          : priceSyp;

        const stock = rng.weighted([
          [0, 2],
          [rng.int(1, 6), 4],
          [rng.int(7, 40), 14],
        ]);
        const offerStatus =
          product.status !== ProductStatus.ACTIVE
            ? OfferStatus.DRAFT
            : stock === 0
              ? OfferStatus.OUT_OF_STOCK
              : rng.weighted<OfferStatus>([
                  [OfferStatus.ACTIVE, 22],
                  [OfferStatus.PAUSED, 1],
                ]);

        const variantStocks = distributeStock(
          stock,
          product.variants.length,
          rng,
        );
        const hasCompareAt = rng.bool(0.4);
        const offer = await prisma.sellerOffer.create({
          data: {
            productId: product.id,
            sellerId: seller.id,
            currency,
            price: new D(price),
            compareAtPrice: hasCompareAt
              ? new D(
                  inUsd
                    ? Math.round(price * rng.float(1.15, 1.4, 2) * 2) / 2
                    : roundSyp(price * rng.float(1.15, 1.4, 3)),
                )
              : null,
            wholesalePrice: rng.bool(0.2) ? new D(price * 0.85) : null,
            wholesaleMinQty: rng.bool(0.2) ? 5 : null,
            stock,
            minOrderQty: 1,
            maxOrderQty: rng.bool(0.3) ? rng.int(3, 10) : null,
            sku: `${spec.stem.toUpperCase()}-${sequence}-${offerIndex}`,
            handlingDays: rng.int(1, 4),
            isMadeToOrder: rng.bool(0.08),
            acceptsReturns: !['chocolate', 'candy-boxes', 'perfumes'].includes(
              leaf,
            ),
            status: offerStatus,
            isActive: offerStatus !== OfferStatus.PAUSED,
            createdAt: product.createdAt,
            variants: product.variants.length
              ? {
                  create: product.variants.map((variant, position) => ({
                    variantId: variant.id,
                    stock: variantStocks[position],
                    sku: `${spec.stem.toUpperCase()}-${sequence}-${offerIndex}-${variant.name}`,
                  })),
                }
              : undefined,
          },
          include: { variants: true },
        });

        // Perishables and cosmetics carry batch/expiry tracking (Q60 P1).
        if (
          ['chocolate', 'candy-boxes', 'bouquets', 'baby-skincare'].includes(
            leaf,
          ) &&
          stock > 0
        ) {
          await prisma.inventoryBatch.create({
            data: {
              offerId: offer.id,
              batchRef: `B-${sequence}-${offerIndex}`,
              quantity: stock,
              expiresAt: rng.futureDate(180, 20),
              alertDays: 30,
            },
          });
        }

        offers.push({
          id: offer.id,
          live:
            offerStatus === OfferStatus.ACTIVE &&
            offer.isActive &&
            stock > 0,
          sellerId: seller.id,
          sellerName: seller.name,
          price,
          currency: currency === Currency.USD ? 'USD' : 'SYP',
          priceSyp,
          stock,
          // Only the sizes a customer could actually buy — carts and orders
          // draw from this list.
          variants: product.variants
            .map((variant, position) => ({
              id: offer.variants.find((v) => v.variantId === variant.id)!.id,
              name: variant.name,
              stock: variantStocks[position],
            }))
            .filter((variant) => variant.stock > 0),
        });
      }

      // ── Roll-ups over the live offers ─────────────────────────────────
      const live = offers.filter((offer) => offer.live);
      const priced = live.length ? live : offers;
      await prisma.product.update({
        where: { id: product.id },
        data: {
          offersCount: live.length,
          minPriceSyp: new D(Math.min(...priced.map((o) => o.priceSyp))),
          maxPriceSyp: new D(Math.max(...priced.map((o) => o.priceSyp))),
        },
      });

      if (status === ProductStatus.ACTIVE) {
        products.push({
          id: product.id,
          slug,
          title,
          leaf,
          imageUrl: product.media[0].url,
          offers: live.slice().sort((a, b) => a.priceSyp - b.priceSyp),
        });
      }
    }
  }

  return products;
}
