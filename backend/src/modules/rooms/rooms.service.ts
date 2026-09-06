import { BadRequestException, Injectable } from '@nestjs/common';
import {
  OutfitSlot,
  Prisma,
  Room,
  RoomEventKind,
  RoomKind,
  RoomMemberRole,
  RoomMemberStatus,
  RoomStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  occasionEntry,
  slotLabel,
} from '../ai-stylist/understanding/stylist-lexicon';
import { RoomAccessService } from './room-access.service';
import { RoomEventService } from './room-event.service';

/** How a room is loaded when the whole thing is wanted. */
export const ROOM_INCLUDE = {
  decisions: {
    orderBy: { position: 'asc' as const },
    include: {
      candidates: {
        orderBy: { position: 'asc' as const },
        include: {
          offer: {
            include: {
              seller: { select: { id: true, name: true, imageUrl: true } },
              product: {
                include: {
                  media: { orderBy: { sortOrder: 'asc' as const }, take: 1 },
                  category: true,
                },
              },
            },
          },
          offerVariant: { include: { variant: true } },
        },
      },
    },
  },
  members: {
    where: { status: { not: RoomMemberStatus.REMOVED } },
    orderBy: { joinedAt: 'asc' as const },
  },
} satisfies Prisma.RoomInclude;

export type RoomRecord = Prisma.RoomGetPayload<{ include: typeof ROOM_INCLUDE }>;

/**
 * Rooms: the intents a woman is shopping inside.
 *
 * The interesting method is `create`, and specifically what it does with an
 * occasion. A room opened for a wedding does not start empty — it starts with
 * the questions a wedding actually poses, taken from the stylist's own occasion
 * table. That is the difference between a container she has to fill and a space
 * that already understands what she is doing.
 *
 * Those seeded decisions are marked `isSuggested`, which is what stops them
 * becoming an obligation: she can ignore the perfume question entirely and the
 * room still reaches READY on the dress and the shoes.
 */
