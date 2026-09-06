import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  RoomCandidate,
  RoomComment,
  RoomEventKind,
  RoomVote,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { RoomAccessService } from './room-access.service';
import { RoomEventService } from './room-event.service';

/**
 * The other people.
 *
 * Two verbs, and the difference between them is the whole reason a room is
 * worth sharing: a vote is a preference, a comment is a reason. A feature that
 * offered only the first would turn asking your sister's advice into a poll,
 * and the useful half of what she has to say — "the navy one, the other washes
 * you out" — has nowhere to go.
 *
 * Neither verb decides anything. The tallies maintained here feed
 * `consensusFor`, which reports what the room leans towards; choosing stays
 * with the people who hold the wallet. See `room-readiness.ts`.
 */
@Injectable()
export class RoomCollaborationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: RoomAccessService,
    private readonly events: RoomEventService,
  ) {}

  /**
   * Say yes or no to a candidate.
   *
   * Signed, and idempotent per person: voting again changes her mind rather
   * than stacking. `value: 0` withdraws the opinion entirely, which is a real
   * thing to want and is otherwise unexpressible.
   */
  async vote(
    roomId: string,
    userId: string,
    candidateId: string,
    value: number,
    note?: string,
  ): Promise<RoomVote | null> {
    const access = await this.access.require(roomId, userId, 'vote');
    if (![-1, 0, 1].includes(value)) {
      throw new BadRequestException('A vote is +1, −1, or 0 to withdraw it');
    }

    const candidate = await this.prisma.roomCandidate.findFirst({
      where: { id: candidateId, decision: { roomId } },
      select: { id: true },
    });
    if (!candidate) throw new NotFoundException('Candidate not found');

    let vote: RoomVote | null = null;

    if (value === 0) {
      await this.prisma.roomVote.deleteMany({
        where: { candidateId, memberId: access.member.id },
      });
    } else {
      vote = await this.prisma.roomVote.upsert({
        where: {
          candidateId_memberId: { candidateId, memberId: access.member.id },
        },
        create: {
          candidateId,
          memberId: access.member.id,
          value,
          note: note ?? null,
        },
        update: { value, note: note ?? null },
      });
    }

    await this.retally(candidateId);
    await this.events.record(roomId, RoomEventKind.VOTE_CAST, userId, {
      candidateId,
      value,
    });
    return vote;
  }

  /**
   * Recount from the rows.
   *
   * Recomputed rather than incremented, deliberately: several people vote at
   * once in a room, and an increment beside a concurrent upsert is how a tally
   * and its votes start disagreeing. The columns are a cache of the rows and
   * are treated as one.
   */
  private async retally(candidateId: string): Promise<void> {
    const votes = await this.prisma.roomVote.findMany({
      where: { candidateId },
      select: { value: true },
    });

    const votesUp = votes.filter((vote) => vote.value > 0).length;
    const votesDown = votes.filter((vote) => vote.value < 0).length;

    await this.prisma.roomCandidate.update({
      where: { id: candidateId },
      data: {
        votesUp,
        votesDown,
        voteScore: votes.reduce((total, vote) => total + vote.value, 0),
      },
    });
  }

  async votesFor(roomId: string, candidateId: string) {
    return this.prisma.roomVote.findMany({
      where: { candidateId, candidate: { decision: { roomId } } },
      include: {
        member: {
          select: {
            id: true,
            displayName: true,
            role: true,
            user: { select: { id: true, name: true, imageUrl: true } },
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  /**
   * Say something.
   *
   * Attaches to a candidate or to a decision, never both and never neither:
   * "this one is too short" is about a dress, "do we even need a bag?" is about
   * the question, and collapsing the two would put the second in a thread
   * nobody reading about the dress would look at.
   */
  async comment(
    roomId: string,
    userId: string,
    input: { body: string; decisionId?: string | null; candidateId?: string | null },
  ): Promise<RoomComment> {
    const access = await this.access.require(roomId, userId, 'comment');
    const body = input.body.trim();
    if (!body) throw new BadRequestException('Say something');

    const onDecision = !!input.decisionId;
    const onCandidate = !!input.candidateId;
    if (onDecision === onCandidate) {
      throw new BadRequestException(
        'A comment attaches to exactly one decision or one candidate',
      );
    }

    if (onCandidate) {
      const exists = await this.prisma.roomCandidate.count({
        where: { id: input.candidateId!, decision: { roomId } },
      });
      if (!exists) throw new NotFoundException('Candidate not found');
    } else {
      const exists = await this.prisma.roomDecision.count({
        where: { id: input.decisionId!, roomId },
      });
      if (!exists) throw new NotFoundException('Decision not found');
    }

    const comment = await this.prisma.roomComment.create({
      data: {
        roomId,
        memberId: access.member.id,
        body,
        decisionId: input.decisionId ?? null,
        candidateId: input.candidateId ?? null,
      },
    });

    await this.events.record(roomId, RoomEventKind.COMMENT_ADDED, userId, {
      candidateId: input.candidateId ?? null,
      decisionId: input.decisionId ?? null,
    });
    return comment;
  }

  async comments(
    roomId: string,
    filter: { candidateId?: string; decisionId?: string; limit?: number } = {},
  ) {
    return this.prisma.roomComment.findMany({
      where: {
        roomId,
        ...(filter.candidateId ? { candidateId: filter.candidateId } : {}),
        ...(filter.decisionId ? { decisionId: filter.decisionId } : {}),
      },
      include: {
        member: {
          select: {
            id: true,
            displayName: true,
            role: true,
            user: { select: { id: true, name: true, imageUrl: true } },
          },
        },
      },
      orderBy: { createdAt: 'asc' },
      take: Math.min(filter.limit ?? 100, 200),
    });
  }

  /**
   * Delete her own words.
   *
   * Her own, or the owner's call in her own room — the two people with a
   * legitimate claim over a comment. A co-shopper cannot delete an advisor's
   * objection, which would make the room a place where inconvenient advice
   * disappears.
   */
  async removeComment(
    roomId: string,
    userId: string,
    commentId: string,
  ): Promise<void> {
    const access = await this.access.require(roomId, userId, 'comment');
    const comment = await this.prisma.roomComment.findFirst({
      where: { id: commentId, roomId },
    });
    if (!comment) throw new NotFoundException('Comment not found');

    const isAuthor = comment.memberId === access.member.id;
    const isOwner = access.room.ownerId === userId;
    if (!isAuthor && !isOwner) {
      throw new BadRequestException('You can only delete your own comments');
    }

    await this.prisma.roomComment.delete({ where: { id: commentId } });
  }

  /** Every candidate's tally, for the compare view. */
  async tallies(roomId: string): Promise<RoomCandidate[]> {
    return this.prisma.roomCandidate.findMany({
      where: { decision: { roomId } },
      orderBy: [{ decisionId: 'asc' }, { voteScore: 'desc' }],
    });
  }
}
