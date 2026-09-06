import { Injectable, Logger } from '@nestjs/common';
import {
  DeliveryFailureReason,
  DisputeStatus,
  Prisma,
  ReferralStatus,
  ReviewStatus,
  ShipmentStatus,
  ValueEvent,
  ValueEventStatus,
  ValuePillar,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ValuePolicyService } from './value-policy.service';
import { ValueScoringService } from './value-scoring.service';
import { EARNING_RULE_BY_CODE, MATURITY } from './value.constants';

/**
 * Where standing actually comes from.
 *
 * A collector rather than a set of hooks, and that is the load-bearing choice
 * in this file. Every contribution is discovered by *querying for its evidence*
 * — a review that has three helpful votes, a referral whose customer kept her
 * order, a parcel that was refused at the door — rather than by a module
 * calling in to say something happened.
 *
 * Three things follow from it, and all three are the anti-manipulation design:
 *
 *  1. **Nothing counts on the strength of an action alone.** There is no path
 *     from "she posted" to "she earned"; there is only a path from "the post
 *     was engaged with" to "she earned". Writing something is free, and this
 *     engine pays for none of it.
 *  2. **It is idempotent.** Every event carries `dedupeKey`, unique per user,
 *     so a sweep can run every hour, be interrupted, and run again without
 *     double-counting anything.
 *  3. **It reverses.** The same queries that confirm evidence detect its
 *     collapse — a review taken down, an order sent back, a referral flagged —
 *     and the event goes to REVERSED. A points balance, once credited, is
 *     almost never clawed back; a standing is only ever the current truth.
 *
 * The cost of the choice is that six modules are read from here. That is
 * accepted deliberately: the alternative is six modules that know about
 * standing, and a change to what Reem values becoming a change to the reviews
 * module.
 */
@Injectable()
export class ValueCollectorService {
  private readonly logger = new Logger(ValueCollectorService.name);

  /** How far back a sweep looks for new evidence. */
  private static readonly WINDOW_DAYS = 45;

  /** Rows examined per source per sweep. */
  private static readonly BATCH = 500;

  constructor(
    private readonly prisma: PrismaService,
    private readonly policies: ValuePolicyService,
    private readonly scoring: ValueScoringService,
  ) {}

  // ── Writing ───────────────────────────────────────────────────────────

  /**
   * Record one contribution, once.
   *
   * The weight is stamped from the policy at write time and never touched
   * again — see `ValueEvent.weight`. `update: {}` on the conflict is the whole
   * idempotency guarantee: a second sighting of the same evidence changes
   * nothing, which is what lets the sweep be safely re-run.
   */
  async record(input: {
    userId: string;
    code: string;
    occurredAt: Date;
    subjectType?: string;
    subjectId?: string;
    evidence?: Record<string, unknown>;
    status?: ValueEventStatus;
  }): Promise<ValueEvent | null> {
    const rule = EARNING_RULE_BY_CODE.get(input.code);
    if (!rule) {
      this.logger.warn(`Unknown earning rule: ${input.code}`);
      return null;
    }

    const profile = await this.scoring.findOrCreate(input.userId);
    // A frozen profile stops accruing. Nothing is lost — the evidence is still
    // in the source tables, and a later sweep picks it up once she is unfrozen.
    if (profile.frozenAt) return null;

    const weight = await this.policies.weightFor(input.code);
    const dedupeKey = `${input.code}:${input.subjectId ?? 'global'}`;

    return this.prisma.valueEvent.upsert({
      where: { userId_dedupeKey: { userId: input.userId, dedupeKey } },
      create: {
        profileId: profile.id,
        userId: input.userId,
        pillar: rule.pillar,
        code: input.code,
        status: input.status ?? ValueEventStatus.CONFIRMED,
        weight,
        dedupeKey,
        subjectType: input.subjectType ?? null,
        subjectId: input.subjectId ?? null,
        evidence: (input.evidence ?? {}) as Prisma.InputJsonValue,
        occurredAt: input.occurredAt,
        confirmedAt:
          (input.status ?? ValueEventStatus.CONFIRMED) === ValueEventStatus.CONFIRMED
            ? new Date()
            : null,
      },
      update: {},
    });
  }

