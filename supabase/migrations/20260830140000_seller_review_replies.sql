-- GENERATED from backend/prisma/migrations/20260830140000_seller_review_replies/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: a3b08cd0044d9c075787d155571c74e6d3fed16f7b255ef24fdb2697177eb93e

SET search_path = public, extensions;


-- A seller could read every review of her and answer none of them.
--
-- On a marketplace the reply matters more than the rating: a customer reading
-- «القياس صغير» learns something different when the seller has written
-- «صحيح، الموديل ضيّق — خذي مقاساً أكبر» underneath it. Without somewhere to
-- put that, the only remedy a seller had for an unfair review was to ask a
-- moderator to remove it.
--
-- The reply is a column on the review rather than a row of its own: there is
-- at most one, it belongs to whoever is being reviewed, and it is edited in
-- place. A thread would imply a conversation the platform does not moderate.
ALTER TABLE "product_reviews"
  ADD COLUMN "seller_reply" TEXT,
  ADD COLUMN "seller_replied_at" TIMESTAMP(3);

ALTER TABLE "seller_reviews"
  ADD COLUMN "seller_reply" TEXT,
  ADD COLUMN "seller_replied_at" TIMESTAMP(3);


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'a3b08cd0044d9c075787d155571c74e6d3fed16f7b255ef24fdb2697177eb93e', now(), '20260830140000_seller_review_replies', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260830140000_seller_review_replies');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
