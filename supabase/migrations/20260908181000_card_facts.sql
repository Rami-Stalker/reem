-- GENERATED from backend/prisma/migrations/20260908181000_card_facts/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 092108d5dbdde1abb8bb9cfaf394a506cdf904d6e9e7b28c36b97bb27c4d585a

SET search_path = public, extensions;


-- The three facts an honest product card needs.
--
-- Social proof and scarcity only work because they are true, and checking that
-- they are true per card is three joins a page. Most catalogues resolve that
-- either by dropping the badges or by caching a guess that drifts — and a
-- drifted "only 2 left" is a dark pattern whether or not anybody meant it to
-- be. These are refreshed by the same sweep that scores the listing, so the
-- badge and the ranking can never disagree about the same shelf.
-- AlterTable
ALTER TABLE "products" ADD COLUMN     "live_offers_count" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "live_stock" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "recent_orders_30" INTEGER NOT NULL DEFAULT 0;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '092108d5dbdde1abb8bb9cfaf394a506cdf904d6e9e7b28c36b97bb27c4d585a', now(), '20260908181000_card_facts', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908181000_card_facts');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