  /** Promote a pending event once its evidence has matured. */
  async confirm(
    userId: string,
    dedupeKey: string,
    evidence?: Record<string, unknown>,
  ): Promise<void> {
    await this.prisma.valueEvent.updateMany({
      where: { userId, dedupeKey, status: ValueEventStatus.PENDING },
      data: {
        status: ValueEventStatus.CONFIRMED,
        confirmedAt: new Date(),
        ...(evidence ? { evidence: evidence as Prisma.InputJsonValue } : {}),
      },
    });
  }

  /**
   * Withdraw a contribution whose evidence collapsed.
   *
   * Never deletes. The row stays, worth nothing, because "why did my standing
   * drop" is a question somebody has to be able to answer, and an absent row
   * answers nothing.
   */
  async reverse(
    subjectType: string,
    subjectId: string,
    reason: string,
  ): Promise<number> {
    const result = await this.prisma.valueEvent.updateMany({
      where: {
        subjectType,
        subjectId,
        status: { in: [ValueEventStatus.PENDING, ValueEventStatus.CONFIRMED] },
      },
      data: {
        status: ValueEventStatus.REVERSED,
        reversedAt: new Date(),
        reversedReason: reason,
      },
    });
    return result.count;
  }

  // ── The sweep ─────────────────────────────────────────────────────────

  /**
   * One pass over every source of evidence.
   *
   * Returns what it found so the scheduler can log it and an administrator can
   * see the programme is alive. Each source is wrapped: one failing query must
   * not stop the other five.
   */
  async sweep(options: { now?: Date } = {}): Promise<Record<string, number>> {
    const now = options.now ?? new Date();
    const since = new Date(now.getTime() - ValueCollectorService.WINDOW_DAYS * 86_400_000);
    const touched = new Set<string>();
    const counts: Record<string, number> = {};

    const sources: Array<[string, () => Promise<string[]>]> = [
      ['reliability', () => this.sweepReliability(since)],
      ['commerce', () => this.sweepCommerce(since)],
      ['craft', () => this.sweepCraft(since)],
      ['community', () => this.sweepCommunity(since)],
      ['advocacy', () => this.sweepAdvocacy(since)],
      ['discovery', () => this.sweepDiscovery(now)],
      ['reversals', () => this.sweepReversals(since)],
    ];

    for (const [name, run] of sources) {
      try {
        const users = await run();
        counts[name] = users.length;
        for (const userId of users) touched.add(userId);
      } catch (error) {
        this.logger.warn(`Value sweep source ${name} failed: ${String(error)}`);
        counts[name] = -1;
      }
    }

    for (const userId of touched) {
      try {
        await this.scoring.recompute(userId, { now });
      } catch (error) {
        this.logger.warn(`Value recompute failed for ${userId}: ${String(error)}`);
      }
    }

    counts.recomputed = touched.size;
    return counts;
  }

  // ── Sources ───────────────────────────────────────────────────────────

  /**
   * What happened at her door.
   *
   * Read from `Shipment`, which is what the courier app writes back, rather
   * than from the COD risk assessment — the assessment is a prediction and this
   * pillar is about what actually occurred. Refusal and non-delivery are kept
   * apart for the same reason the COD kernel keeps them apart: turning a
   * courier away is a decision, a phone that rang out is a scheduling problem,
   * and pricing them the same punishes a woman who works shifts.
   */
  private async sweepReliability(since: Date): Promise<string[]> {
    const shipments = await this.prisma.shipment.findMany({
      where: {
        updatedAt: { gte: since },
        status: { in: [ShipmentStatus.DELIVERED, ShipmentStatus.FAILED] },
      },
      select: {
        id: true,
        status: true,
        failureReason: true,
        deliveredAt: true,
        updatedAt: true,
        sellerOrder: { select: { order: { select: { userId: true } } } },
      },
      take: ValueCollectorService.BATCH,
      orderBy: { updatedAt: 'desc' },
    });

    const touched: string[] = [];
    for (const shipment of shipments) {
      const userId = shipment.sellerOrder.order.userId;
      // A guest checkout has no standing to move.
      if (!userId) continue;

      const code =
        shipment.status === ShipmentStatus.DELIVERED
          ? 'parcel_delivered'
          : shipment.failureReason === DeliveryFailureReason.CUSTOMER_REFUSED
            ? 'parcel_refused'
            : 'parcel_failed';

      await this.record({
        userId,
        code,
        subjectType: 'shipment',
        subjectId: shipment.id,
        occurredAt: shipment.deliveredAt ?? shipment.updatedAt,
        evidence: {
          status: shipment.status,
          failure_reason: shipment.failureReason ?? null,
        },
      });
      touched.push(userId);
    }
    return touched;
  }

