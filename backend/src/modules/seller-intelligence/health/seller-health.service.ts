import { Injectable, Logger } from '@nestjs/common';
import {
  Prisma,
  ReturnStatus,
  ReviewStatus,
  SellerHealthBand,
  SellerOrderStatus,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { utcTimestamp } from '../../../common/sql/utc-timestamp';
import {
  HEALTH_BAND_AR,
  HEALTH_WINDOW_DAYS,
} from '../intelligence.constants';
import {
  HealthAdvice,
  SellerHealthFacts,
  SellerHealthResult,
  adviseSellerHealth,
  scoreSellerHealth,
} from '../kernel/seller-health';

/**
 * The states an order stops moving in.
 *
 * Anything not in this list is still travelling, and an order in transit is
 * evidence of neither success nor failure. Naming the set here rather than
 * inline because every rate in this file divides by some version of it, and
 * they must all mean the same thing.
 */
const SETTLED_STATUSES = [
  SellerOrderStatus.DELIVERED,
  SellerOrderStatus.DELIVERY_FAILED,
  SellerOrderStatus.CANCELLED_BY_CUSTOMER,
  SellerOrderStatus.CANCELLED_BY_SELLER,
  SellerOrderStatus.REJECTED_ON_DELIVERY,
  SellerOrderStatus.RETURNED,
  SellerOrderStatus.EXCHANGED,
  SellerOrderStatus.REFUNDED,
] as const;

/**
 * Measuring a shop.
 *
 * The seam between the health kernel and the database. Its whole job is to
 * fill in `SellerHealthFacts` honestly — every field is a count or a median
 * over rows that already exist, and none of it is estimated, defaulted or
 * assumed.
 *
 * ── What this replaces ───────────────────────────────────────────────────
 *
 * `ReputationService` already wrote a `performanceScore`, a `fulfillmentScore`
 * and a `responseScore` onto `SellerReputation`. Two of those were thin and
 * the third was the literal constant `90` — nobody's response time was ever
 * measured, and every seller on the platform carried the same fabricated
 * number. This service computes all eight dimensions from rows, including the
 * one that was invented, and hands the honest figures back to
 * `SellerReputation` so the rest of the app keeps reading one source.
 *
 * ── Why the medians are computed in SQL ──────────────────────────────────
 *
 * A median needs the whole distribution, and pulling ninety days of orders
 * into Node to sort them would be the kind of query that is fine on the
 * demo seed and falls over on a real shop. `percentile_cont` does it in the
 * database, over an index, and returns one row.
 */
@Injectable()
export class SellerHealthService {
  private readonly logger = new Logger(SellerHealthService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Her health today, computed fresh.
   *
   * Not read from the snapshot: the snapshot is the historical record, and a
   * seller who has just shipped three parcels should see that reflected when
   * she opens the screen rather than seeing last night's sweep.
   */
  async current(
    sellerId: string,
    options: { windowDays?: number; now?: Date } = {},
  ): Promise<{
    result: SellerHealthResult;
    advice: HealthAdvice[];
    facts: SellerHealthFacts;
    bandAr: string;
    momentum: number;
    windowDays: number;
  }> {
    const windowDays = options.windowDays ?? HEALTH_WINDOW_DAYS;
    const facts = await this.gather(sellerId, windowDays, options.now);
    const result = scoreSellerHealth(facts);

    return {
      result,
      advice: adviseSellerHealth(result, facts),
      facts,
      bandAr: HEALTH_BAND_AR[result.band],
      momentum: await this.momentum(sellerId, result.score, options.now),
      windowDays,
    };
  }

  /**
   * Every fact the kernel needs, from rows.
   *
   * Deliberately one method: the honesty of the score depends entirely on
   * these queries, and scattering them across the class would make it hard to
   * check that nothing is being defaulted.
   */
  async gather(
    sellerId: string,
    windowDays = HEALTH_WINDOW_DAYS,
    now = new Date(),
  ): Promise<SellerHealthFacts> {
    const since = new Date(now.getTime() - windowDays * 86_400_000);
    const orderWindow = { sellerId, createdAt: { gte: since } };

    const [
      settled,
      delivered,
      cancelledBySeller,
      acceptedTotal,
      cancelledByOthers,
      durations,
      returned,
      reviews,
      response,
      listings,
      productReviews,
    ] = await Promise.all([
      // Accepted *and finished*.
      //
      // Two gates, and the second is the one live data caught. Accepted,
      // because a shop cannot be judged on an order it never saw. But also
      // *settled*, because an order still moving through the courier network
      // is not evidence of anything yet — and counting it as a non-delivery
      // scored a seller with a dozen parcels in transit as catastrophically
      // unreliable, which is precisely backwards: a rush of recent orders is
      // the opposite of a failing shop.
      this.prisma.sellerOrder.count({
        where: {
          ...orderWindow,
          confirmedAt: { not: null },
          status: { in: [...SETTLED_STATUSES] },
        },
      }),
      this.prisma.sellerOrder.count({
        where: { ...orderWindow, status: SellerOrderStatus.DELIVERED },
      }),
      this.prisma.sellerOrder.count({
        where: { ...orderWindow, status: SellerOrderStatus.CANCELLED_BY_SELLER },
      }),
      // Everything she has accepted, in flight or not. The cancellation rate
      // divides by this rather than by settled orders: pulling out of an
      // order is a decision she makes *while* it is live, so the honest
      // denominator is everything she took on.
      this.prisma.sellerOrder.count({
        where: { ...orderWindow, confirmedAt: { not: null } },
      }),
      this.prisma.sellerOrder.count({
        where: {
          ...orderWindow,
          status: {
            in: [
              SellerOrderStatus.CANCELLED_BY_CUSTOMER,
              SellerOrderStatus.REJECTED_ON_DELIVERY,
            ],
          },
        },
      }),
      this.durations(sellerId, since),
      this.prisma.returnRequest.count({
        where: {
          sellerOrder: { sellerId },
          createdAt: { gte: since },
          // Only returns that actually went through. A request she talked the
          // buyer out of, or that was refused, is not a returned parcel.
          status: {
            in: [
              ReturnStatus.APPROVED,
              ReturnStatus.IN_TRANSIT,
              ReturnStatus.RECEIVED,
              ReturnStatus.REFUNDED,
              ReturnStatus.EXCHANGED,
            ],
          },
        },
      }),
      // Reviews *of the shop* — the honest source for "was she happy with
      // buying here". Product reviews are a different question and feed the
      // quality dimension instead; counting either one twice would let a
      // single good month carry two dimensions.
      this.prisma.sellerReview.aggregate({
        where: {
          sellerId,
          status: ReviewStatus.APPROVED,
          createdAt: { gte: since },
        },
        _avg: { rating: true },
        _count: { _all: true },
      }),
      this.responseHours(sellerId, since),
      this.listingHealth(sellerId),
      // Reviews *of her pieces*, which is what "product quality" means.
      this.prisma.productReview.aggregate({
        where: {
          product: { offers: { some: { sellerId } } },
          status: ReviewStatus.APPROVED,
          createdAt: { gte: since },
        },
        _avg: { rating: true },
        _count: { _all: true },
      }),
    ]);

    return {
      // `acceptedOrders` is the reliability denominator and therefore the
      // settled count; `cancelledBySeller` is measured against everything she
      // took on, which the kernel receives through `openOrders`.
      acceptedOrders: settled,
      openOrders: Math.max(0, acceptedTotal - settled),
      deliveredOrders: delivered,
      cancelledBySeller,
      cancelledByOthers,
      prepHours: durations.prepHours,
      prepSample: durations.prepSample,
      shipHours: durations.shipHours,
      shipSample: durations.shipSample,
      responseHours: response.hours,
      responseSample: response.sample,
      returnedOrders: returned,
      averageRating: reviews._avg.rating ?? null,
      reviewCount: reviews._count._all,
      // The quality dimension takes both halves of "are her pieces good":
      // how well the listings are built, and how the buyers rated what
      // arrived. Either alone is half the story — a beautifully written
      // listing for a disappointing dress, or a loved piece nobody can find.
      productHealthMean: blend(
        listings.mean,
        productReviews._avg.rating === null
          ? null
          : (productReviews._avg.rating / 5) * 100,
      ),
      productHealthSample: listings.sample + productReviews._count._all,
    };
  }

  /**
   * Median hours to prepare, and median hours in transit.
   *
   * Medians rather than means throughout: one order that sat over a holiday
   * would drag a mean somewhere that misrepresents every other parcel she
   * sent, and a seller looking at a number that does not match her experience
   * stops trusting the whole screen.
   */
  private async durations(
    sellerId: string,
    since: Date,
  ): Promise<{
    prepHours: number | null;
    prepSample: number;
    shipHours: number | null;
    shipSample: number;
  }> {
    const rows = await this.prisma.$queryRaw<
      Array<{
        prep_hours: number | null;
        prep_sample: bigint;
        ship_hours: number | null;
        ship_sample: bigint;
      }>
    >`
      SELECT
        percentile_cont(0.5) WITHIN GROUP (
          ORDER BY EXTRACT(EPOCH FROM (shipped_at - confirmed_at)) / 3600.0
        ) FILTER (WHERE shipped_at IS NOT NULL AND confirmed_at IS NOT NULL)
          AS prep_hours,
        count(*) FILTER (WHERE shipped_at IS NOT NULL AND confirmed_at IS NOT NULL)
          AS prep_sample,
        percentile_cont(0.5) WITHIN GROUP (
          ORDER BY EXTRACT(EPOCH FROM (delivered_at - shipped_at)) / 3600.0
        ) FILTER (WHERE delivered_at IS NOT NULL AND shipped_at IS NOT NULL)
          AS ship_hours,
        count(*) FILTER (WHERE delivered_at IS NOT NULL AND shipped_at IS NOT NULL)
          AS ship_sample
      FROM seller_orders
      WHERE seller_id = ${sellerId}::uuid
        AND created_at >= ${since}
    `;

    const row = rows[0];
    return {
      prepHours: numeric(row?.prep_hours),
      prepSample: Number(row?.prep_sample ?? 0),
      shipHours: numeric(row?.ship_hours),
      shipSample: Number(row?.ship_sample ?? 0),
    };
  }

  /**
   * How long a buyer actually waits for her first reply.
   *
   * The number `ReputationService` used to hardcode as `90`.
   *
   * For every chat she is the seller in, take the buyer's opening message and
   * the first message she sent after it, and measure the gap. One measurement
   * per conversation rather than per message, deliberately: a chat where the
   * buyer sent six messages and she answered once should count as one answered
   * conversation, not six fast replies.
   *
   * Conversations she has not answered at all are excluded rather than counted
   * as infinite — an unanswered chat from an hour ago is not evidence of a
   * slow seller. That is a real limitation and the honest one: the alternative
   * silently punishes shops for questions that arrived this morning.
   */
  private async responseHours(
    sellerId: string,
    since: Date,
  ): Promise<{ hours: number | null; sample: number }> {
    const rows = await this.prisma.$queryRaw<
      Array<{ hours: number | null; sample: bigint }>
    >`
      WITH first_reply AS (
        SELECT
          c.id AS chat_id,
          min(buyer.created_at) AS asked_at,
          min(seller.created_at) FILTER (
            WHERE seller.created_at > (
              SELECT min(b2.created_at)
              FROM messages b2
              WHERE b2.chat_id = c.id AND b2.sender_id = c.buyer_id
            )
          ) AS answered_at
        FROM chats c
        JOIN messages buyer
          ON buyer.chat_id = c.id AND buyer.sender_id = c.buyer_id
        LEFT JOIN messages seller
          ON seller.chat_id = c.id AND seller.sender_id = c.seller_id
        WHERE c.seller_id = ${sellerId}::uuid
          AND c.buyer_id IS NOT NULL
          AND buyer.created_at >= ${utcTimestamp(since)}
        GROUP BY c.id
      )
      SELECT
        percentile_cont(0.5) WITHIN GROUP (
          ORDER BY EXTRACT(EPOCH FROM (answered_at - asked_at)) / 3600.0
        ) AS hours,
        count(*) AS sample
      FROM first_reply
      WHERE answered_at IS NOT NULL
    `;

    const row = rows[0];
    return { hours: numeric(row?.hours), sample: Number(row?.sample ?? 0) };
  }

  /**
   * The mean health of her live listings.
   *
   * Read from `ProductHealthSnapshot` rather than recomputed here: Product
   * Intelligence already decided what a good listing is, and a second opinion
   * living in this file would eventually disagree with the one she can see on
   * the product screen.
   */
  private async listingHealth(
    sellerId: string,
  ): Promise<{ mean: number | null; sample: number }> {
    const rows = await this.prisma.$queryRaw<
      Array<{ mean: number | null; sample: bigint }>
    >`
      SELECT avg(latest.score) AS mean, count(*) AS sample
      FROM (
        SELECT DISTINCT ON (product_id) score
        FROM product_health_snapshots
        WHERE seller_id = ${sellerId}::uuid
        ORDER BY product_id, day DESC
      ) latest
    `;
    const row = rows[0];
    return { mean: numeric(row?.mean), sample: Number(row?.sample ?? 0) };
  }

  /** Score today minus the score thirty days ago, from the record of the time. */
  private async momentum(
    sellerId: string,
    score: number,
    now = new Date(),
  ): Promise<number> {
    const then = new Date(now.getTime() - 30 * 86_400_000);
    const past = await this.prisma.sellerHealthSnapshot.findFirst({
      where: { sellerId, day: { lte: then } },
      orderBy: { day: 'desc' },
      select: { score: true },
    });
    return past ? round(score - past.score) : 0;
  }

  // ── Persistence ────────────────────────────────────────────────────────

  /**
   * Write today's row, and push the honest figures back onto `SellerReputation`.
   *
   * The second half is what stops this becoming a parallel truth. Ranking,
   * the storefront badge and the AI assistant all read `SellerReputation`
   * today; if this service kept its results to itself, the platform would
   * have two opinions about every shop and the older, weaker one would still
   * be the one customers saw.
   */
  async snapshot(
    sellerId: string,
    options: { now?: Date } = {},
  ): Promise<{ score: number; band: SellerHealthBand }> {
    const now = options.now ?? new Date();
    const day = utcDay(now);
    const { result, advice, momentum, windowDays, facts } = await this.current(
      sellerId,
      { now },
    );

    await this.prisma.sellerHealthSnapshot.upsert({
      where: { sellerId_day: { sellerId, day } },
      create: {
        sellerId,
        day,
        score: result.score,
        band: result.band,
        dimensions: result.dimensions as unknown as Prisma.InputJsonValue,
        confidence: result.confidence,
        momentum,
        advice: advice as unknown as Prisma.InputJsonValue,
        windowDays,
      },
      // One row per day: the last run of the day is what she went to bed with.
      update: {
        score: result.score,
        band: result.band,
        dimensions: result.dimensions as unknown as Prisma.InputJsonValue,
        confidence: result.confidence,
        momentum,
        advice: advice as unknown as Prisma.InputJsonValue,
        windowDays,
        computedAt: now,
      },
    });

    await this.syncReputation(sellerId, result, facts);
    return { score: result.score, band: result.band };
  }

  /**
   * Feed the measured dimensions back into the row the rest of the app reads.
   *
   * `performanceScore` becomes the health score itself, and the three
   * component scores become the dimensions that actually correspond to them.
   * `averageRating` and the review counts are left alone — those are
   * `ReputationService`'s own facts and it owns them.
   */
  private async syncReputation(
    sellerId: string,
    result: SellerHealthResult,
    facts: SellerHealthFacts,
  ): Promise<void> {
    const by = new Map(result.dimensions.map((d) => [d.key, d.score]));

    // Only write a component we actually measured. Writing a null through as
    // a zero would recreate exactly the problem this replaces — a number on a
    // seller's record that nothing ever measured.
    const patch: Prisma.SellerReputationUpdateInput = {
      performanceScore: result.score,
      calculatedAt: new Date(),
    };
    const response = by.get('responsiveness');
    const fulfilment = by.get('reliability');
    if (fulfilment !== null && fulfilment !== undefined) {
      patch.fulfillmentScore = fulfilment;
    }
    // Written unconditionally, null included.
    //
    // The other components are skipped when unmeasured because something real
    // may already be there. Responsiveness is the opposite case: the values
    // sitting in this column were invented — a hardcoded 90 from the old
    // reputation service, a random figure from the demo seed — so leaving a
    // stale one in place is the very thing this system exists to stop. If we
    // cannot measure her replies, the column says so.
    patch.responseScore = by.get('responsiveness') ?? null;
    const satisfaction = by.get('satisfaction');
    if (satisfaction !== null && satisfaction !== undefined) {
      patch.customerSatisfactionScore = satisfaction;
    }

    await this.prisma.sellerReputation.upsert({
      where: { sellerId },
      update: patch,
      create: {
        sellerId,
        performanceScore: result.score,
        fulfillmentScore: fulfilment ?? 0,
        responseScore: response,
        customerSatisfactionScore: satisfaction ?? 0,
        averageRating: facts.averageRating ?? 0,
        reviewsCount: facts.reviewCount,
      },
    });
  }

  /** Her history, for the sparkline. */
  async history(sellerId: string, days = 90) {
    const since = utcDay(new Date(Date.now() - days * 86_400_000));
    return this.prisma.sellerHealthSnapshot.findMany({
      where: { sellerId, day: { gte: since } },
      orderBy: { day: 'asc' },
      select: { day: true, score: true, band: true, confidence: true },
    });
  }

  /**
   * Recompute every seller who has traded.
   *
   * Batched and per-seller-isolated, like the Value recompute: one shop with
   * odd data must not stop the rest of the population being scored.
   */
  async snapshotAll(options: { now?: Date } = {}): Promise<number> {
    const sellers = await this.prisma.user.findMany({
      where: { sellerOrders: { some: {} } },
      select: { id: true },
    });

    let done = 0;
    for (const seller of sellers) {
      try {
        await this.snapshot(seller.id, options);
        done += 1;
      } catch (error) {
        this.logger.warn(
          `Seller health failed for ${seller.id}: ${String(error)}`,
        );
      }
    }
    return done;
  }
}

/** The mean of whichever halves we actually have, or null if neither. */
function blend(a: number | null, b: number | null): number | null {
  if (a === null) return b;
  if (b === null) return a;
  return round((a + b) / 2);
}

function numeric(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const n = Number(value);
  return Number.isFinite(n) ? round(n) : null;
}

function round(n: number): number {
  return Math.round(n * 100) / 100;
}

function utcDay(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
}
