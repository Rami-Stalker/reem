import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  SupportPriority,
  SupportTicketStatus,
  UserRole,
} from '@prisma/client';

import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * The customer's way of reaching a person.
 *
 * The admin console could already list tickets and change their status — but
 * nothing could create one, and no message was ever written, so «تواصلي مع
 * الدعم» led nowhere and the queue an operator watched was permanently empty.
 *
 * Q88 puts support hours at 09:00–23:00 and Q60 makes customer service its own
 * role. Neither is much use without a way in.
 */
@Injectable()
export class SupportService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Opens a ticket, with her first message already in it.
   *
   * A subject with no body is a subject line somebody has to chase, so the
   * first message is part of opening rather than a second step she might not
   * take.
   */
  async open(
    user: AuthUser,
    input: { subject: string; body: string; category?: string },
  ) {
    // One open conversation at a time per topic. A customer who taps twice
    // should land back in the thread she started, not split her problem across
    // two queues where each half looks unanswered.
    const existing = await this.prisma.supportTicket.findFirst({
      where: {
        userId: user.id,
        category: input.category ?? 'general',
        status: { in: [SupportTicketStatus.OPEN, SupportTicketStatus.PENDING] },
      },
    });

    if (existing) {
      await this.reply(existing.id, user, { body: input.body });
      return this.detail(existing.id, user);
    }

    const ticket = await this.prisma.supportTicket.create({
      data: {
        userId: user.id,
        subject: input.subject,
        category: input.category ?? 'general',
        status: SupportTicketStatus.OPEN,
        priority: SupportPriority.NORMAL,
        lastMessageAt: new Date(),
        messages: {
          create: { authorId: user.id, body: input.body },
        },
      },
    });

    return this.detail(ticket.id, user);
  }

  /** Her tickets, newest activity first. */
  async listMine(userId: string) {
    const tickets = await this.prisma.supportTicket.findMany({
      where: { userId },
      orderBy: [{ lastMessageAt: 'desc' }, { createdAt: 'desc' }],
      include: { _count: { select: { messages: true } } },
    });

    return tickets.map((ticket) => this.serializeSummary(ticket));
  }

  async detail(ticketId: string, viewer: AuthUser) {
    const ticket = await this.load(ticketId, viewer);
    const isStaff = this.isStaff(viewer.role);

    const messages = await this.prisma.supportMessage.findMany({
      where: {
        ticketId,
        // An internal note is support talking to support. Filtered out rather
        // than marked hidden: a message she can see the existence of is a
        // message she will ask about.
        ...(isStaff ? {} : { internal: false }),
      },
      orderBy: { createdAt: 'asc' },
    });

    return {
      ...this.serializeSummary({ ...ticket, _count: { messages: messages.length } }),
      messages: messages.map((message) => ({
        id: message.id,
        body: message.body,
        internal: message.internal,
        is_mine: message.authorId === viewer.id,
        // Whether it came from the platform at all — she should be able to
        // tell an answer from her own message at a glance.
        from_support: message.authorId !== ticket.userId,
        created_at: message.createdAt,
      })),
    };
  }

  async reply(
    ticketId: string,
    author: AuthUser,
    input: { body: string; internal?: boolean },
  ) {
    const ticket = await this.load(ticketId, author);

    if (ticket.status === SupportTicketStatus.CLOSED) {
      throw new BadRequestException(
        'This conversation is closed — open a new one',
      );
    }

    const isStaff = this.isStaff(author.role);
    if (input.internal && !isStaff) {
      throw new ForbiddenException('Only support can leave an internal note');
    }

    const message = await this.prisma.supportMessage.create({
      data: {
        ticketId,
        authorId: author.id,
        body: input.body,
        internal: input.internal ?? false,
      },
    });

    await this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: {
        lastMessageAt: message.createdAt,
        // Who spoke last is what the queue is sorted by: a ticket waiting on
        // support is `OPEN`, one waiting on her is `PENDING`. An internal note
        // moves neither — it is not an answer.
        ...(input.internal
          ? {}
          : {
              status: isStaff
                ? SupportTicketStatus.PENDING
                : SupportTicketStatus.OPEN,
            }),
      },
    });

    return {
      id: message.id,
      body: message.body,
      internal: message.internal,
      is_mine: true,
      from_support: isStaff,
      created_at: message.createdAt,
    };
  }

  /** She can close her own conversation; so can support. */
  async close(ticketId: string, user: AuthUser) {
    await this.load(ticketId, user);
    await this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: { status: SupportTicketStatus.CLOSED },
    });
    return { message: 'Ticket closed' };
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /**
   * Loads a ticket the reader is part of.
   *
   * Not a 403 for a stranger: confirming that a ticket id exists tells whoever
   * guessed it that somebody had a problem, which is not theirs to know.
   */
  private async load(ticketId: string, user: AuthUser) {
    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
    });
    if (!ticket) throw new NotFoundException('Ticket not found');
    if (ticket.userId !== user.id && !this.isStaff(user.role)) {
      throw new NotFoundException('Ticket not found');
    }
    return ticket;
  }

  private isStaff(role: UserRole): boolean {
    return (
      role === UserRole.SUPER_ADMIN ||
      role === UserRole.SUPPORT_ADMIN ||
      role === UserRole.OPERATIONS_ADMIN ||
      role === UserRole.SUPPORT ||
      role === UserRole.ADMIN
    );
  }

  private serializeSummary(ticket: {
    id: string;
    subject: string;
    status: SupportTicketStatus;
    priority: SupportPriority;
    category: string;
    lastMessageAt: Date | null;
    createdAt: Date;
    _count: { messages: number };
  }) {
    return {
      id: ticket.id,
      subject: ticket.subject,
      status: ticket.status,
      priority: ticket.priority,
      category: ticket.category,
      messages_count: ticket._count.messages,
      last_message_at: ticket.lastMessageAt,
      created_at: ticket.createdAt,
    };
  }
}
