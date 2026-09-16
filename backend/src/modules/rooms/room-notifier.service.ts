import { Injectable, Logger } from '@nestjs/common';
import {
  NotificationType,
  Prisma,
  RoomEventKind,
  RoomMemberStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

/** What happened, in the vocabulary the notifier renders. */
export interface RoomNotice {
  roomId: string;
  kind: RoomEventKind;
  /** Who did it. Never notified about her own gesture. */
  actorId: string;
  /** For the one-event sentence: "رنا صوّتت على اقتراحك". */
  subjectTitle?: string;
  /** Told first and in their own words, whatever the coalescing does. */
  priorityUserIds?: string[];
}

/**
 * Telling the room.
 *
 * The whole difficulty here is volume, and it is not a small one. A room with
 * five people and six candidates generates thirty votes in an afternoon, and a
 * notification per gesture would make the one feature that depends on people
 * staying in the room the reason they leave it.
 *
 * So notices **coalesce per room**. Within `WINDOW_MINUTES`, an unread room
 * notification for the same recipient and the same room is *updated* — its
 * count goes up and its sentence is rewritten — rather than a second one being
 * written. One line per room that says "٤ تفاعلات جديدة", not four lines.
 *
 * Coalescing at write time rather than in a digest job is deliberate: it needs
 * no scheduler, it is correct the moment it happens, and the row she is looking
 * at is the row that updates.
 *
 * Two things are never coalesced away, because they are events rather than
 * activity:
 *
 *  - **A decision being resolved.** Somebody chose; that is the room moving,
 *    and it deserves its own line.
 *  - **A plan being bought.** The room is finished.
 *
 * This lives in the rooms module rather than in notifications, and writes
 * through Prisma directly. The dependency runs one way: rooms knows what a
 * notification is, notifications knows nothing about rooms — the same direction
 * every other cross-module read in this codebase takes.
 */
@Injectable()
export class RoomNotifier {
  private readonly logger = new Logger(RoomNotifier.name);

  /** How long a room's activity keeps folding into one line. */
  private static readonly WINDOW_MINUTES = 45;

  /** Kinds that always get their own notification. */
  private static readonly UNCOALESCED: ReadonlySet<RoomEventKind> = new Set([
    RoomEventKind.DECISION_RESOLVED,
    RoomEventKind.PLAN_ORDERED,
    RoomEventKind.MEMBER_INVITED,
  ]);

  constructor(
    private readonly prisma: PrismaService,
    /**
     * Only ever asked to *send* a row this class has already written.
     *
     * The dependency still runs one way — notifications knows nothing about
     * rooms — but a row written and never pushed is a notification only a
     * woman already inside the app can see, which is precisely the wrong
     * audience for "you have been invited into a room".
     */
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * Tell everybody in the room except whoever did it.
   *
   * Swallows its own failures: a notification is a courtesy attached to a vote,
   * and a courtesy must never be able to fail the thing it is attached to.
   */
  async notify(notice: RoomNotice): Promise<void> {
    try {
      await this.deliver(notice);
    } catch (error) {
      this.logger.warn(
        `Room notification failed for ${notice.roomId}: ${String(error)}`,
      );
    }
  }

  private async deliver(notice: RoomNotice): Promise<void> {
    const room = await this.prisma.room.findUnique({
      where: { id: notice.roomId },
      select: { id: true, title: true, isSurprise: true, recipientUserId: true },
    });
    if (!room) return;

    const members = await this.prisma.roomMember.findMany({
      where: { roomId: room.id, status: RoomMemberStatus.ACTIVE },
      select: { userId: true },
    });

    const recipients = members
      .map((member) => member.userId)
      .filter((userId) => userId !== notice.actorId)
      // Belt and braces. A surprise room never admits its recipient, so she is
      // not a member — but a notification is the one thing that would reach her
      // outside the room, so the exclusion is repeated where it would leak.
      .filter((userId) => !(room.isSurprise && userId === room.recipientUserId));

    if (!recipients.length) return;

    const muted = await this.mutedAmong(recipients);
    const audience = recipients.filter((userId) => !muted.has(userId));
    if (!audience.length) return;

    const actor = await this.prisma.user.findUnique({
      where: { id: notice.actorId },
      select: { name: true },
    });
    const actorName = actor?.name ?? 'حدا';

    for (const userId of audience) {
      await this.deliverOne(userId, room.id, room.title, notice, actorName);
    }
  }

  private async deliverOne(
    userId: string,
    roomId: string,
    roomTitle: string,
    notice: RoomNotice,
    actorName: string,
  ): Promise<void> {
    const single = this.sentenceFor(notice, actorName);

    if (RoomNotifier.UNCOALESCED.has(notice.kind)) {
      const created = await this.prisma.notification.create({
        data: {
          userId,
          type: NotificationType.room,
          title: roomTitle,
          body: single,
          data: { room_id: roomId, kind: notice.kind } as Prisma.InputJsonValue,
        },
      });
      await this.notifications.pushExisting(created);
      return;
    }

    const since = new Date(
      Date.now() - RoomNotifier.WINDOW_MINUTES * 60_000,
    );

    // The open line for this room, if she has one she has not read.
    const existing = await this.prisma.notification.findFirst({
      where: {
        userId,
        type: NotificationType.room,
        isRead: false,
        createdAt: { gte: since },
        data: { path: ['room_id'], equals: roomId },
      },
      orderBy: { createdAt: 'desc' },
      select: { id: true, data: true },
    });

    if (!existing) {
      const created = await this.prisma.notification.create({
        data: {
          userId,
          type: NotificationType.room,
          title: roomTitle,
          body: single,
          data: {
            room_id: roomId,
            kind: notice.kind,
            count: 1,
          } as Prisma.InputJsonValue,
        },
      });
      // The first gesture in a window buzzes; the next twelve fold into the
      // line it opened and do not. That is the whole bargain coalescing makes,
      // and pushing on the update below would break it on the one surface
      // where the noise is actually felt.
      await this.notifications.pushExisting(created);
      return;
    }

    const previous = (existing.data as Record<string, unknown> | null) ?? {};
    const count = Number(previous['count'] ?? 1) + 1;

    await this.prisma.notification.update({
      where: { id: existing.id },
      data: {
        body: `${count} تفاعلات جديدة بالغرفة`,
        // Re-stamped so the line rises to the top of her list again: the whole
        // point of folding is that one row stays current, not that it goes
        // stale where it was first written.
        createdAt: new Date(),
        data: { room_id: roomId, kind: notice.kind, count } as Prisma.InputJsonValue,
      },
    });
  }

  /** Who has turned room notices off. */
  private async mutedAmong(userIds: string[]): Promise<Set<string>> {
    const prefs = await this.prisma.notificationPreference.findMany({
      where: { userId: { in: userIds }, inAppRooms: false },
      select: { userId: true },
    });
    return new Set(prefs.map((pref) => pref.userId));
  }

  /**
   * One gesture, in Arabic.
   *
   * Rendered from the kind rather than stored as prose, like the room timeline
   * — so the same event reads correctly in a second language without a
   * backfill.
   */
  private sentenceFor(notice: RoomNotice, actorName: string): string {
    const subject = notice.subjectTitle;

    switch (notice.kind) {
      case RoomEventKind.VOTE_CAST:
        return `${actorName} صوّتت على اقتراح`;
      case RoomEventKind.COMMENT_ADDED:
        return subject
          ? `${actorName} علّقت على «${subject}»`
          : `${actorName} علّقت بالغرفة`;
      case RoomEventKind.CANDIDATE_ADDED:
        return subject
          ? `${actorName} اقترحت قطعة لـ«${subject}»`
          : `${actorName} اقترحت قطعة`;
      case RoomEventKind.DECISION_ADDED:
        return `${actorName} ضافت قرار جديد`;
      case RoomEventKind.DECISION_RESOLVED:
        return subject
          ? `${actorName} حسمت «${subject}»`
          : `${actorName} حسمت قرار`;
      case RoomEventKind.DECISION_SKIPPED:
        return subject
          ? `${actorName} قرّرت تتخطّى «${subject}»`
          : `${actorName} تخطّت قرار`;
      case RoomEventKind.MEMBER_JOINED:
        return `${actorName} انضمّت للغرفة`;
      case RoomEventKind.MEMBER_INVITED:
        return `${actorName} دعتك لغرفة`;
      case RoomEventKind.PLAN_DRAWN:
        return `${actorName} جهّزت خطة الشرا`;
      case RoomEventKind.PLAN_ORDERED:
        return `${actorName} اشترت من الغرفة`;
      default:
        return `في حركة جديدة بالغرفة`;
    }
  }
}
