import { Injectable } from '@nestjs/common';
import { Prisma, UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { utcTimestamp } from '../../common/sql/utc-timestamp';
import { AudienceSpec, hasInterestGroups } from './ad-plans';

/** How far back «مهتمة بهذا النوع» looks. */
const INTEREST_WINDOW_DAYS = 30;

/** Seller-order statuses that are not a purchase. */
const NOT_A_PURCHASE = ['CANCELLED_BY_CUSTOMER', 'CANCELLED_BY_SELLER'];

/** A placement's audience, with what it needs from the viewer. */
export interface TargetedCandidate {
  sellerId: string;
  categoryId: string;
  audience: AudienceSpec;
}

/** What one shopper is, as far as these campaigns ask. */
interface ViewerFacts {
  governorates: Set<string>;
  follows: Set<string>;
  boughtFrom: Set<string>;
  interestedIn: Set<string>;
  hasOrdered: boolean;
}

/**
 * Who a campaign is for.
 *
 * The rules in one place: a TARGETED campaign is shown to a signed-in shopper
 * when she is in one of the chosen governorates (if any were chosen) AND in
 * one of the chosen groups (if any were chosen). A guest sees only campaigns
 * meant for everyone — she has no address, follows and orders to match.
 *
 * Nothing about her leaves this service. A boutique is told how many women its
 * audience holds, never which women they are.
 */
@Injectable()
export class AdAudienceService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Which of `candidates` this viewer may be shown, as a parallel boolean
   * array. Loads only the facts the targeted candidates actually ask about,
   * and only for their sellers and categories.
   */
  async matches(
    viewerId: string | undefined,
    candidates: readonly TargetedCandidate[],
  ): Promise<boolean[]> {
    const targeted = candidates.filter((c) => c.audience.targeted);
    if (targeted.length === 0) return candidates.map(() => true);
    if (!viewerId) return candidates.map((c) => !c.audience.targeted);

    const facts = await this.factsFor(viewerId, targeted);
    return candidates.map((c) => !c.audience.targeted || this.fits(c, facts));
  }

  private fits(c: TargetedCandidate, facts: ViewerFacts): boolean {
    const a = c.audience;
    if (a.governorates.length > 0 && !a.governorates.some((g) => facts.governorates.has(g))) {
      return false;
    }
    if (!hasInterestGroups(a)) return true;
    return (
      (a.followers && facts.follows.has(c.sellerId)) ||
      (a.pastBuyers && facts.boughtFrom.has(c.sellerId)) ||
      (a.interested && facts.interestedIn.has(c.categoryId)) ||
      (a.newShoppers && !facts.hasOrdered)
    );
  }

  private async factsFor(
    viewerId: string,
    targeted: readonly TargetedCandidate[],
  ): Promise<ViewerFacts> {
    const need = {
      location: targeted.some((c) => c.audience.governorates.length > 0),
      follows: targeted.some((c) => c.audience.followers),
      bought: targeted.some((c) => c.audience.pastBuyers),
      interest: targeted.some((c) => c.audience.interested),
      ordered: targeted.some((c) => c.audience.newShoppers),
    };
    const sellerIds = [...new Set(targeted.map((c) => c.sellerId))];
    const categoryIds = [...new Set(targeted.map((c) => c.categoryId))];
    const since = new Date(Date.now() - INTEREST_WINDOW_DAYS * 86_400_000);

    const [addresses, follows, bought, interest, anyOrder] = await Promise.all([
      need.location
        ? this.prisma.address.findMany({
            where: { userId: viewerId },
            select: { governorate: true },
          })
        : [],
      need.follows
        ? this.prisma.follow.findMany({
            where: { followerId: viewerId, followingId: { in: sellerIds } },
            select: { followingId: true },
          })
        : [],
      need.bought
        ? this.prisma.sellerOrder.findMany({
            where: {
              sellerId: { in: sellerIds },
              order: { userId: viewerId },
              status: { notIn: NOT_A_PURCHASE as never[] },
            },
            select: { sellerId: true },
            distinct: ['sellerId'],
          })
        : [],
      need.interest
        ? this.prisma.$queryRaw<{ category_id: string }[]>`
            SELECT DISTINCT p.category_id
              FROM products p
             WHERE p.category_id = ANY(${categoryIds}::uuid[])
               AND (
                 EXISTS (SELECT 1 FROM favorites f
                          WHERE f.user_id = ${viewerId}::uuid AND f.product_id = p.id
                            AND f.created_at >= ${utcTimestamp(since)})
                 OR EXISTS (SELECT 1 FROM analytics_events e
                             WHERE e.user_id = ${viewerId}::uuid AND e.product_id = p.id
                               AND e.type IN ('PRODUCT_VIEW', 'PRODUCT_FAVORITE', 'CART_ADD')
                               AND e.occurred_at >= ${utcTimestamp(since)})
               )`
        : [],
      need.ordered
        ? this.prisma.order.findFirst({ where: { userId: viewerId }, select: { id: true } })
        : null,
    ]);

    return {
      governorates: new Set(addresses.map((a) => a.governorate.trim())),
      follows: new Set(follows.map((f) => f.followingId)),
      boughtFrom: new Set(bought.map((b) => b.sellerId)),
      interestedIn: new Set(interest.map((i) => i.category_id)),
      hasOrdered: anyOrder !== null,
    };
  }

  /**
   * How many shoppers a campaign would reach — the number a boutique sees
   * before she pays. Counted, never listed.
   */
  async estimateReach(
    sellerId: string,
    categoryId: string,
    audience: AudienceSpec,
  ): Promise<{ shoppers: number; total_shoppers: number }> {
    const base = Prisma.sql`
      u.role = ${UserRole.CUSTOMER}::"UserRole"
      AND u.deleted_at IS NULL AND u.disabled_at IS NULL`;
    const [{ total }] = await this.prisma.$queryRaw<{ total: bigint }[]>`
      SELECT COUNT(*)::bigint AS total FROM users u WHERE ${base}`;
    const totalShoppers = Number(total);
    if (!audience.targeted) return { shoppers: totalShoppers, total_shoppers: totalShoppers };

    const since = new Date(Date.now() - INTEREST_WINDOW_DAYS * 86_400_000);
    const location =
      audience.governorates.length > 0
        ? Prisma.sql`AND EXISTS (SELECT 1 FROM addresses a WHERE a.user_id = u.id
                                   AND btrim(a.governorate) = ANY(${[...audience.governorates]}::text[]))`
        : Prisma.empty;

    const groups: Prisma.Sql[] = [];
    if (audience.followers) {
      groups.push(Prisma.sql`EXISTS (SELECT 1 FROM follows f
        WHERE f.follower_id = u.id AND f.following_id = ${sellerId}::uuid)`);
    }
    if (audience.pastBuyers) {
      groups.push(Prisma.sql`EXISTS (SELECT 1 FROM seller_orders so JOIN orders o ON o.id = so.order_id
        WHERE o.user_id = u.id AND so.seller_id = ${sellerId}::uuid
          AND so.status::text <> ALL(${NOT_A_PURCHASE}::text[]))`);
    }
    if (audience.interested) {
      groups.push(Prisma.sql`(
        EXISTS (SELECT 1 FROM favorites fv JOIN products p ON p.id = fv.product_id
                 WHERE fv.user_id = u.id AND p.category_id = ${categoryId}::uuid
                   AND fv.created_at >= ${utcTimestamp(since)})
        OR EXISTS (SELECT 1 FROM analytics_events e JOIN products p ON p.id = e.product_id
                    WHERE e.user_id = u.id AND p.category_id = ${categoryId}::uuid
                      AND e.type IN ('PRODUCT_VIEW', 'PRODUCT_FAVORITE', 'CART_ADD')
                      AND e.occurred_at >= ${utcTimestamp(since)}))`);
    }
    if (audience.newShoppers) {
      groups.push(Prisma.sql`NOT EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id)`);
    }
    const interest =
      groups.length > 0 ? Prisma.sql`AND (${Prisma.join(groups, ' OR ')})` : Prisma.empty;

    const [{ n }] = await this.prisma.$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*)::bigint AS n FROM users u WHERE ${base} ${location} ${interest}`;
    return { shoppers: Number(n), total_shoppers: totalShoppers };
  }

  /**
   * The governorates her shoppers actually live in, most common first — the
   * choices offered when she targets by location, so she picks from places
   * that hold customers rather than typing a name that matches nobody.
   */
  async governorates(): Promise<{ name: string; shoppers: number }[]> {
    const rows = await this.prisma.$queryRaw<{ name: string; n: bigint }[]>`
      SELECT btrim(a.governorate) AS name, COUNT(DISTINCT a.user_id)::bigint AS n
        FROM addresses a JOIN users u ON u.id = a.user_id
       WHERE u.role = ${UserRole.CUSTOMER}::"UserRole" AND u.deleted_at IS NULL
         AND btrim(a.governorate) <> ''
       GROUP BY 1 ORDER BY 2 DESC, 1 ASC LIMIT 30`;
    return rows.map((row) => ({ name: row.name, shoppers: Number(row.n) }));
  }
}
