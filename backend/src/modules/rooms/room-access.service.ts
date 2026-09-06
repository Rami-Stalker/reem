import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Room,
  RoomMember,
  RoomMemberRole,
  RoomMemberStatus,
} from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { PrismaService } from '../../prisma/prisma.service';

/** What somebody may do inside a room. */
export type RoomCapability =
  | 'read'
  | 'comment'
  | 'vote'
  | 'propose'
  | 'decide'
  | 'manage'
  | 'buy';

/**
 * Who may do what in a room.
 *
 * The table is the feature. A room exists to let other people in, and the only
 * reason that is safe is that the roles separate *having an opinion* from
 * *having a wallet*: an ADVISOR — which is what a shared link makes you — can
 * argue for a dress all afternoon and cannot change what gets bought.
 *
 * Everything below reads from this map, so widening what a guest may do is one
 * edit in one place rather than a search for missing checks.
 */
const CAPABILITIES: Record<RoomMemberRole, ReadonlySet<RoomCapability>> = {
  OWNER: new Set<RoomCapability>([
    'read',
    'comment',
    'vote',
    'propose',
    'decide',
    'manage',
    'buy',
  ]),
  CO_SHOPPER: new Set<RoomCapability>([
    'read',
    'comment',
    'vote',
    'propose',
    'decide',
  ]),
  ADVISOR: new Set<RoomCapability>(['read', 'comment', 'vote', 'propose']),
  VIEWER: new Set<RoomCapability>(['read']),
};

export interface RoomAccess {
  room: Room;
  member: RoomMember;
  role: RoomMemberRole;
  can: (capability: RoomCapability) => boolean;
}

/**
 * Getting into a room, and what that entitles you to.
 *
 * Every other service in this module goes through `require`, which is the only
 * place a room is loaded for somebody. That is deliberate: a room is the first
 * object in this application that several people read and write at once, and a
 * permission check scattered across five services is a permission check that
 * will be missing from the sixth.
 */
