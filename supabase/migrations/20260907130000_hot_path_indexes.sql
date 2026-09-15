-- GENERATED from backend/prisma/migrations/20260907130000_hot_path_indexes/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 5aba89fb3e4cc2bfc6ed1ae30ee72f6e74ce92f6054bf15448872dfe0a921c11

SET search_path = public, extensions;


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


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '5aba89fb3e4cc2bfc6ed1ae30ee72f6e74ce92f6054bf15448872dfe0a921c11', now(), '20260907130000_hot_path_indexes', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260907130000_hot_path_indexes');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
