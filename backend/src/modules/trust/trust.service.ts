import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import {
  Prisma,
  ReviewStatus,
  TrustBand,
  TrustSignalStatus,
  TrustSubject,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { TrustFactsService } from './trust-facts.service';
import {
  RiskReading,
  scoreMultiAccount,
  scoreRefundAbuse,
  scoreReview,
  scoreSellerConduct,
} from './kernel/trust-risk';

/** Readings below WATCH are not written. See `record`. */
const KEEP_FROM: TrustBand = TrustBand.WATCH;

@Injectable()
export class TrustService {
  private readonly logger = new Logger(TrustService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly facts: TrustFactsService,
  ) {}

  // ── Scoring one subject ──────────────────────────────────────────────────

  async scoreOneReview(reviewId: string) {
    const facts = await this.facts.forReview(reviewId);
    if (!facts) throw new NotFoundException('Review not found');
    return this.record(TrustSubject.REVIEW, reviewId, scoreReview(facts));
  }

  async scoreCustomerRefunds(userId: string) {
    const facts = await this.facts.forRefunds(userId);
    return this.record(
      TrustSubject.CUSTOMER_REFUNDS,
      userId,
      scoreRefundAbuse(facts),
    );
  }

  async scoreCustomerIdentity(userId: string) {
    const facts = await this.facts.forIdentity(userId);
    return this.record(
      TrustSubject.CUSTOMER_IDENTITY,
      userId,
      scoreMultiAccount(facts),
    );
  }

  async scoreSellerConduct(sellerId: string) {
    const facts = await this.facts.forSellerConduct(sellerId);
    return this.record(
      TrustSubject.SELLER_CONDUCT,
      sellerId,
      scoreSellerConduct(facts),
    );
  }

  // ── Sweeps ───────────────────────────────────────────────────────────────

  /**
   * Scores reviews written since the last sweep.
   *
   * Bounded by `limit` rather than running the whole table, because this is a
   * scheduled job on a marketplace that will one day have a million reviews
   * and the honest failure mode of an unbounded sweep is a nightly outage.
   */
  async sweepReviews(sinceDays: number, limit: number) {
    const since = new Date(Date.now() - sinceDays * 24 * 60 * 60 * 1000);
    const reviews = await this.prisma.productReview.findMany({
      where: { createdAt: { gte: since } },
      select: { id: true },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    let flagged = 0;
    for (const review of reviews) {
      try {
        const signal = await this.scoreOneReview(review.id);
        if (signal) flagged += 1;
      } catch (error) {
        // One unreadable review must not stop the sweep.
        this.logger.warn(`Review ${review.id} not scored: ${String(error)}`);
      }
    }
    return { scanned: reviews.length, flagged };
  }

  /**
   * Scores customers who have had a parcel delivered or a return move
   * recently — the only ones whose refund reading can have changed.
   */
  async sweepCustomers(sinceDays: number, limit: number) {
    const since = new Date(Date.now() - sinceDays * 24 * 60 * 60 * 1000);
    // Guest orders carry no `userId`, and a guest has no account to score:
    // there is no history to read, nothing to link her to, and nobody to
    // flag. Q46 P1 allows guest checkout, so this is a normal case rather
    // than a gap — the cash-risk scorer is what looks at those orders.
    const rows = await this.prisma.order.findMany({
      where: { createdAt: { gte: since }, userId: { not: null } },
      select: { userId: true },
      distinct: ['userId'],
      take: limit,
    });

    let flagged = 0;
    for (const row of rows) {
      if (!row.userId) continue;
      try {
        const refunds = await this.scoreCustomerRefunds(row.userId);
        const identity = await this.scoreCustomerIdentity(row.userId);
        flagged += [refunds, identity].filter(Boolean).length;
      } catch (error) {
        this.logger.warn(`Customer ${row.userId} not scored: ${String(error)}`);
      }
    }
    return { scanned: rows.length, flagged };
  }

  /**
   * Scores boutiques that have moved a parcel recently — the only ones whose
   * conduct reading can have changed.
   */
  async sweepSellers(sinceDays: number, limit: number) {
    const since = new Date(Date.now() - sinceDays * 24 * 60 * 60 * 1000);
    const rows = await this.prisma.sellerOrder.findMany({
      where: { createdAt: { gte: since } },
      select: { sellerId: true },
      distinct: ['sellerId'],
      take: limit,
    });

    let flagged = 0;
    for (const row of rows) {
      try {
        if (await this.scoreSellerConduct(row.sellerId)) flagged += 1;
      } catch (error) {
        this.logger.warn(`Seller ${row.sellerId} not scored: ${String(error)}`);
      }
    }
    return { scanned: rows.length, flagged };
  }

  // ── The queue ────────────────────────────────────────────────────────────

  async queue(options: {
    subject?: TrustSubject;
    band?: TrustBand;
    status?: TrustSignalStatus;
    limit: number;
    skip: number;
  }) {
    const where: Prisma.TrustSignalWhereInput = {
      ...(options.subject ? { subject: options.subject } : {}),
      ...(options.band ? { band: options.band } : {}),
      // Open by default: a queue that shows settled cases is a list, not a queue.
      status: options.status ?? TrustSignalStatus.OPEN,
    };

    const [rows, total] = await Promise.all([
      this.prisma.trustSignal.findMany({
        where,
        orderBy: [{ score: 'desc' }, { createdAt: 'desc' }],
        take: options.limit,
        skip: options.skip,
        include: {
          resolvedBy: { select: { id: true, name: true } },
        },
      }),
      this.prisma.trustSignal.count({ where }),
    ]);

    // The subjects, fetched in one round per kind rather than per row.
    const context = await this.contextFor(rows);

    return {
      data: rows.map((row) => ({
        id: row.id,
        subject: row.subject.toLowerCase(),
        subject_id: row.subjectId,
        score: row.score,
        band: row.band.toLowerCase(),
        status: row.status.toLowerCase(),
        reasons: row.reasons,
        note: row.note,
        resolved_by: row.resolvedBy
          ? { id: row.resolvedBy.id, name: row.resolvedBy.name }
          : null,
        resolved_at: row.resolvedAt?.toISOString() ?? null,
        created_at: row.createdAt.toISOString(),
        context: context.get(`${row.subject}:${row.subjectId}`) ?? null,
      })),
      total,
    };
  }

  /**
   * Records what a person decided.
   *
   * `CONFIRMED` on a review is the one action that touches the thing itself:
   * the review is rejected, which is what hides it from the product page.
   * Nothing else in this module changes any state a customer can see —
   * confirming refund abuse or a linked cluster records the finding and leaves
   * what to do about it to the people who can talk to her.
   */
  async resolve(input: {
    signalId: string;
    status: TrustSignalStatus;
    note?: string | null;
    actorId: string;
  }) {
    const signal = await this.prisma.trustSignal.findUnique({
      where: { id: input.signalId },
    });
    if (!signal) throw new NotFoundException('Signal not found');

    const updated = await this.prisma.$transaction(async (tx) => {
      const row = await tx.trustSignal.update({
        where: { id: input.signalId },
        data: {
          status: input.status,
          note: input.note ?? null,
          resolvedById: input.actorId,
          resolvedAt: new Date(),
        },
      });

      if (
        signal.subject === TrustSubject.REVIEW &&
        input.status === TrustSignalStatus.CONFIRMED
      ) {
        await tx.productReview.updateMany({
          where: { id: signal.subjectId },
          data: { status: ReviewStatus.REJECTED },
        });
      }

      return row;
    });

    return {
      id: updated.id,
      status: updated.status.toLowerCase(),
      resolved_at: updated.resolvedAt?.toISOString() ?? null,
    };
  }

  // ── internals ────────────────────────────────────────────────────────────

  /**
   * Writes a reading, or clears one.
   *
   * Three rules, and each of them is what keeps this a queue somebody works
   * rather than a table somebody stops opening:
   *
   * A `CLEAR` reading deletes any open flag rather than storing a row saying
   * nothing is wrong. Behaviour changes; a customer flagged in March who has
   * bought normally since should not still be in the queue.
   *
   * A signal a person has already ruled on is left alone. Re-flagging a review
   * a moderator dismissed yesterday, on the same evidence, is how a queue
   * teaches its readers to ignore it.
   *
   * Otherwise the existing row is updated in place — one reading per subject,
   * never a nightly stack of copies.
   */
  private async record(
    subject: TrustSubject,
    subjectId: string,
    reading: RiskReading,
  ) {
    const key = { subject_subjectId: { subject, subjectId } };
    const existing = await this.prisma.trustSignal.findUnique({ where: key });

    if (reading.band === TrustBand.CLEAR || reading.score < 25) {
      if (existing && existing.status === TrustSignalStatus.OPEN) {
        await this.prisma.trustSignal.delete({ where: key });
      }
      return null;
    }

    if (existing && existing.status !== TrustSignalStatus.OPEN) {
      return null;
    }

    const data = {
      score: reading.score,
      band: reading.band as TrustBand,
      reasons: reading.reasons as unknown as Prisma.InputJsonValue,
    };

    return this.prisma.trustSignal.upsert({
      where: key,
      create: { subject, subjectId, ...data },
      update: data,
    });
  }

  /**
   * Enough of each subject for the queue to be readable without a click.
   *
   * A moderator deciding whether a review is bought needs the review's words
   * in front of her; a row that says only "REVIEW 7f3a…" is a lookup exercise,
   * not a queue.
   */
  private async contextFor(
    rows: { subject: TrustSubject; subjectId: string }[],
  ): Promise<Map<string, unknown>> {
    const byKind = new Map<TrustSubject, string[]>();
    for (const row of rows) {
      byKind.set(row.subject, [
        ...(byKind.get(row.subject) ?? []),
        row.subjectId,
      ]);
    }

    const out = new Map<string, unknown>();

    const reviewIds = byKind.get(TrustSubject.REVIEW) ?? [];
    if (reviewIds.length) {
      const reviews = await this.prisma.productReview.findMany({
        where: { id: { in: reviewIds } },
        select: {
          id: true,
          rating: true,
          body: true,
          status: true,
          createdAt: true,
          product: { select: { id: true, title: true, slug: true } },
          user: { select: { id: true, name: true } },
        },
      });
      for (const review of reviews) {
        out.set(`${TrustSubject.REVIEW}:${review.id}`, {
          rating: review.rating,
          body: review.body,
          status: review.status.toLowerCase(),
          created_at: review.createdAt.toISOString(),
          product: review.product,
          author: review.user,
        });
      }
    }

    const customerIds = [
      ...(byKind.get(TrustSubject.CUSTOMER_REFUNDS) ?? []),
      ...(byKind.get(TrustSubject.CUSTOMER_IDENTITY) ?? []),
      ...(byKind.get(TrustSubject.SELLER_CONDUCT) ?? []),
    ];
    if (customerIds.length) {
      const users = await this.prisma.user.findMany({
        where: { id: { in: [...new Set(customerIds)] } },
        select: { id: true, name: true, username: true, createdAt: true },
      });
      for (const user of users) {
        const value = {
          name: user.name,
          username: user.username,
          joined_at: user.createdAt.toISOString(),
        };
        out.set(`${TrustSubject.CUSTOMER_REFUNDS}:${user.id}`, value);
        out.set(`${TrustSubject.CUSTOMER_IDENTITY}:${user.id}`, value);
        out.set(`${TrustSubject.SELLER_CONDUCT}:${user.id}`, value);
      }
    }

    return out;
  }
}
