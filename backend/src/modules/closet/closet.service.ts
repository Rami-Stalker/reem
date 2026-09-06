import { Injectable } from '@nestjs/common';
import { Closet, ClosetItemStatus, ClosetSeason, OutfitSlot, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  ClosetItemFact,
  ClosetLookFact,
  ClosetSnapshot,
  SlotCounts,
  outfitCapacity,
} from './gaps/gap-engine';
import { seasonOf } from './items/garment-descriptor';

/**
 * The closet itself: the row, and the snapshot every engine reads.
 *
 * Three features — gaps, suggestions, and the daily pick — all need the same
 * view of her wardrobe, and all three are pure functions that must not touch a
 * database. So the reading happens once, here, and produces the plain
 * `ClosetSnapshot` value they consume. Letting each engine fetch its own would
 * mean three subtly different definitions of "her active pieces", and they
 * would drift the first time one of them gained a filter.
 */
@Injectable()
export class ClosetService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Her closet, created on first touch.
   *
   * Lazy rather than provisioned at signup: a row per registered woman whether
   * or not she ever opens the feature is a table that mostly describes people
   * who are not using it. `upsert` rather than find-then-create because two
   * concurrent first requests are ordinary — she taps the tab and a background
   * refresh fires — and the unique index should settle that, not a race.
   */
  async findOrCreate(userId: string): Promise<Closet> {
    try {
      return await this.prisma.closet.upsert({
        where: { userId },
        create: { userId },
        update: {},
      });
    } catch (error) {
      // `upsert` is not atomic against a concurrent insert of the same row:
      // both callers see no row, both attempt the INSERT, and the loser hits
      // the unique index. It is not a rare race either — the closet's own
      // front page runs `overview()` and `gaps.list()` in one `Promise.all`,
      // and both open the closet, so the very first time a woman opened the
      // tab she got a 409.
      //
      // The winner has by definition committed the row we wanted, so the
      // correct recovery is simply to read it.
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        return this.prisma.closet.findUniqueOrThrow({ where: { userId } });
      }
      throw error;
    }
  }

  /**
   * Everything the engines reason over, in two queries.
   *
   * Only ACTIVE items. Archived pieces are hers but out of rotation, and
   * counting them would have the closet propose outfits from the winter coats
   * she has packed away.
   */
  async snapshot(
    userId: string,
    options: { now?: Date } = {},
  ): Promise<ClosetSnapshot> {
    const now = options.now ?? new Date();
    const closet = await this.findOrCreate(userId);

    const [items, looks, preference, dismissed] = await Promise.all([
      this.prisma.closetItem.findMany({
        where: { closetId: closet.id, status: ClosetItemStatus.ACTIVE },
        orderBy: [{ slot: 'asc' }, { createdAt: 'asc' }],
      }),
      this.prisma.closetLook.findMany({
        where: { closetId: closet.id, isArchived: false },
        include: { items: true },
        orderBy: { updatedAt: 'desc' },
      }),
      this.prisma.userStylePreference.findUnique({ where: { userId } }),
      this.prisma.closetGap.findMany({
        where: { closetId: closet.id, status: 'DISMISSED' },
        select: { fingerprint: true },
      }),
    ]);

    return {
      items: items.map(toItemFact),
      looks: looks.map(toLookFact),
      now,
      season: seasonOf(now),
      // Stated band first, then the one her orders revealed. Same precedence
      // the stylist's profile uses: she knows her budget better than her
      // history does.
      typicalBudgetSyp: preference
        ? {
            min: decimal(preference.budgetMinSyp ?? preference.typicalMinSyp),
            max: decimal(preference.budgetMaxSyp ?? preference.typicalMaxSyp),
          }
        : null,
      dismissedFingerprints: new Set(dismissed.map((row) => row.fingerprint)),
    };
  }

  /**
   * The numbers the closet header shows.
   *
   * `outfitCapacity` is the one worth pausing on: it is the same function the
   * gap engine prioritises COVERAGE with, so the count she reads at the top of
   * the screen and the reason a gap card gives her ("هالقطعة بتفتح ٦ إطلالات
   * جديدة") are computed by one piece of arithmetic. Two implementations would
   * eventually disagree in front of her.
   */
  async overview(userId: string) {
    const closet = await this.findOrCreate(userId);
    const snapshot = await this.snapshot(userId);

    const counts = new Map<OutfitSlot, number>();
    for (const item of snapshot.items) {
      counts.set(item.slot, (counts.get(item.slot) ?? 0) + 1);
    }

    const seasonCounts = new Map<OutfitSlot, number>();
    for (const item of snapshot.items) {
      if (!item.seasons.length || item.seasons.includes(ClosetSeason.ALL) ||
          item.seasons.includes(snapshot.season)) {
        seasonCounts.set(item.slot, (seasonCounts.get(item.slot) ?? 0) + 1);
      }
    }

    const [archivedCount, wornThisMonth] = await Promise.all([
      this.prisma.closetItem.count({
        where: { closetId: closet.id, status: ClosetItemStatus.ARCHIVED },
      }),
      this.prisma.closetItemWear.count({
        where: {
          item: { closetId: closet.id },
          wornOn: { gte: startOfMonth(snapshot.now) },
        },
      }),
    ]);

    return {
      closet,
      season: snapshot.season,
      itemsCount: snapshot.items.length,
      archivedCount,
      looksCount: snapshot.looks.length,
      completeLooksCount: snapshot.looks.filter((look) => !look.wantedSlots.length).length,
      wornThisMonth,
      // The whole-closet figure, and the one for what she can wear today. The
      // difference between them is the seasonal story.
      outfitCapacity: outfitCapacity(counts as SlotCounts),
      seasonOutfitCapacity: outfitCapacity(seasonCounts as SlotCounts),
      slotCounts: [...counts.entries()]
        .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
        .map(([slot, count]) => ({ slot, count })),
      neglected: await this.neglected(closet.id),
    };
  }

  /**
   * Pieces she owns and has stopped reaching for.
   *
   * Never worn outranks worn-long-ago: a garment with no wear at all is either
   * a mistake she has not admitted to or something she has forgotten she owns,
   * and both are worth surfacing before the dress she wore in March.
   */
  private async neglected(closetId: string, limit = 6) {
    return this.prisma.closetItem.findMany({
      where: {
        closetId,
        status: ClosetItemStatus.ACTIVE,
        OR: [
          { lastWornAt: null },
          { lastWornAt: { lt: new Date(Date.now() - 90 * 86_400_000) } },
        ],
      },
      orderBy: [{ lastWornAt: { sort: 'asc', nulls: 'first' } }, { createdAt: 'asc' }],
      take: limit,
    });
  }

  /** Roll-ups, recounted from the rows rather than incremented. */
  async refreshCounts(closetId: string, tx?: Prisma.TransactionClient) {
    const client = tx ?? this.prisma;
    const [itemsCount, looksCount] = await Promise.all([
      client.closetItem.count({
        where: { closetId, status: ClosetItemStatus.ACTIVE },
      }),
      client.closetLook.count({ where: { closetId, isArchived: false } }),
    ]);
    await client.closet.update({
      where: { id: closetId },
      data: { itemsCount, looksCount },
    });
  }

  async updateSettings(
    userId: string,
    patch: { autoAddPurchases?: boolean; suggestionsEnabled?: boolean },
  ): Promise<Closet> {
    const closet = await this.findOrCreate(userId);
    return this.prisma.closet.update({ where: { id: closet.id }, data: patch });
  }
}

