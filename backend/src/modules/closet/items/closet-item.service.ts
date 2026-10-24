import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  ClosetItem,
  ClosetItemSource,
  ClosetItemStatus,
  ClosetSeason,
  OutfitSlot,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { MediaService } from '../../media/media.service';
import { ClosetService } from '../closet.service';
import {
  DescriptorOverrides,
  describeCatalogGarment,
  describePersonalGarment,
  sanitiseDescriptorOverrides,
} from './garment-descriptor';

/** How a catalog piece is loaded when we need to describe it. */
const PRODUCT_FOR_DESCRIPTOR = {
  category: true,
  media: { orderBy: { sortOrder: 'asc' as const }, take: 1 },
} satisfies Prisma.ProductInclude;

export interface ListItemsFilter {
  slot?: OutfitSlot;
  status?: ClosetItemStatus;
  season?: ClosetSeason;
  occasion?: string;
  colour?: string;
  favouritesOnly?: boolean;
  search?: string;
  limit?: number;
  cursor?: string;
}

/**
 * Adding, editing and wearing the things she owns.
 *
 * Two entry points create a row — `addFromCatalog` and `addPersonal` — and the
 * only difference between what they produce is provenance. Both run the
 * descriptor, both store the result, and from the next line of code onwards
 * nothing distinguishes them. That symmetry is the feature; it is also the
 * thing most likely to be eroded by a later change, so it is worth saying: any
 * behaviour added to one of these two methods and not the other should be
 * treated as a bug until argued otherwise.
 */
