import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  ClosetItemStatus,
  ClosetLook,
  ClosetSeason,
  OutfitSlot,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { PRODUCT_CARD_INCLUDE } from '../../../common/catalog/product-include';
import { ClosetService } from '../closet.service';
import { startOfDay } from '../items/closet-item.service';

export const LOOK_INCLUDE = {
  items: {
    include: {
      closetItem: true,
      product: { include: PRODUCT_CARD_INCLUDE },
    },
    orderBy: { position: 'asc' as const },
  },
} satisfies Prisma.ClosetLookInclude;

export type LookRecord = Prisma.ClosetLookGetPayload<{ include: typeof LOOK_INCLUDE }>;

/** One slot of a look, as the client sends it. */
export interface LookSlotInput {
  slot: OutfitSlot;
  /** A piece she owns. */
  closetItemId?: string | null;
  /** A catalog product she does not — the gap, made concrete. */
  productId?: string | null;
  offerId?: string | null;
  variantId?: string | null;
  note?: string | null;
}

/**
 * Looks: the compositions she builds out of her closet.
 *
 * The interesting method is `setItems`, and the interesting thing about it is
 * that it accepts slots she cannot fill. A look with a dress she owns, shoes she
 * owns and a bag from the catalog is a *valid, saved look* — not a draft, not an
 * error. That is the mechanism by which browsing becomes wardrobe-driven: the
 * unfilled slot is a stated intention attached to a specific outfit, and the gap
 * engine reads it as the most concrete need there is.
 */
