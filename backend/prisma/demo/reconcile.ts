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
    // One statement rather than three: the four counters live on one row now,
    // and `commerce_contents` is the only table a post, a reel and a story all
    // share.
    label: 'commerce_contents engagement counters',
    sql: `UPDATE commerce_contents c
          SET reactions_count = (
                SELECT COUNT(*) FROM commerce_content_reactions r
                 WHERE r.content_id = c.id
              ),
              replies_count = (
                SELECT COUNT(*) FROM commerce_content_comments cc
                 WHERE cc.content_id = c.id AND cc.status = 'VISIBLE'
              ),
              saves_count = (
                SELECT COUNT(*) FROM commerce_content_saves s
                 WHERE s.content_id = c.id
              ),
              views_count = GREATEST(c.views_count, (
                SELECT COALESCE(SUM(v.views_count), 0)
                  FROM commerce_content_viewers v WHERE v.content_id = c.id
              )),
              unique_viewers_count = GREATEST(c.unique_viewers_count, (
                SELECT COUNT(*) FROM commerce_content_viewers v
                 WHERE v.content_id = c.id
              ))`,
  },
  {
    // `shares_count` covers reshares AND external shares, so it can only be
    // floored at the reshare count, never set to it.
    label: 'commerce_contents.shares_count',
    sql: `UPDATE commerce_contents c
          SET shares_count = GREATEST(c.shares_count, (
            SELECT COUNT(*) FROM commerce_content_reshares r
             WHERE r.source_content_id = c.id
          ))`,
  },
  {
    // The privacy mirror. A stale `true` here publishes a woman's page to
    // strangers, so it is reconciled like a counter and not trusted to have
    // been kept in step.
    label: 'author_is_public / resharer_is_public',
    sql: `UPDATE commerce_contents c
          SET author_is_public = u.profile_is_public
          FROM users u WHERE u.id = c.author_id
            AND c.author_is_public IS DISTINCT FROM u.profile_is_public`,
  },
  {
    // The boutique's «مين نشر منتجاتي» read model.
    //
    // A projection, so it is rebuilt rather than incremented — every row is
    // derivable from the author, the product tags and the reshares. Note the
    // shape: `gen_random_uuid()` sits OUTSIDE the DISTINCT. Written the obvious
    // way, every row would be unique by construction, the DISTINCT would do
    // nothing, and a post tagging two of a boutique's products would count
    // twice.
    label: 'commerce_content_attributions (projection)',
    sql: `WITH derived AS (
            SELECT c.id AS content_id, c.author_id AS seller_id,
                   'AUTHOR'::"CommerceAttributionSource" AS source,
                   NULL::uuid AS product_id, NULL::uuid AS reshare_id,
                   c.author_id AS actor_id, c.created_at AS created_at
              FROM commerce_contents c
             WHERE c.author_kind = 'SELLER'
            UNION
            SELECT DISTINCT c.id, o.seller_id,
                   'PRODUCT_TAG'::"CommerceAttributionSource",
                   t.product_id, NULL::uuid, c.author_id, c.created_at
              FROM commerce_contents c
              JOIN commerce_content_product_tags t ON t.content_id = c.id
              JOIN seller_offers o ON o.product_id = t.product_id
                                  AND o.status = 'ACTIVE' AND o.is_active
             WHERE o.seller_id <> c.author_id
          ), with_reshares AS (
            SELECT * FROM derived
            UNION ALL
            SELECT d.content_id, d.seller_id,
                   'RESHARE'::"CommerceAttributionSource",
                   d.product_id, r.id, r.resharer_id, r.created_at
              FROM derived d
              JOIN commerce_content_reshares r ON r.source_content_id = d.content_id
          )
          INSERT INTO commerce_content_attributions
            (id, content_id, seller_id, source, product_id, reshare_id, actor_id, created_at)
          SELECT gen_random_uuid(), w.content_id, w.seller_id, w.source,
                 w.product_id, w.reshare_id, w.actor_id, w.created_at
            FROM with_reshares w
           WHERE NOT EXISTS (
             SELECT 1 FROM commerce_content_attributions a
              WHERE a.content_id = w.content_id
                AND a.seller_id = w.seller_id
                AND a.source = w.source
                AND a.product_id IS NOT DISTINCT FROM w.product_id
                AND a.reshare_id IS NOT DISTINCT FROM w.reshare_id
           )`,
  },
  {
    label: 'commerce_content_reshares.resharer_is_public',
    sql: `UPDATE commerce_content_reshares r
          SET resharer_is_public = u.profile_is_public
          FROM users u WHERE u.id = r.resharer_id
            AND r.resharer_is_public IS DISTINCT FROM u.profile_is_public`,
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