// ── Row → fact ──────────────────────────────────────────────────────────
//
// The engines take plain values, not Prisma rows: `Decimal` does not compare
// with `<`, and a pure function that has to know about a client's runtime types
// is not portable to a test that wants to write three garments by hand.

export function toItemFact(item: {
  id: string;
  slot: OutfitSlot;
  colours: string[];
  materials: string[];
  modesty: ClosetItemFact['modesty'];
  seasons: ClosetSeason[];
  occasions: string[];
  size: string | null;
  wearCount: number;
  lastWornAt: Date | null;
  acquiredAt: Date | null;
  purchasePriceSyp: Prisma.Decimal | null;
  isFavourite: boolean;
}): ClosetItemFact {
  return {
    id: item.id,
    slot: item.slot,
    colours: item.colours,
    materials: item.materials,
    modesty: item.modesty,
    seasons: item.seasons,
    occasions: item.occasions,
    size: item.size,
    wearCount: item.wearCount,
    lastWornAt: item.lastWornAt,
    acquiredAt: item.acquiredAt,
    purchasePriceSyp: decimal(item.purchasePriceSyp),
    isFavourite: item.isFavourite,
  };
}

export function toLookFact(look: {
  id: string;
  title: string;
  occasion: string | null;
  seasons: ClosetSeason[];
  palette: string[];
  isFavourite: boolean;
  updatedAt: Date;
  items: Array<{ slot: OutfitSlot; closetItemId: string | null }>;
}): ClosetLookFact {
  return {
    id: look.id,
    title: look.title,
    occasion: look.occasion,
    seasons: look.seasons,
    palette: look.palette,
    isFavourite: look.isFavourite,
    // The split the whole feature turns on: a slot backed by a piece she owns,
    // versus one pointing at something in the shop. The second is a gap.
    ownedSlots: look.items.filter((i) => i.closetItemId).map((i) => i.slot),
    wantedSlots: look.items.filter((i) => !i.closetItemId).map((i) => i.slot),
    updatedAt: look.updatedAt,
  };
}

function decimal(value: Prisma.Decimal | null | undefined): number | null {
  return value === null || value === undefined ? null : Number(value);
}

function startOfMonth(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), 1);
}