  /**
   * Purchases that stuck.
   *
   * Keyed on `escrowReleased`, which is the platform's own definition of a
   * final sale — the return window has closed and the seller has been paid. A
   * purchase that came back is not a contribution, and waiting for this flag is
   * what stops buy-and-return from moving a standing.
   */
  private async sweepCommerce(since: Date): Promise<string[]> {
    const orders = await this.prisma.sellerOrder.findMany({
      where: { escrowReleased: true, updatedAt: { gte: since } },
      select: {
        id: true,
        sellerId: true,
        updatedAt: true,
        itemsSubtotal: true,
        currency: true,
        order: { select: { userId: true } },
      },
      take: ValueCollectorService.BATCH,
      orderBy: { updatedAt: 'desc' },
    });

    const touched: string[] = [];
    for (const order of orders) {
      const userId = order.order.userId;
      if (!userId) continue;

      await this.record({
        userId,
        code: 'order_kept',
        subjectType: 'seller_order',
        subjectId: order.id,
        occurredAt: order.updatedAt,
        evidence: { seller_order: order.id },
      });
      touched.push(userId);

      // Breadth, not depth. A woman who buys from eight boutiques knows the
      // shop better than one who buys eight times from the same one, and only
      // the first kept order from each seller writes this.
      const seenSeller = await this.prisma.valueEvent.findFirst({
        where: {
          userId,
          code: 'order_kept_new_seller',
          subjectType: 'seller',
          subjectId: order.sellerId,
        },
        select: { id: true },
      });
      if (!seenSeller) {
        await this.record({
          userId,
          code: 'order_kept_new_seller',
          subjectType: 'seller',
          subjectId: order.sellerId,
          occurredAt: order.updatedAt,
          evidence: { first_kept_order: order.id },
        });
      }
    }
    return touched;
  }

  /**
   * Reviews other women found useful.
   *
   * Two rules, and the gap between them is the point: writing a review earns a
   * little, and writing one that three other women marked helpful earns four
   * times as much. Reem does not pay for opinions, it pays for opinions that
   * turned out to be worth reading.
   */
  private async sweepCraft(since: Date): Promise<string[]> {
    const touched: string[] = [];

    const reviews = await this.prisma.productReview.findMany({
      where: {
        status: ReviewStatus.APPROVED,
        verifiedPurchase: true,
        updatedAt: { gte: since },
      },
      select: { id: true, userId: true, createdAt: true, helpfulCount: true },
      take: ValueCollectorService.BATCH,
      orderBy: { updatedAt: 'desc' },
    });

    for (const review of reviews) {
      await this.record({
        userId: review.userId,
        code: 'review_written',
        subjectType: 'product_review',
        subjectId: review.id,
        occurredAt: review.createdAt,
        evidence: { verified: true },
      });

      if (review.helpfulCount >= MATURITY.reviewHelpfulVotes) {
        await this.record({
          userId: review.userId,
          code: 'review_helpful',
          subjectType: 'product_review_helpful',
          subjectId: review.id,
          occurredAt: review.createdAt,
          evidence: { helpful_count: review.helpfulCount },
        });
      }
      touched.push(review.userId);
    }

    const sellerReviews = await this.prisma.sellerReview.findMany({
      where: {
        status: ReviewStatus.APPROVED,
        verifiedPurchase: true,
        updatedAt: { gte: since },
      },
      select: { id: true, userId: true, createdAt: true },
      take: ValueCollectorService.BATCH,
      orderBy: { updatedAt: 'desc' },
    });

    for (const review of sellerReviews) {
      await this.record({
        userId: review.userId,
        code: 'seller_review_written',
        subjectType: 'seller_review',
        subjectId: review.id,
        occurredAt: review.createdAt,
        evidence: { verified: true },
      });
      touched.push(review.userId);
    }

    return touched;
  }