@Injectable()
export class RoomAccessService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Load a room for somebody, or refuse.
   *
   * Refuses with 404 rather than 403 when she is not a member at all: a room's
   * existence is itself private, and telling a stranger "this exists but is not
   * yours" leaks that her sister is planning something.
   */
  async require(
    roomId: string,
    userId: string,
    capability: RoomCapability = 'read',
  ): Promise<RoomAccess> {
    const room = await this.prisma.room.findUnique({ where: { id: roomId } });
    if (!room) throw new NotFoundException('Room not found');

    const member = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (!member || member.status !== RoomMemberStatus.ACTIVE) {
      throw new NotFoundException('Room not found');
    }

    const allowed = CAPABILITIES[member.role];
    if (!allowed.has(capability)) {
      throw new ForbiddenException(
        'Your role in this room does not allow that',
      );
    }

    return {
      room,
      member,
      role: member.role,
      can: (wanted) => allowed.has(wanted),
    };
  }

  /** The capability set, without throwing — for serializing what to render. */
  capabilitiesOf(role: RoomMemberRole): RoomCapability[] {
    return [...CAPABILITIES[role]];
  }

  // ── Membership ────────────────────────────────────────────────────────

  async members(roomId: string): Promise<RoomMember[]> {
    return this.prisma.roomMember.findMany({
      where: { roomId, status: { not: RoomMemberStatus.REMOVED } },
      orderBy: [{ role: 'asc' }, { joinedAt: 'asc' }],
    });
  }

  /**
   * Invite somebody by account.
   *
   * The surprise rule lives here and nowhere else: a gift room that is a
   * surprise refuses to admit the person it is about. It is the one access
   * rule that cannot be delegated to the client, because the client that would
   * enforce it is the one belonging to the person being surprised.
   */
  async invite(
    roomId: string,
    actorId: string,
    input: { userId: string; role?: RoomMemberRole },
  ): Promise<RoomMember> {
    const access = await this.require(roomId, actorId, 'manage');
    const role = input.role ?? RoomMemberRole.ADVISOR;

    if (role === RoomMemberRole.OWNER) {
      throw new BadRequestException('A room has one owner');
    }
    this.assertNotTheRecipient(access.room, input.userId);

    const user = await this.prisma.user.findUnique({
      where: { id: input.userId },
      select: { id: true, name: true },
    });
    if (!user) throw new NotFoundException('No such account');

    const member = await this.prisma.roomMember.upsert({
      where: { roomId_userId: { roomId, userId: user.id } },
      create: {
        roomId,
        userId: user.id,
        role,
        status: RoomMemberStatus.ACTIVE,
        invitedById: actorId,
        displayName: user.name,
      },
      // Re-inviting somebody who left brings her back at the new role rather
      // than failing on the unique index.
      update: { role, status: RoomMemberStatus.ACTIVE, invitedById: actorId },
    });

    await this.refreshMemberCount(roomId);
    return member;
  }

  async setRole(
    roomId: string,
    actorId: string,
    memberId: string,
    role: RoomMemberRole,
  ): Promise<RoomMember> {
    const access = await this.require(roomId, actorId, 'manage');
    if (role === RoomMemberRole.OWNER) {
      throw new BadRequestException('A room has one owner');
    }

    const member = await this.prisma.roomMember.findFirst({
      where: { id: memberId, roomId },
    });
    if (!member) throw new NotFoundException('Member not found');
    if (member.userId === access.room.ownerId) {
      throw new BadRequestException('The owner keeps her room');
    }

    return this.prisma.roomMember.update({
      where: { id: memberId },
      data: { role },
    });
  }

  async remove(
    roomId: string,
    actorId: string,
    memberId: string,
  ): Promise<void> {
    const access = await this.require(roomId, actorId, 'manage');
    const member = await this.prisma.roomMember.findFirst({
      where: { id: memberId, roomId },
    });
    if (!member) throw new NotFoundException('Member not found');
    if (member.userId === access.room.ownerId) {
      throw new BadRequestException('The owner cannot be removed');
    }

    // Marked rather than deleted: her votes and comments stay, and a timeline
    // that suddenly had no author would read as if the argument never happened.
    await this.prisma.roomMember.update({
      where: { id: memberId },
      data: { status: RoomMemberStatus.REMOVED },
    });
    await this.refreshMemberCount(roomId);
  }

  /** Leave a room she was invited into. The owner cannot; she deletes it. */
  async leave(roomId: string, userId: string): Promise<void> {
    const access = await this.require(roomId, userId);
    if (access.room.ownerId === userId) {
      throw new BadRequestException(
        'You own this room — delete or archive it instead',
      );
    }
    await this.prisma.roomMember.update({
      where: { id: access.member.id },
      data: { status: RoomMemberStatus.REMOVED },
    });
    await this.refreshMemberCount(roomId);
  }

  // ── Links ─────────────────────────────────────────────────────────────

  /**
   * Turn sharing on, or rotate the link.
   *
   * Rotation is the only revocation a link-shared room can honestly offer, so
   * it is the same call: asking to share again replaces the slug and every link
   * already handed out stops working.
   */
  async share(
    roomId: string,
    actorId: string,
    role: RoomMemberRole = RoomMemberRole.ADVISOR,
  ): Promise<Room> {
    await this.require(roomId, actorId, 'manage');
    if (role === RoomMemberRole.OWNER || role === RoomMemberRole.CO_SHOPPER) {
      // A link is an invitation to have an opinion. Anybody who is to spend
      // money in here is invited by name.
      throw new BadRequestException(
        'A shared link can only make advisors or viewers',
      );
    }

    return this.prisma.room.update({
      where: { id: roomId },
      data: { shareSlug: randomBytes(9).toString('base64url'), shareRole: role },
    });
  }

  async unshare(roomId: string, actorId: string): Promise<Room> {
    await this.require(roomId, actorId, 'manage');
    return this.prisma.room.update({
      where: { id: roomId },
      data: { shareSlug: null },
    });
  }

  /**
   * Follow a shared link.
   *
   * Joins at the room's `shareRole`, never higher — and refuses the recipient
   * of a surprise, who would otherwise walk into her own party.
   */
  async joinByLink(slug: string, userId: string): Promise<RoomAccess> {
    const room = await this.prisma.room.findUnique({ where: { shareSlug: slug } });
    if (!room) throw new NotFoundException('This link is no longer valid');

    this.assertNotTheRecipient(room, userId);

    const existing = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId: room.id, userId } },
    });
    // Somebody already in the room keeps the role she has: following the link
    // again must never demote a co-shopper to an advisor.
    if (existing && existing.status === RoomMemberStatus.ACTIVE) {
      return this.require(room.id, userId);
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { name: true },
    });

    await this.prisma.roomMember.upsert({
      where: { roomId_userId: { roomId: room.id, userId } },
      create: {
        roomId: room.id,
        userId,
        role: room.shareRole,
        status: RoomMemberStatus.ACTIVE,
        displayName: user?.name ?? null,
      },
      update: { status: RoomMemberStatus.ACTIVE },
    });

    await this.refreshMemberCount(room.id);
    return this.require(room.id, userId);
  }

  // ── Internals ─────────────────────────────────────────────────────────

  private assertNotTheRecipient(room: Room, userId: string): void {
    if (room.isSurprise && room.recipientUserId === userId) {
      // Deliberately the same message a stranger gets. "You may not join
      // because this is your surprise" is itself the spoiler.
      throw new NotFoundException('Room not found');
    }
  }

  private async refreshMemberCount(roomId: string): Promise<void> {
    const membersCount = await this.prisma.roomMember.count({
      where: { roomId, status: RoomMemberStatus.ACTIVE },
    });
    await this.prisma.room.update({ where: { id: roomId }, data: { membersCount } });
  }
}
