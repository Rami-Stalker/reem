import { PrismaClient } from '@prisma/client';

/**
 * Recomputes every denormalised counter from the rows that were actually
 * written.
 *
 * The generators create engagement in whatever order is convenient, so the
 * counters they set along the way are only ever provisional. This pass makes
 * the invariant the app relies on true again — `likes_count` equals
 * `COUNT(post_likes)`, `rating` equals the average of approved reviews — which
 * matters because the read paths serve the column, not the join, and a demo
 * whose numbers disagree with its own tables is worse than no demo.
 *
 * `views_count` is reconciled from `analytics_events` — the trend engine
 * writes a PRODUCT_VIEW row for every open, so the column has a table behind
 * it after all, and the figure on the product page is now the number of times
 * the page was actually opened rather than a number the seed invented.
 */
const STATEMENTS: { label: string; sql: string }[] = [
  {
    label: 'products.favorites_count',
    sql: `UPDATE products p
          SET favorites_count = (
            SELECT COUNT(*) FROM favorites f WHERE f.product_id = p.id
          )`,
  },
  {
    label: 'products.reviews_count / rating',
    sql: `UPDATE products p
          SET reviews_count = COALESCE(r.total, 0),
              rating = COALESCE(ROUND(r.average::numeric, 2), 0)
          FROM (
            SELECT pr.product_id,
                   COUNT(*) AS total,
                   AVG(pr.rating) AS average
            FROM product_reviews pr
            WHERE pr.status = 'APPROVED'
            GROUP BY pr.product_id
          ) r
          WHERE p.id = r.product_id`,
  },
  {
    label: 'products.reviews_count (zero case)',
    sql: `UPDATE products p
          SET reviews_count = 0, rating = 0
          WHERE NOT EXISTS (
            SELECT 1 FROM product_reviews pr
            WHERE pr.product_id = p.id AND pr.status = 'APPROVED'
          )`,
  },
  {
    label: 'products.views_count',
    sql: `UPDATE products p
          SET views_count = COALESCE((
            SELECT COUNT(*)
            FROM analytics_events ae
            WHERE ae.product_id = p.id
              AND ae.type = 'PRODUCT_VIEW'
          ), 0)`,
  },
  {
    label: 'products.orders_count',
    sql: `UPDATE products p
          SET orders_count = COALESCE((
            SELECT SUM(oi.quantity)
            FROM order_items oi
            JOIN seller_orders so ON so.id = oi.seller_order_id
            JOIN orders o ON o.id = so.order_id
            WHERE oi.product_id = p.id
              AND o.status NOT IN ('CANCELLED', 'PENDING_PAYMENT')
          ), 0)`,
  },
  {
    label: 'posts.likes_count',
    sql: `UPDATE posts p
          SET likes_count = (
            SELECT COUNT(*) FROM post_likes pl WHERE pl.post_id = p.id
          )`,
  },
  {
    label: 'posts.comments_count',
    sql: `UPDATE posts p
          SET comments_count = (
            SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id
          )`,
  },
  {
    label: 'posts.saves_count',
    sql: `UPDATE posts p
          SET saves_count = (
            SELECT COUNT(*) FROM post_saves ps WHERE ps.post_id = p.id
          )`,
  },
  {
    label: 'users.followers_count / following_count',
    sql: `UPDATE users u
          SET followers_count = (
                SELECT COUNT(*) FROM follows f WHERE f.following_id = u.id
              ),
              following_count = (
                SELECT COUNT(*) FROM follows f WHERE f.follower_id = u.id
              )`,
  },
  {
    label: 'coupons.used_count',
    sql: `UPDATE coupons c
          SET used_count = (
            SELECT COUNT(*) FROM coupon_redemptions r WHERE r.coupon_id = c.id
          )`,
  },
];

export async function reconcileCounters(prisma: PrismaClient): Promise<void> {
  for (const statement of STATEMENTS) {
    await prisma.$executeRawUnsafe(statement.sql);
  }
}