@Injectable()
export class ClosetLookService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly closet: ClosetService,
  ) {}

  // ── Reading ───────────────────────────────────────────────────────────

  async list(
    userId: string,
    filter: { occasion?: string; includeArchived?: boolean; limit?: number } = {},
  ): Promise<LookRecord[]> {
    const closet = await this.closet.findOrCreate(userId);
    return this.prisma.closetLook.findMany({
      where: {
        closetId: closet.id,
        ...(filter.includeArchived ? {} : { isArchived: false }),
        ...(filter.occasion ? { occasion: filter.occasion } : {}),
      },
      include: LOOK_INCLUDE,
      orderBy: [{ isFavourite: 'desc' }, { updatedAt: 'desc' }],
      take: Math.min(filter.limit ?? 50, 100),
    });
  }

  async require(userId: string, lookId: string): Promise<LookRecord> {
    const look = await this.prisma.closetLook.findFirst({
      where: { id: lookId, userId },
      include: LOOK_INCLUDE,
    });
    if (!look) throw new NotFoundException('Look not found');
    return look;
  }

  // ── Writing ───────────────────────────────────────────────────────────

  async create(
    userId: string,
    input: {
      title: string;
      occasion?: string | null;
      note?: string | null;
      seasons?: ClosetSeason[];
      items?: LookSlotInput[];
      sourceOutfitId?: string | null;
    },
  ): Promise<LookRecord> {
    const title = input.title.trim();
    if (!title) throw new BadRequestException('Title is required');

    const closet = await this.closet.findOrCreate(userId);

    // Before the look exists, not after — see `assertSlotsValid`.
    if (input.items?.length) await this.assertSlotsValid(userId, input.items);

    const look = await this.prisma.closetLook.create({
      data: {
        closetId: closet.id,
        userId,
        title,
        occasion: input.occasion ?? null,
        note: input.note ?? null,
        seasons: input.seasons ?? [],
        sourceOutfitId: input.sourceOutfitId ?? null,
      },
    });

    if (input.items?.length) await this.setItems(userId, look.id, input.items);
    await this.closet.refreshCounts(closet.id);
    return this.require(userId, look.id);
  }

  async update(
    userId: string,
    lookId: string,
    patch: {
      title?: string;
      occasion?: string | null;
      note?: string | null;
      seasons?: ClosetSeason[];
      isFavourite?: boolean;
      isArchived?: boolean;
    },
  ): Promise<LookRecord> {
    await this.require(userId, lookId);
    await this.prisma.closetLook.update({
      where: { id: lookId },
      data: {
        ...(patch.title !== undefined ? { title: patch.title.trim() } : {}),
        ...(patch.occasion !== undefined ? { occasion: patch.occasion } : {}),
        ...(patch.note !== undefined ? { note: patch.note } : {}),
        ...(patch.seasons !== undefined ? { seasons: patch.seasons } : {}),
        ...(patch.isFavourite !== undefined ? { isFavourite: patch.isFavourite } : {}),
        ...(patch.isArchived !== undefined ? { isArchived: patch.isArchived } : {}),
      },
    });

    if (patch.isArchived !== undefined) {
      const look = await this.require(userId, lookId);
      await this.closet.refreshCounts(look.closetId);
    }
    return this.require(userId, lookId);
  }

  async remove(userId: string, lookId: string): Promise<void> {
    const look = await this.require(userId, lookId);
    await this.prisma.closetLook.delete({ where: { id: lookId } });
    await this.closet.refreshCounts(look.closetId);
  }

  /**
   * Replace the look's slots wholesale.
   *
   * Whole-set rather than per-slot patching because a look is edited as a
   * composition: she swaps the shoes and removes the jacket in one gesture, and
   * three round trips would let the server hold a look that never existed on
   * her screen.
   *
   * Every slot is validated before anything is written, so a bad row cannot
   * leave a half-edited outfit behind.
   */
  /**
   * Everything that must be true of a set of slots before anything is written.
   *
   * Extracted so `create` can run it *before* the look row exists. It used to
   * live inside `setItems` alone, which meant a rejected creation had already
   * committed the look: the request returned 400 and she was left with an empty
   * outfit in her closet — and worse, the gap engine then told her she was
   * "missing a dress to complete" a look that contained nothing at all.
   */
  private async assertSlotsValid(
    userId: string,
    slots: readonly LookSlotInput[],
  ): Promise<void> {
    const seen = new Set<OutfitSlot>();
    for (const entry of slots) {
      const owned = !!entry.closetItemId;
      const wanted = !!entry.productId;

      // The invariant the schema documents and cannot express: a slot is either
      // something she has or something she wants, never both and never neither.
      if (owned === wanted) {
        throw new BadRequestException(
          `Slot ${entry.slot} must reference exactly one of closetItemId or productId`,
        );
      }
      if (seen.has(entry.slot)) {
        throw new BadRequestException(`Slot ${entry.slot} appears more than once`);
      }
      seen.add(entry.slot);
    }

    // Ownership check in one query rather than per slot: a woman may only build
    // looks from her own wardrobe, and this is the line that enforces it.
    const itemIds = slots
      .map((entry) => entry.closetItemId)
      .filter((id): id is string => !!id);
    if (itemIds.length) {
      const owned = await this.prisma.closetItem.count({
        where: { id: { in: itemIds }, userId, status: { not: ClosetItemStatus.RELEASED } },
      });
      if (owned !== new Set(itemIds).size) {
        throw new BadRequestException('One or more pieces are not in your closet');
      }
    }
  }

  async setItems(
    userId: string,
    lookId: string,
    slots: readonly LookSlotInput[],
  ): Promise<LookRecord> {
    await this.require(userId, lookId);
    await this.assertSlotsValid(userId, slots);

    await this.prisma.$transaction(async (tx) => {
      await tx.closetLookItem.deleteMany({ where: { lookId } });
      if (slots.length) {
        await tx.closetLookItem.createMany({
          data: slots.map((entry, index) => ({
            lookId,
            slot: entry.slot,
            position: index,
            closetItemId: entry.closetItemId ?? null,
            productId: entry.productId ?? null,
            offerId: entry.offerId ?? null,
            variantId: entry.variantId ?? null,
            note: entry.note ?? null,
          })),
        });
      }
    });

    await this.refreshDerived(lookId);
    return this.require(userId, lookId);
  }

  /**
   * Recompute the fields that are functions of the look's slots.
   *
   * `isComplete` and `palette` are stored rather than computed on read because
   * both are filtered and sorted on — "منها الجاهزة" is an indexed query, and a
   * derived column is the only way to have one.
   */
  private async refreshDerived(lookId: string): Promise<void> {
    const items = await this.prisma.closetLookItem.findMany({
      where: { lookId },
      include: { closetItem: { select: { colours: true } } },
    });

    const palette = new Set<string>();
    for (const item of items) {
      for (const colour of item.closetItem?.colours ?? []) palette.add(colour);
    }

    await this.prisma.closetLook.update({
      where: { id: lookId },
      data: {
        // An empty look is not complete — there is nothing to wear.
        isComplete: items.length > 0 && items.every((item) => item.closetItemId !== null),
        palette: [...palette],
      },
    });
  }

  // ── Wearing ───────────────────────────────────────────────────────────

  /**
   * She wore this look today.
   *
   * Fans out to a wear on every owned piece in it, in the same transaction, so
   * "I wore this outfit" and "I wore this dress" can never disagree. The
   * per-item counters are recounted rather than incremented, for the same
   * reason as in `ClosetItemService.logWear`.
   */
  async logWear(
    userId: string,
    lookId: string,
    input: { wornOn?: Date; occasionNote?: string | null } = {},
  ): Promise<LookRecord> {
    const look = await this.require(userId, lookId);
    const day = startOfDay(input.wornOn ?? new Date());
    const itemIds = look.items
      .map((item) => item.closetItemId)
      .filter((id): id is string => !!id);

    await this.prisma.$transaction(async (tx) => {
      const lookWear = await tx.closetLookWear.upsert({
        where: { lookId_wornOn: { lookId, wornOn: day } },
        create: { lookId, wornOn: day, occasionNote: input.occasionNote ?? null },
        update: { occasionNote: input.occasionNote ?? null },
      });

      for (const itemId of itemIds) {
        await tx.closetItemWear.upsert({
          where: { itemId_wornOn: { itemId, wornOn: day } },
          // A piece worn on its own this morning and then logged as part of a
          // look is one wearing; the update binds it to the look rather than
          // adding a second row.
          create: { itemId, wornOn: day, lookWearId: lookWear.id },
          update: { lookWearId: lookWear.id },
        });

        const [wearCount, latest] = await Promise.all([
          tx.closetItemWear.count({ where: { itemId } }),
          tx.closetItemWear.findFirst({ where: { itemId }, orderBy: { wornOn: 'desc' } }),
        ]);
        await tx.closetItem.update({
          where: { id: itemId },
          data: { wearCount, lastWornAt: latest?.wornOn ?? null },
        });
      }

      const [wearCount, latest] = await Promise.all([
        tx.closetLookWear.count({ where: { lookId } }),
        tx.closetLookWear.findFirst({ where: { lookId }, orderBy: { wornOn: 'desc' } }),
      ]);
      await tx.closetLook.update({
        where: { id: lookId },
        data: { wearCount, lastWornAt: latest?.wornOn ?? null },
      });
    });

    return this.require(userId, lookId);
  }

  /**
   * Save a stylist suggestion as a look of her own.
   *
   * The one-way bridge between the two tables. Pieces she already owns are
   * matched by product and attached as owned slots; the rest stay as wanted
   * slots pointing at the catalog — so promoting a suggestion produces a look
   * that is already partly hers, and gaps for exactly the pieces it would take
   * to finish it.
   */
  async promoteStylistOutfit(userId: string, outfitId: string): Promise<LookRecord> {
    const outfit = await this.prisma.aiStylistOutfit.findFirst({
      where: { id: outfitId, userId },
      include: { items: true },
    });
    if (!outfit) throw new NotFoundException('Outfit not found');

    const productIds = outfit.items.map((item) => item.productId);
    const owned = await this.prisma.closetItem.findMany({
      where: {
        userId,
        productId: { in: productIds },
        status: { not: ClosetItemStatus.RELEASED },
      },
      select: { id: true, productId: true },
    });
    const ownedByProduct = new Map(owned.map((row) => [row.productId, row.id]));

    return this.create(userId, {
      title: outfit.title,
      occasion: outfit.occasion,
      note: outfit.note,
      sourceOutfitId: outfit.id,
      items: outfit.items.map((item) => {
        const ownedId = ownedByProduct.get(item.productId);
        return ownedId
          ? { slot: item.slot, closetItemId: ownedId, note: item.reason }
          : {
              slot: item.slot,
              productId: item.productId,
              offerId: item.offerId,
              variantId: item.variantId,
              note: item.reason,
            };
      }),
    });
  }
}
