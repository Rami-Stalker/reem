import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  ClosetItemStatus,
  OfferStatus,
  OutfitSlot,
  Prisma,
  ProductStatus,
  ResaleCondition,
  ResaleStatus,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { GraphQueryService } from '../../graph/graph-query.service';
import {
  Disposition,
  ItemLife,
  LifeReading,
  readLife,
  suggestResalePrice,
} from '../kernel/lifecycle';

const DAY_MS = 24 * 60 * 60 * 1000;

/** Which dispositions are worth putting in front of her, and in what order. */
const ATTENTION_ORDER: Disposition[] = ['RESELL', 'DONATE', 'RESTYLE'];

/**
 * Ohara Life Cycle, and the resale market that grows out of it.
 *
 * The closet already knows what she owns and when she last wore it; the graph
 * already knows what goes with what. This service adds no facts. It reads
 * those two and answers one question per garment — keep it, wear it
 * differently, sell it, or give it away — and then, only if she says yes,
 * turns the last two into a listing.
 *
 * ── Why resale is a separate surface ─────────────────────────────────────
 *
 * Because a used dress and a boutique's new one answer different questions,
 * and putting them in the same grid degrades both: the boutique loses the
 * frame that justifies its price, and the used piece loses the context that
 * makes its price a bargain rather than a discount. So resale listings never
 * enter product search, never join the catalogue rollups, and live in their
 * own read path. The marketplace is untouched, which was the constraint.
 */
@Injectable()
export class LifecycleService {
  private readonly logger = new Logger(LifecycleService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly graph: GraphQueryService,
  ) {}

  /**
   * The season we are judging in.
   *
   * Syria's calendar, not a hemisphere-agnostic abstraction — this is the only
   * place the answer is needed and inventing a configuration layer for it
   * would be a file nobody reads.
   */
  private currentSeason(now = new Date()): string {
    const month = now.getMonth() + 1;
    if (month >= 6 && month <= 9) return 'SUMMER';
    if (month === 12 || month <= 3) return 'WINTER';
    return 'TRANSITIONAL';
  }

  private daysBetween(from: Date | null, now: Date): number | null {
    if (!from) return null;
    return Math.max(0, Math.floor((now.getTime() - from.getTime()) / DAY_MS));
  }