@Injectable()
export class RoomsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: RoomAccessService,
    private readonly events: RoomEventService,
  ) {}

  async list(
    userId: string,
    filter: { status?: RoomStatus; kind?: RoomKind; limit?: number } = {},
  ): Promise<RoomRecord[]> {
    return this.prisma.room.findMany({
      where: {
        // Every room she is in, not only the ones she owns — a room her sister
        // opened and invited her to is hers to see on this list.
        members: { some: { userId, status: RoomMemberStatus.ACTIVE } },
        ...(filter.status ? { status: filter.status } : {}),
        ...(filter.kind ? { kind: filter.kind } : {}),
      },
      include: ROOM_INCLUDE,
      orderBy: { lastActivityAt: 'desc' },
      take: Math.min(filter.limit ?? 30, 60),
    });
  }

  async detail(roomId: string, userId: string): Promise<RoomRecord> {
    await this.access.require(roomId, userId);
    return this.prisma.room.findUniqueOrThrow({
      where: { id: roomId },
      include: ROOM_INCLUDE,
    });
  }

  async create(
    userId: string,
    input: {
      title: string;
      kind?: RoomKind;
      note?: string | null;
      occasion?: string | null;
      targetDate?: Date | null;
      budgetMinSyp?: number | null;
      budgetMaxSyp?: number | null;
      recipientName?: string | null;
      recipientUserId?: string | null;
      isSurprise?: boolean;
      seedFromOccasion?: boolean;
    },
  ): Promise<RoomRecord> {
    const title = input.title.trim();
    if (!title) throw new BadRequestException('Give the room a name');

    const kind = input.kind ?? RoomKind.SOLO;
    if (kind === RoomKind.GIFT && !input.recipientName?.trim() && !input.recipientUserId) {
      throw new BadRequestException('A gift room needs somebody to be for');
    }
    if (input.isSurprise && input.recipientUserId === userId) {
      throw new BadRequestException('You cannot surprise yourself');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { name: true },
    });

    const room = await this.prisma.$transaction(async (tx) => {
      const created = await tx.room.create({
        data: {
          ownerId: userId,
          kind,
          title,
          note: input.note ?? null,
          occasion: input.occasion ?? null,
          targetDate: input.targetDate ?? null,
          budgetMinSyp: input.budgetMinSyp ?? null,
          budgetMaxSyp: input.budgetMaxSyp ?? null,
          recipientName: input.recipientName?.trim() || null,
          recipientUserId: input.recipientUserId ?? null,
          isSurprise: input.isSurprise ?? false,
          members: {
            create: {
              userId,
              role: RoomMemberRole.OWNER,
              status: RoomMemberStatus.ACTIVE,
              displayName: user?.name ?? null,
            },
          },
        },
      });

      // A wedding room opens already knowing a wedding needs a dress, shoes and
      // a bag. Suggested rather than required — see the class comment.
      if (input.seedFromOccasion !== false && input.occasion) {
        const slots = this.slotsForOccasion(input.occasion);
        if (slots.length) {
          await tx.roomDecision.createMany({
            data: slots.map((slot, index) => ({
              roomId: created.id,
              title: slotLabel(slot),
              slot,
              position: index,
              isSuggested: true,
              // A seeded decision is never required: the room proposed it, she
              // did not.
              isRequired: false,
            })),
          });
          await tx.room.update({
            where: { id: created.id },
            data: { decisionsCount: slots.length },
          });
        }
      }

      return created;
    });

    await this.events.record(room.id, RoomEventKind.ROOM_CREATED, userId, {
      title: room.title,
      kind: room.kind,
    });

    return this.prisma.room.findUniqueOrThrow({
      where: { id: room.id },
      include: ROOM_INCLUDE,
    });
  }

  async update(
    roomId: string,
    userId: string,
    patch: {
      title?: string;
      note?: string | null;
      occasion?: string | null;
      targetDate?: Date | null;
      budgetMinSyp?: number | null;
      budgetMaxSyp?: number | null;
      status?: RoomStatus;
      coverUrl?: string | null;
      recipientName?: string | null;
    },
  ): Promise<RoomRecord> {
    await this.access.require(roomId, userId, 'manage');

    await this.prisma.room.update({
      where: { id: roomId },
      data: {
        ...(patch.title !== undefined ? { title: patch.title.trim() } : {}),
        ...(patch.note !== undefined ? { note: patch.note } : {}),
        ...(patch.occasion !== undefined ? { occasion: patch.occasion } : {}),
        ...(patch.targetDate !== undefined ? { targetDate: patch.targetDate } : {}),
        ...(patch.budgetMinSyp !== undefined
          ? { budgetMinSyp: patch.budgetMinSyp }
          : {}),
        ...(patch.budgetMaxSyp !== undefined
          ? { budgetMaxSyp: patch.budgetMaxSyp }
          : {}),
        ...(patch.status !== undefined ? { status: patch.status } : {}),
        ...(patch.coverUrl !== undefined ? { coverUrl: patch.coverUrl } : {}),
        ...(patch.recipientName !== undefined
          ? { recipientName: patch.recipientName }
          : {}),
        lastActivityAt: new Date(),
      },
    });

    return this.prisma.room.findUniqueOrThrow({
      where: { id: roomId },
      include: ROOM_INCLUDE,
    });
  }

  async archive(roomId: string, userId: string): Promise<Room> {
    await this.access.require(roomId, userId, 'manage');
    return this.prisma.room.update({
      where: { id: roomId },
      data: { status: RoomStatus.ARCHIVED },
    });
  }

  /**
   * Delete a room outright.
   *
   * Only the owner, and only her — everybody else leaves. A room somebody was
   * invited into holds other people's comments and votes, so removing it is a
   * decision about their words too, and it belongs to exactly one person.
   */
  async remove(roomId: string, userId: string): Promise<void> {
    const access = await this.access.require(roomId, userId, 'manage');
    if (access.room.ownerId !== userId) {
      throw new BadRequestException('Only the owner can delete a room');
    }
    await this.prisma.room.delete({ where: { id: roomId } });
  }

  /**
   * The slots an occasion implies, read out of the stylist's own table.
   *
   * `GIFT` is dropped: it is a whole-purchase slot rather than a body position,
   * and a room seeded with a decision called "هدية" inside a wedding room is
   * the lexicon leaking rather than a question anybody has.
   */
  private slotsForOccasion(occasion: string): OutfitSlot[] {
    const entry = occasionEntry(occasion);
    if (!entry) return [];
    return entry.slots.filter((slot) => slot !== OutfitSlot.GIFT).slice(0, 5);
  }
}
