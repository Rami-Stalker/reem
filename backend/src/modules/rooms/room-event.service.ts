import { Injectable } from '@nestjs/common';
import { Prisma, RoomEvent, RoomEventKind } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { RoomNotifier } from './room-notifier.service';

/**
 * The room's timeline.
 *
 * Append-only, and stores a `kind` plus a payload rather than a sentence. The
 * Arabic is rendered by the serializer, so the same event reads correctly today
 * and in a second language later without a backfill — the same contract the
 * closet's gap headlines and the stylist's reason codes keep.
 *
 * Recording an event also stamps `lastActivityAt`, which is what orders the
 * room list: a room somebody commented in an hour ago belongs above one nobody
 * has touched since Tuesday, and that ordering is the whole reason a shared
 * room feels alive rather than filed.
 */
@Injectable()
export class RoomEventService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifier: RoomNotifier,
  ) {}

  async record(
    roomId: string,
    kind: RoomEventKind,
    actorId: string | null,
    payload: Record<string, unknown> = {},
  ): Promise<RoomEvent> {
    const [event] = await this.prisma.$transaction([
      this.prisma.roomEvent.create({
        data: {
          roomId,
          kind,
          actorId,
          payload: payload as Prisma.InputJsonValue,
        },
      }),
      this.prisma.room.update({
        where: { id: roomId },
        data: { lastActivityAt: new Date() },
      }),
    ]);
    // Every room event flows through here, so this is the one place the room
    // has to be told. Awaited but self-swallowing: a notification is a
    // courtesy attached to a gesture, and it must never be able to fail it.
    if (actorId) {
      await this.notifier.notify({
        roomId,
        kind,
        actorId,
        subjectTitle:
          (payload['decision'] as string | undefined) ??
          (payload['title'] as string | undefined),
      });
    }

    return event;
  }

  async timeline(roomId: string, limit = 50): Promise<RoomEvent[]> {
    return this.prisma.roomEvent.findMany({
      where: { roomId },
      include: { actor: { select: { id: true, name: true, imageUrl: true } } },
      orderBy: { createdAt: 'desc' },
      take: Math.min(limit, 100),
    });
  }
}