  /**
   * Every piece she owns, read.
   *
   * `ARCHIVED` items are excluded: she has already told us it is out of
   * rotation, and advising her about a coat she put away for the summer is the
   * exact nagging this feature is built to avoid.
   */
  async wardrobe(userId: string, now = new Date()) {
    const items = await this.prisma.closetItem.findMany({
      where: { userId, status: ClosetItemStatus.ACTIVE },
      select: {
        id: true,
        title: true,
        slot: true,
        imageUrl: true,
        blurHash: true,
        materials: true,
        seasons: true,
        wearCount: true,
        lastWornAt: true,
        acquiredAt: true,
        createdAt: true,
        purchasePriceSyp: true,
        isFavourite: true,
        productId: true,
        resaleListing: { select: { id: true, status: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    const season = this.currentSeason(now);

    return items.map((item) => {
      const facts: ItemLife = {
        slot: item.slot,
        materials: item.materials,
        seasons: item.seasons,
        wearCount: item.wearCount,
        daysSinceWorn: this.daysBetween(item.lastWornAt, now),
        // Falls back to when it entered the closet, which for a delivered
        // order is the delivery date — close enough to be honest, and better
        // than reporting an unknown age for every piece she never dated.
        daysOwned: this.daysBetween(item.acquiredAt ?? item.createdAt, now),
        purchasePriceSyp: item.purchasePriceSyp
          ? Number(item.purchasePriceSyp)
          : null,
        isFavourite: item.isFavourite,
      };

      return {
        item,
        reading: readLife(facts, season),
      };
    });
  }

  /**
   * The short list: pieces that actually need her attention.
   *
   * Capped hard. A screen with forty suggestions on it is a chore, and the
   * whole feature dies the first time it feels like one.
   */
  async attention(userId: string, limit = 6, now = new Date()) {
    const wardrobe = await this.wardrobe(userId, now);

    const worth = wardrobe.filter(
      (row) =>
        row.reading.disposition !== 'KEEP' &&
        // Already listed — nothing left to advise.
        (!row.item.resaleListing ||
          row.item.resaleListing.status === ResaleStatus.WITHDRAWN),
    );

    worth.sort((a, b) => {
      const rank =
        ATTENTION_ORDER.indexOf(a.reading.disposition) -
        ATTENTION_ORDER.indexOf(b.reading.disposition);
      if (rank !== 0) return rank;
      return b.reading.confidence - a.reading.confidence;
    });

    const chosen = worth.slice(0, limit);

    // A RESTYLE with nothing to restyle it *with* is a scolding. Fetch the
    // graph's complements for those, and only those.
    const restyle = chosen.filter(
      (row) => row.reading.disposition === 'RESTYLE' && row.item.productId,
    );
    const styleWith = new Map<string, Array<{ id: string; title: string }>>();

    for (const row of restyle) {
      const ids = await this.graph.complements(row.item.productId as string, 3);
      if (!ids.length) continue;
      const products = await this.prisma.product.findMany({
        where: {
          id: { in: ids },
          status: ProductStatus.ACTIVE,
          offers: { some: { status: OfferStatus.ACTIVE, stock: { gt: 0 } } },
        },
        select: { id: true, title: true },
      });
      if (products.length) styleWith.set(row.item.id, products);
    }

    return chosen.map((row) => ({
      ...row,
      styleWith: styleWith.get(row.item.id) ?? [],
      // Only offered where it is the advice; a price beside a "wear it again"
      // note would read as a push to sell.
      suggestedPriceSyp:
        row.reading.disposition === 'RESELL'
          ? suggestResalePrice(
              row.item.purchasePriceSyp ? Number(row.item.purchasePriceSyp) : null,
              ResaleCondition.EXCELLENT,
            )
          : null,
    }));
  }

  /** One piece, read on its own — for the closet item screen. */
  async readItem(userId: string, closetItemId: string, now = new Date()) {
    const rows = await this.wardrobe(userId, now);
    const row = rows.find((entry) => entry.item.id === closetItemId);
    if (!row) throw new NotFoundException('Closet item not found');

    return {
      ...row,
      suggestedPriceSyp: suggestResalePrice(
        row.item.purchasePriceSyp ? Number(row.item.purchasePriceSyp) : null,
        ResaleCondition.EXCELLENT,
      ),
    };
  }

  // ── Resale ────────────────────────────────────────────────────────────

  /**
   * Put a wardrobe piece up for sale.
   *
   * Created as a DRAFT: writing a listing and publishing it are two decisions,
   * and collapsing them means a woman who tapped to see what her dress is
   * worth has accidentally offered it to strangers.
   */
  async list(
    userId: string,
    closetItemId: string,
    input: {
      condition: ResaleCondition;
      priceSyp?: number;
      title?: string;
      note?: string;
    },
  ) {
    const item = await this.prisma.closetItem.findUnique({
      where: { id: closetItemId },
      select: {
        id: true,
        userId: true,
        title: true,
        status: true,
        productId: true,
        purchasePriceSyp: true,
        resaleListing: { select: { id: true, status: true } },
      },
    });
    if (!item) throw new NotFoundException('Closet item not found');
    if (item.userId !== userId) throw new NotFoundException('Closet item not found');
    if (item.status === ClosetItemStatus.RELEASED) {
      throw new BadRequestException('This piece has already left your closet');
    }

    const original = item.purchasePriceSyp ? Number(item.purchasePriceSyp) : null;
    const price =
      input.priceSyp ?? suggestResalePrice(original, input.condition) ?? null;
    if (price === null || price <= 0) {
      // We do not know what she paid and she did not say what she wants, so
      // there is no honest number to write down.
      throw new BadRequestException('A price is required for this piece');
    }

    const existing = item.resaleListing;
    if (existing && existing.status === ResaleStatus.SOLD) {
      throw new BadRequestException('This piece has already been sold');
    }

    const data = {
      sellerId: userId,
      productId: item.productId,
      title: input.title?.trim() || item.title,
      note: input.note?.trim() || null,
      condition: input.condition,
      status: ResaleStatus.DRAFT,
      priceSyp: new Prisma.Decimal(price),
      originalPriceSyp:
        original !== null ? new Prisma.Decimal(original) : null,
    };

    // Returned with the piece attached, so the sheet she is looking at can
    // render the photograph and the slot it just wrote a price for.
    return this.prisma.resaleListing.upsert({
      where: { closetItemId },
      create: { closetItemId, ...data },
      // Re-drafting a piece she withdrew resets its clock. Without this the
      // draft comes back carrying the date it was published the first time,
      // which is a field saying "listed at" on something that is not listed.
      update: { ...data, listedAt: null, soldAt: null },
      include: {
        closetItem: {
          select: {
            id: true,
            slot: true,
            imageUrl: true,
            blurHash: true,
            colours: true,
            materials: true,
            size: true,
            brandName: true,
            wearCount: true,
          },
        },
      },
    });
  }

  /**
   * Move a listing along.
   *
   * Publishing archives the closet item, because a piece being sold is out of
   * rotation and should stop appearing in her looks and her gaps. Withdrawing
   * puts it back. Selling releases it — the closet keeps the row so
   * cost-per-wear and replacement gaps survive the sale, which is exactly what
   * `RELEASED` was built for.
   */
  async setStatus(userId: string, listingId: string, status: ResaleStatus) {
    const listing = await this.prisma.resaleListing.findUnique({
      where: { id: listingId },
      select: { id: true, sellerId: true, status: true, closetItemId: true },
    });
    if (!listing) throw new NotFoundException('Listing not found');
    if (listing.sellerId !== userId) throw new NotFoundException('Listing not found');

    const allowed: Record<ResaleStatus, ResaleStatus[]> = {
      [ResaleStatus.DRAFT]: [ResaleStatus.LISTED, ResaleStatus.WITHDRAWN],
      [ResaleStatus.LISTED]: [
        ResaleStatus.RESERVED,
        ResaleStatus.SOLD,
        ResaleStatus.WITHDRAWN,
      ],
      [ResaleStatus.RESERVED]: [ResaleStatus.SOLD, ResaleStatus.LISTED],
      [ResaleStatus.SOLD]: [],
      [ResaleStatus.WITHDRAWN]: [ResaleStatus.LISTED],
    };

    if (!allowed[listing.status].includes(status)) {
      throw new BadRequestException(
        `Cannot move a ${listing.status} listing to ${status}`,
      );
    }

    const closetStatus =
      status === ResaleStatus.SOLD
        ? ClosetItemStatus.RELEASED
        : status === ResaleStatus.LISTED || status === ResaleStatus.RESERVED
          ? ClosetItemStatus.ARCHIVED
          : ClosetItemStatus.ACTIVE;

    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.resaleListing.update({
        where: { id: listingId },
        data: {
          status,
          ...(status === ResaleStatus.LISTED ? { listedAt: new Date() } : {}),
          ...(status === ResaleStatus.SOLD ? { soldAt: new Date() } : {}),
        },
      include: {
        closetItem: {
          select: {
            id: true,
            slot: true,
            imageUrl: true,
            blurHash: true,
            colours: true,
            materials: true,
            size: true,
            brandName: true,
            wearCount: true,
          },
        },
      },
      });

      await tx.closetItem.update({
        where: { id: listing.closetItemId },
        data: { status: closetStatus },
      });

      return updated;
    });
  }

  /** Her own listings. */
  async mine(userId: string) {
    return this.prisma.resaleListing.findMany({
      where: { sellerId: userId },
      orderBy: { updatedAt: 'desc' },
      include: {
        closetItem: {
          select: {
            id: true,
            imageUrl: true,
            blurHash: true,
            slot: true,
            wearCount: true,
          },
        },
      },
    });
  }

  /**
   * The resale market, as a shopper sees it.
   *
   * Its own read path, deliberately. Nothing here touches product search.
   */
  async market(options: { slot?: string; limit?: number; viewerId?: string } = {}) {
    const listings = await this.prisma.resaleListing.findMany({
      where: {
        status: ResaleStatus.LISTED,
        ...(options.viewerId ? { sellerId: { not: options.viewerId } } : {}),
        ...(options.slot ? { closetItem: { slot: options.slot as OutfitSlot } } : {}),
      },
      orderBy: { listedAt: 'desc' },
      take: options.limit ?? 24,
      include: {
        closetItem: {
          select: {
            id: true,
            slot: true,
            imageUrl: true,
            blurHash: true,
            colours: true,
            materials: true,
            size: true,
            brandName: true,
            // How many times she wore it. The one fact a second-hand
            // marketplace normally hides and the one a buyer most wants.
            wearCount: true,
          },
        },
        seller: { select: { id: true, name: true } },
        product: { select: { id: true, title: true } },
      },
    });

    return listings.map((listing) => {
      const original = listing.originalPriceSyp
        ? Number(listing.originalPriceSyp)
        : null;
      const price = Number(listing.priceSyp);
      return {
        listing,
        // The one number that makes a used piece legible: what it saves
        // against what it cost new. Null rather than invented when unknown.
        savingBps:
          original && original > price
            ? Math.round(((original - price) / original) * 10000)
            : null,
      };
    });
  }

  async detail(listingId: string) {
    const listing = await this.prisma.resaleListing.findUnique({
      where: { id: listingId },
      include: {
        closetItem: {
          select: {
            id: true,
            slot: true,
            imageUrl: true,
            blurHash: true,
            colours: true,
            materials: true,
            size: true,
            brandName: true,
            wearCount: true,
          },
        },
        seller: { select: { id: true, name: true } },
        product: { select: { id: true, title: true } },
      },
    });
    if (!listing) throw new NotFoundException('Listing not found');
    if (listing.status === ResaleStatus.DRAFT) {
      throw new ForbiddenException('This listing is not published');
    }
    return listing;
  }

  /**
   * Reading of a whole wardrobe, for the closet header.
   *
   * Deliberately three numbers. A wardrobe is not a portfolio and does not
   * want a dashboard.
   */
  async summary(userId: string, now = new Date()) {
    const wardrobe = await this.wardrobe(userId, now);
    const worn = wardrobe.filter((row) => row.item.wearCount > 0);
    const costed = wardrobe.filter((row) => row.reading.costPerWear !== null);

    return {
      items: wardrobe.length,
      // Actually worn, not merely un-judged. A wardrobe of nine pieces she has
      // not worn yet reads as "9 in rotation" under the rotation state alone,
      // because a new piece is correctly ACTIVE — and "9 in rotation, 0% worn"
      // is a pair of numbers that contradict each other on the same line.
      inRotation: wardrobe.filter(
        (row) => row.reading.rotation === 'ACTIVE' && row.item.wearCount > 0,
      ).length,
      needsAttention: wardrobe.filter(
        (row) => row.reading.disposition !== 'KEEP',
      ).length,
      wornShare: wardrobe.length
        ? Math.round((worn.length / wardrobe.length) * 100)
        : 0,
      medianCostPerWear: costed.length
        ? median(costed.map((row) => row.reading.costPerWear as number))
        : null,
    };
  }
}

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  const value =
    sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  return Math.round(value * 100) / 100;
}