  /**
   * What the community engaged with.
   *
   * Posts qualify on likes *plus saves* rather than likes alone: a save is the
   * stronger signal and the harder one to trade between friends. Nothing here
   * pays for posting, only for having been useful to somebody.
   */
  private async sweepCommunity(since: Date): Promise<string[]> {
    const touched: string[] = [];

    const posts = await this.prisma.post.findMany({
      where: { createdAt: { gte: since } },
      select: {
        id: true,
        authorId: true,
        createdAt: true,
        likesCount: true,
        savesCount: true,
      },
      take: ValueCollectorService.BATCH,
      orderBy: { createdAt: 'desc' },
    });

    for (const post of posts) {
      const engagement = post.likesCount + post.savesCount;
      if (engagement < MATURITY.postEngagement) continue;

      await this.record({
        userId: post.authorId,
        code: 'post_engaged',
        subjectType: 'post',
        subjectId: post.id,
        occurredAt: post.createdAt,
        evidence: { likes: post.likesCount, saves: post.savesCount },
      });
      touched.push(post.authorId);
    }

    // Comments on posts that themselves drew a crowd. A comment on a post
    // nobody read helped nobody, whatever it said.
    const comments = await this.prisma.comment.findMany({
      where: {
        createdAt: { gte: since },
        post: { likesCount: { gte: MATURITY.postEngagement } },
      },
      select: { id: true, userId: true, createdAt: true },
      take: ValueCollectorService.BATCH,
      orderBy: { createdAt: 'desc' },
    });

    for (const comment of comments) {
      await this.record({
        userId: comment.userId,
        code: 'comment_engaged',
        subjectType: 'comment',
        subjectId: comment.id,
        occurredAt: comment.createdAt,
      });
      touched.push(comment.userId);
    }

    return touched;
  }

  /**
   * People she brought who turned out to be real.
   *
   * Gated on `QUALIFIED` *and* a fraud score under the threshold. The referral
   * module already decides what qualification means — a first order that was
   * delivered — and re-deciding it here would give Reem two definitions of a
   * real customer.
   */
  private async sweepAdvocacy(since: Date): Promise<string[]> {
    const referrals = await this.prisma.referral.findMany({
      where: {
        status: ReferralStatus.QUALIFIED,
        fraudScore: { lte: MATURITY.referralMaxFraudScore },
        updatedAt: { gte: since },
      },
      select: {
        id: true,
        referrerId: true,
        participantType: true,
        qualifiedAt: true,
        createdAt: true,
        fraudScore: true,
      },
      take: ValueCollectorService.BATCH,
      orderBy: { updatedAt: 'desc' },
    });

    const touched: string[] = [];
    for (const referral of referrals) {
      await this.record({
        userId: referral.referrerId,
        code:
          referral.participantType === 'SELLER'
            ? 'referral_seller_active'
            : 'referral_kept',
        subjectType: 'referral',
        subjectId: referral.id,
        // Dated from when she made the introduction, not when it paid off —
        // decay should measure the age of the act, not of the confirmation.
        occurredAt: referral.createdAt,
        evidence: { fraud_score: referral.fraudScore },
      });
      touched.push(referral.referrerId);
    }
    return touched;
  }

