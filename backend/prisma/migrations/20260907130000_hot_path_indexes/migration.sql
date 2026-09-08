-- Five foreign keys that carry real traffic and had nothing behind them.
--
-- A survey of the schema found 66 single-column foreign keys with no index
-- leading on them. Most are harmless — admin tables, one-row-per-parent
-- relations, columns nothing filters on — and indexing all of them would cost
-- write throughput to buy nothing. These five are the ones on paths the app
-- actually walks:
--
--   product_media               every product card loads its images, and this
--                               table had no index whatsoever, so each batch
--                               of cards read all of it
--   commerce_content_comments   `listReplies` filters on parent_id alone; the
--                               existing composite leads with content_id and
--                               could not serve it
--   favorites                   the unique key leads with user_id, so "who
--                               saved this piece" and the cascade behind a
--                               removed listing both scanned
--   cart_items, order_items     both are reached from the offer when a seller
--                               withdraws a listing, and both scanned to do it
--
-- The rest are recorded in the audit rather than indexed on speculation.
CREATE INDEX IF NOT EXISTS "product_media_product_id_sort_order_idx"
  ON "product_media" ("product_id", "sort_order");

CREATE INDEX IF NOT EXISTS "commerce_content_comments_parent_id_created_at_idx"
  ON "commerce_content_comments" ("parent_id", "created_at");

CREATE INDEX IF NOT EXISTS "favorites_product_id_idx"
  ON "favorites" ("product_id");

CREATE INDEX IF NOT EXISTS "cart_items_offer_id_idx"
  ON "cart_items" ("offer_id");

CREATE INDEX IF NOT EXISTS "order_items_offer_id_idx"
  ON "order_items" ("offer_id");
