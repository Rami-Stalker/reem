-- GENERATED from backend/prisma/migrations/20260908130000_seller_conduct/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: b0af2fff312cae9ef2cdec94f935a6ca89620cc0859d028bf45feb17e2bbeb0d

SET search_path = public, extensions;


-- A boutique can be flagged too.
--
-- `SellerHealth` already scores how well a shop is selling — fulfilment,
-- response time, ratings — and answers "should she be doing better". Conduct
-- is the other question: whether the platform is carrying a risk by listing
-- her at all. Refunds running far above what her category does, disputes
-- decided against her, review campaigns on her own listings, cancelling
-- orders after customers have paid. None of that makes a shop *unhealthy* in
-- the performance sense, and none of it was looked for.
--
-- It joins the existing subjects rather than opening a second queue, because
-- the console works all of them the same way: a score, the evidence, a
-- decision.
ALTER TYPE "TrustSubject" ADD VALUE IF NOT EXISTS 'SELLER_CONDUCT';


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'b0af2fff312cae9ef2cdec94f935a6ca89620cc0859d028bf45feb17e2bbeb0d', now(), '20260908130000_seller_conduct', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908130000_seller_conduct');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