@Injectable()
export class ClosetItemService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly closet: ClosetService,
    private readonly media: MediaService,
  ) {}

  // ── Reading ───────────────────────────────────────────────────────────

  async list(userId: string, filter: ListItemsFilter = {}) {
    const closet = await this.closet.findOrCreate(userId);
    const limit = Math.min(filter.limit ?? 40, 100);

    const where: Prisma.ClosetItemWhereInput = {
      closetId: closet.id,
      status: filter.status ?? ClosetItemStatus.ACTIVE,
      ...(filter.slot ? { slot: filter.slot } : {}),
      ...(filter.occasion ? { occasions: { has: filter.occasion } } : {}),
      ...(filter.colour ? { colours: { has: filter.colour } } : {}),
      ...(filter.favouritesOnly ? { isFavourite: true } : {}),
      // `ALL` is stored explicitly, so a seasonal filter has to admit it or a
      // handbag disappears from the winter view.
      ...(filter.season
        ? { seasons: { hasSome: [filter.season, ClosetSeason.ALL] } }
        : {}),
      ...(filter.search
        ? {
            OR: [
              { title: { contains: filter.search, mode: 'insensitive' } },
              { brandName: { contains: filter.search, mode: 'insensitive' } },
              { note: { contains: filter.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const rows = await this.prisma.closetItem.findMany({
      where,
      include: { product: { include: PRODUCT_FOR_DESCRIPTOR }, brand: true },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(filter.cursor ? { cursor: { id: filter.cursor }, skip: 1 } : {}),
    });

    return {
      items: rows.slice(0, limit),
      nextCursor: rows.length > limit ? rows[limit - 1].id : null,
    };
  }

  async require(userId: string, itemId: string): Promise<ClosetItem> {
    const item = await this.prisma.closetItem.findFirst({
      where: { id: itemId, userId },
    });
    if (!item) throw new NotFoundException('Closet item not found');
    return item;
  }

  async detail(userId: string, itemId: string) {
    await this.require(userId, itemId);
    return this.prisma.closetItem.findUnique({
      where: { id: itemId },
      include: {
        product: { include: PRODUCT_FOR_DESCRIPTOR },
        brand: true,
        wears: { orderBy: { wornOn: 'desc' }, take: 30 },
        lookItems: { include: { look: true } },
      },
    });
  }

  /** Which of these products she already owns — for the product page. */
  async ownedProductIds(userId: string, productIds: readonly string[]) {
    if (!productIds.length) return new Set<string>();
    const rows = await this.prisma.closetItem.findMany({
      where: {
        userId,
        productId: { in: [...productIds] },
        status: { not: ClosetItemStatus.RELEASED },
      },
      select: { productId: true },
    });
    return new Set(rows.map((row) => row.productId).filter((id): id is string => !!id));
  }

  // ── Adding ────────────────────────────────────────────────────────────

  /**
   * She owns this Ohara product.
   *
   * Idempotent on (product, variant): tapping "أضيفي لخزانتي" twice is one
   * garment. Enforced in code rather than by a unique index because a woman may
   * legitimately own two of the same dress in different sizes — the variant is
   * part of the identity, and a null variant should not collide with a real one
   * the way a database unique constraint would let it.
   */
  async addFromCatalog(
    userId: string,
    input: {
      productId: string;
      offerId?: string | null;
      variantId?: string | null;
      overrides?: DescriptorOverrides;
      note?: string | null;
      acquiredAt?: Date | null;
      purchasePriceSyp?: number | null;
    },
  ): Promise<ClosetItem> {
    const closet = await this.closet.findOrCreate(userId);

    const existing = await this.prisma.closetItem.findFirst({
      where: {
        closetId: closet.id,
        productId: input.productId,
        variantId: input.variantId ?? null,
        status: { not: ClosetItemStatus.RELEASED },
      },
    });
    if (existing) return existing;

    const product = await this.prisma.product.findUnique({
      where: { id: input.productId },
      include: PRODUCT_FOR_DESCRIPTOR,
    });
    if (!product) throw new NotFoundException('Product not found');

    const variant = input.variantId
      ? await this.prisma.productVariant.findFirst({
          where: { id: input.variantId, productId: product.id },
        })
      : null;

    const offer = input.offerId
      ? await this.prisma.sellerOffer.findFirst({
          where: { id: input.offerId, productId: product.id },
        })
      : null;

    const descriptor = describeCatalogGarment(
      {
        categorySlug: product.category.slug,
        title: product.title,
        description: product.description,
        attributes: product.attributes as Record<string, unknown> | null,
        variantAttributes: variant?.attributes as Record<string, unknown> | null,
        variantName: variant?.name ?? null,
      },
      sanitiseDescriptorOverrides(input.overrides ?? {}),
    );

    const item = await this.prisma.closetItem.create({
      data: {
        closetId: closet.id,
        userId,
        source: ClosetItemSource.CATALOG,
        productId: product.id,
        offerId: offer?.id ?? null,
        variantId: variant?.id ?? null,
        // Snapshotted, not joined. A seller renaming or delisting the product
        // must not empty a row in her wardrobe.
        title: product.title,
        imageUrl: variant?.imageUrl ?? product.media[0]?.url ?? null,
        blurHash: product.media[0]?.blurHash ?? null,
        brandId: product.brandId,
        purchasePriceSyp:
          input.purchasePriceSyp ??
          (offer?.priceSyp ? Number(offer.priceSyp) : null) ??
          (product.minPriceSyp ? Number(product.minPriceSyp) : null),
        acquiredAt: input.acquiredAt ?? new Date(),
        note: input.note ?? null,
        ...descriptor,
      },
    });

    await this.closet.refreshCounts(closet.id);
    return item;
  }

  /**
   * A garment of her own.
   *
   * `slot` is required here where it is derived for a catalog piece, and the
   * asymmetry is deliberate: a product has a category to fall back on, a
   * photograph has nothing. Guessing from a title like "الجاكيت الأزرق" is a
   * bonus, not a foundation, and a piece filed in the wrong slot is worse than
   * one she was asked a single question about — it will quietly distort every
   * gap and every outfit from then on.
   */
  async addPersonal(
    userId: string,
    input: {
      title: string;
      slot: OutfitSlot;
      imageUrl?: string | null;
      overrides?: DescriptorOverrides;
      brandName?: string | null;
      note?: string | null;
      acquiredAt?: Date | null;
      purchasePriceSyp?: number | null;
    },
  ): Promise<ClosetItem> {
    const title = input.title.trim();
    if (!title) throw new BadRequestException('Title is required');

    const closet = await this.closet.findOrCreate(userId);

    const descriptor = describePersonalGarment(
      { title, note: input.note },
      { ...sanitiseDescriptorOverrides(input.overrides ?? {}), slot: input.slot },
    );

    const item = await this.prisma.closetItem.create({
      data: {
        closetId: closet.id,
        userId,
        source: ClosetItemSource.PERSONAL,
        title,
        imageUrl: input.imageUrl ?? null,
        brandName: input.brandName?.trim() || null,
        note: input.note ?? null,
        acquiredAt: input.acquiredAt ?? null,
        purchasePriceSyp: input.purchasePriceSyp ?? null,
        ...descriptor,
      },
    });

    // Claim the photograph now the row exists, so the orphan sweeper stops
    // considering it abandoned. Forgiving by design — see `markAttached`.
    if (input.imageUrl) await this.media.markAttached(userId, [input.imageUrl]);

    await this.closet.refreshCounts(closet.id);
    return item;
  }

  /**
   * A delivered line becomes a garment.
   *
   * The one moment Ohara knows for certain she owns something, which is why the
   * closet fills itself from here rather than from an order being placed. The
   * `orderItemId` unique index makes a replayed delivery event a no-op, so this
   * is safe to call from an event handler that may fire more than once.
   */
  async addFromOrderItem(
    userId: string,
    orderItemId: string,
  ): Promise<ClosetItem | null> {
    const line = await this.prisma.orderItem.findUnique({
      where: { id: orderItemId },
      include: { product: { include: PRODUCT_FOR_DESCRIPTOR } },
    });
    if (!line?.product) return null;

    const closet = await this.closet.findOrCreate(userId);

    // `OrderItem.variantId` is an unconstrained column, and its writers do not
    // agree about what it holds: checkout stores the `ProductVariant` behind the
    // offer variant, while other paths store the `SellerOfferVariant` itself.
    // Every seeded line in the database is the second kind.
    //
    // The closet cannot copy that id blindly, because `ClosetItem.variantId`
    // *is* constrained — pointing at `ProductVariant` — so an offer-variant id
    // failed the foreign key and took the whole intake down with it. Since this
    // is the path that puts a delivered order into her wardrobe, that meant the
    // feature's headline promise silently failed for every garment sold in a
    // size.
    //
    // So: resolve it, accepting either meaning, and keep only what resolved.
    const variant = await this.resolveVariant(line.variantId);

    const descriptor = describeCatalogGarment({
      categorySlug: line.product.category.slug,
      title: line.product.title,
      description: line.product.description,
      attributes: line.product.attributes as Record<string, unknown> | null,
      variantAttributes: variant?.attributes as Record<string, unknown> | null,
      variantName: variant?.name ?? line.variantSnapshot,
    });

    try {
      const item = await this.prisma.closetItem.create({
        data: {
          closetId: closet.id,
          userId,
          source: ClosetItemSource.PURCHASE,
          orderItemId: line.id,
          productId: line.productId,
          offerId: line.offerId,
          // The resolved id, never the raw one — see `resolveVariant`.
          variantId: variant?.id ?? null,
          // The order's snapshot, not the live product: this is what she was
          // sold, and the order page and the closet must agree about it.
          title: line.titleSnapshot,
          imageUrl: line.imageSnapshot ?? line.product.media[0]?.url ?? null,
          blurHash: line.product.media[0]?.blurHash ?? null,
          brandId: line.product.brandId,
          purchasePriceSyp: line.product.minPriceSyp
            ? Number(line.product.minPriceSyp)
            : null,
          acquiredAt: new Date(),
          ...descriptor,
        },
      });
      await this.closet.refreshCounts(closet.id);
      return item;
    } catch (error) {
      // A redelivered order racing itself. The unique index is the arbiter and
      // the loser has nothing to report.
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        return null;
      }
      throw error;
    }
  }

  // ── Editing ───────────────────────────────────────────────────────────

  async update(
    userId: string,
    itemId: string,
    patch: {
      title?: string;
      imageUrl?: string | null;
      brandName?: string | null;
      note?: string | null;
      size?: string | null;
      isFavourite?: boolean;
      acquiredAt?: Date | null;
      purchasePriceSyp?: number | null;
      overrides?: DescriptorOverrides;
    },
  ): Promise<ClosetItem> {
    await this.require(userId, itemId);
    const overrides = sanitiseDescriptorOverrides(patch.overrides ?? {});

    if (patch.imageUrl) await this.media.markAttached(userId, [patch.imageUrl]);

    return this.prisma.closetItem.update({
      where: { id: itemId },
      data: {
        ...(patch.title !== undefined ? { title: patch.title.trim() } : {}),
        ...(patch.imageUrl !== undefined ? { imageUrl: patch.imageUrl } : {}),
        ...(patch.brandName !== undefined
          ? { brandName: patch.brandName?.trim() || null }
          : {}),
        ...(patch.note !== undefined ? { note: patch.note } : {}),
        ...(patch.isFavourite !== undefined ? { isFavourite: patch.isFavourite } : {}),
        ...(patch.acquiredAt !== undefined ? { acquiredAt: patch.acquiredAt } : {}),
        ...(patch.purchasePriceSyp !== undefined
          ? { purchasePriceSyp: patch.purchasePriceSyp }
          : {}),
        // Her correction wins outright and is stored, not merged: re-deriving
        // afterwards would hand the guess back the field she just fixed.
        ...(overrides.slot !== undefined ? { slot: overrides.slot } : {}),
        ...(overrides.colours !== undefined ? { colours: overrides.colours } : {}),
        ...(overrides.materials !== undefined ? { materials: overrides.materials } : {}),
        ...(overrides.modesty !== undefined ? { modesty: overrides.modesty } : {}),
        ...(overrides.seasons !== undefined ? { seasons: overrides.seasons } : {}),
        ...(overrides.occasions !== undefined ? { occasions: overrides.occasions } : {}),
        ...(patch.size !== undefined
          ? { size: patch.size?.trim() || null }
          : overrides.size !== undefined
            ? { size: overrides.size }
            : {}),
      },
    });
  }

  async setStatus(
    userId: string,
    itemId: string,
    status: ClosetItemStatus,
  ): Promise<ClosetItem> {
    const item = await this.require(userId, itemId);
    const updated = await this.prisma.closetItem.update({
      where: { id: itemId },
      data: { status },
    });
    await this.closet.refreshCounts(item.closetId);
    return updated;
  }

  /**
   * Delete, properly.
   *
   * Offered alongside `RELEASED` because they are different requests: releasing
   * says "I no longer own this" and keeps the history, deleting says "this was
   * never right". A wardrobe log that cannot be corrected stops being kept.
   */
  async remove(userId: string, itemId: string): Promise<void> {
    const item = await this.require(userId, itemId);
    await this.prisma.closetItem.delete({ where: { id: itemId } });
    await this.closet.refreshCounts(item.closetId);
  }

  // ── Wearing ───────────────────────────────────────────────────────────

  /**
   * She wore this today.
   *
   * The counter and the row move together in one transaction, and the unique
   * index on (item, day) makes a second tap idempotent rather than a second
   * wear. `wearCount` is recounted from the rows instead of incremented — an
   * increment beside a conflicting insert is how a counter and its table start
   * disagreeing.
   */
  async logWear(userId: string, itemId: string, wornOn?: Date): Promise<ClosetItem> {
    await this.require(userId, itemId);
    const day = startOfDay(wornOn ?? new Date());

    return this.prisma.$transaction(async (tx) => {
      await tx.closetItemWear.upsert({
        where: { itemId_wornOn: { itemId, wornOn: day } },
        create: { itemId, wornOn: day },
        update: {},
      });

      const [wearCount, latest] = await Promise.all([
        tx.closetItemWear.count({ where: { itemId } }),
        tx.closetItemWear.findFirst({
          where: { itemId },
          orderBy: { wornOn: 'desc' },
        }),
      ]);

      return tx.closetItem.update({
        where: { id: itemId },
        data: { wearCount, lastWornAt: latest?.wornOn ?? null },
      });
    });
  }

  async removeWear(userId: string, itemId: string, wornOn: Date): Promise<ClosetItem> {
    await this.require(userId, itemId);
    const day = startOfDay(wornOn);

    return this.prisma.$transaction(async (tx) => {
      await tx.closetItemWear.deleteMany({ where: { itemId, wornOn: day } });
      const [wearCount, latest] = await Promise.all([
        tx.closetItemWear.count({ where: { itemId } }),
        tx.closetItemWear.findFirst({ where: { itemId }, orderBy: { wornOn: 'desc' } }),
      ]);
      return tx.closetItem.update({
        where: { id: itemId },
        data: { wearCount, lastWornAt: latest?.wornOn ?? null },
      });
    });
  }

  /**
   * An order line's variant id, whichever of the two things it means.
   *
   * Tried as a `ProductVariant` first and as a `SellerOfferVariant` second,
   * because only the first is what the closet is allowed to store. A dangling
   * id resolves to null rather than throwing: a garment whose variant row has
   * since been deleted is still a garment she owns, and refusing to put it in
   * her closet over a missing size would be the wrong trade.
   */
  private async resolveVariant(
    variantId: string | null,
  ): Promise<{ id: string; name: string | null; attributes: unknown } | null> {
    if (!variantId) return null;

    const direct = await this.prisma.productVariant.findUnique({
      where: { id: variantId },
    });
    if (direct) return direct;

    const viaOffer = await this.prisma.sellerOfferVariant.findUnique({
      where: { id: variantId },
      include: { variant: true },
    });
    return viaOffer?.variant ?? null;
  }
}

/**
 * Midnight UTC.
 *
 * `wornOn` is a `@db.Date`, and Postgres reads the date part of whatever
 * instant it is handed. Normalising here rather than trusting the client keeps
 * the unique index meaningful: without it, two taps from phones in different
 * time zones are two rows for one Thursday.
 */
export function startOfDay(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
}
