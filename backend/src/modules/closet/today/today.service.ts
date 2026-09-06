import { Injectable } from '@nestjs/common';
import { ClosetItem } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { ClosetService } from '../closet.service';
import { OutfitProposal, pickTodayOutfits } from './today-picker';

export interface TodayOutfit extends OutfitProposal {
  /** The actual rows, in slot order, so the client renders without a lookup. */
  pieceItems: ClosetItem[];
  /** Set for SAVED proposals. */
  lookTitle: string | null;
}

/**
 * The morning question, answered.
 *
 * Thin by design: the picking is a pure function over the snapshot, and this
 * class exists to read the closet, hand it over, and hydrate the ids that come
 * back into rows the client can draw. Anything resembling a decision that ends
 * up here is a decision that has escaped the testable half of the feature.
 */
@Injectable()
export class ClosetTodayService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly closet: ClosetService,
  ) {}

  async today(
    userId: string,
    options: { occasion?: string | null; limit?: number; now?: Date } = {},
  ): Promise<{ season: string; outfits: TodayOutfit[] }> {
    const now = options.now ?? new Date();
    const snapshot = await this.closet.snapshot(userId, { now });

    const proposals = pickTodayOutfits({
      items: snapshot.items,
      looks: snapshot.looks,
      now,
      season: snapshot.season,
      occasion: options.occasion ?? null,
      limit: options.limit ?? 6,
    });

    const itemIds = [
      ...new Set(proposals.flatMap((p) => p.pieces.map((piece) => piece.itemId))),
    ];
    const lookIds = [
      ...new Set(proposals.map((p) => p.lookId).filter((id): id is string => !!id)),
    ];

    const [items, looks] = await Promise.all([
      itemIds.length
        ? this.prisma.closetItem.findMany({ where: { id: { in: itemIds } } })
        : Promise.resolve([]),
      lookIds.length
        ? this.prisma.closetLook.findMany({
            where: { id: { in: lookIds } },
            select: { id: true, title: true },
          })
        : Promise.resolve([]),
    ]);

    const itemById = new Map(items.map((item) => [item.id, item]));
    const lookById = new Map(looks.map((look) => [look.id, look.title]));

    return {
      season: snapshot.season,
      outfits: proposals.map((proposal) => ({
        ...proposal,
        // Filtered rather than asserted: an item deleted between the snapshot
        // and this read is a missing card, not a five-hundred.
        pieceItems: proposal.pieces
          .map((piece) => itemById.get(piece.itemId))
          .filter((item): item is ClosetItem => item !== undefined),
        lookTitle: proposal.lookId ? (lookById.get(proposal.lookId) ?? null) : null,
      })),
    };
  }
}