  /**
   * Taste, proven by time.
   *
   * The two-step rule that makes DISCOVERY honest. A favourite on a product
   * still under five orders writes a PENDING event — she was early, and we can
   * only know that *now*. It confirms later, when that product passes fifty,
   * because being early is only worth something if the thing turned out to be
   * good. Neither half works alone: the first would pay for random favouriting,
   * the second would pay everyone who ever touched a bestseller.
   */
  private async sweepDiscovery(now: Date): Promise<string[]> {
    const touched: string[] = [];

    // ── Step one: record the early finds ──────────────────────────────
    const early = await this.prisma.favorite.findMany({
      where: {
        createdAt: { gte: new Date(now.getTime() - 30 * 86_400_000) },
        product: { ordersCount: { lt: MATURITY.discoveryEarlyOrders } },
      },
      select: {
        userId: true,
        productId: true,
        createdAt: true,
        product: { select: { ordersCount: true } },
      },
      take: ValueCollectorService.BATCH,
      orderBy: { createdAt: 'desc' },
    });

    for (const favourite of early) {
      await this.record({
        userId: favourite.userId,
        code: 'early_product',
        subjectType: 'product_discovery',
        subjectId: favourite.productId,
        occurredAt: favourite.createdAt,
        evidence: { orders_at_discovery: favourite.product.ordersCount },
        status: ValueEventStatus.PENDING,
      });
    }

    // ── Step two: confirm the ones that came good ─────────────────────
    const pending = await this.prisma.valueEvent.findMany({
      where: { status: ValueEventStatus.PENDING, code: 'early_product' },
      select: { id: true, userId: true, dedupeKey: true, subjectId: true },
      take: ValueCollectorService.BATCH,
    });

    if (pending.length) {
      const productIds = pending
        .map((event) => event.subjectId)
        .filter((id): id is string => !!id);
      const proven = await this.prisma.product.findMany({
        where: {
          id: { in: productIds },
          ordersCount: { gte: MATURITY.discoveryProvenOrders },
        },
        select: { id: true, ordersCount: true },
      });
      const provenById = new Map(proven.map((product) => [product.id, product]));

      for (const event of pending) {
        const product = event.subjectId ? provenById.get(event.subjectId) : null;
        if (!product) continue;
        await this.confirm(event.userId, event.dedupeKey, {
          orders_now: product.ordersCount,
        });
        touched.push(event.userId);
      }
    }

    return touched;
  }

  /**
   * Evidence that collapsed.
   *
   * The half of the engine that keeps a standing honest. A review taken down in
   * moderation stops counting; a dispute resolved against her costs her; an
   * order that came back takes its commerce contribution with it.
   */
  private async sweepReversals(since: Date): Promise<string[]> {
    const touched: string[] = [];

    const removed = await this.prisma.productReview.findMany({
      where: { status: { not: ReviewStatus.APPROVED }, updatedAt: { gte: since } },
      select: { id: true, userId: true },
      take: ValueCollectorService.BATCH,
    });
    for (const review of removed) {
      const count =
        (await this.reverse('product_review', review.id, 'review_removed')) +
        (await this.reverse('product_review_helpful', review.id, 'review_removed'));
      if (count) touched.push(review.userId);
    }

    // A dispute resolved against her. `RESOLVED_SELLER` means the seller was
    // found right, which is the only outcome that says anything about her.
    const disputes = await this.prisma.dispute.findMany({
      where: {
        status: DisputeStatus.RESOLVED_FOR_SELLER,
        updatedAt: { gte: since },
      },
      select: {
        id: true,
        openedById: true,
        updatedAt: true,
        sellerOrder: { select: { order: { select: { userId: true } } } },
      },
      take: ValueCollectorService.BATCH,
    });

    for (const dispute of disputes) {
      const userId = dispute.sellerOrder.order.userId;
      // Only when she is the one who opened it: a seller-opened dispute
      // resolved in the seller's favour is not evidence about the customer.
      if (!userId || dispute.openedById !== userId) continue;
      await this.record({
        userId,
        code: 'dispute_lost',
        subjectType: 'dispute',
        subjectId: dispute.id,
        occurredAt: dispute.updatedAt,
      });
      touched.push(userId);
    }

    return touched;
  }
}
