-- GENERATED from backend/prisma/migrations/20260908160000_customer_profiles/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 680d2f47c6b624966e11a0112080dc29b54e99ff59f9445286ba528e067ef93b

SET search_path = public, extensions;


-- What the platform has worked out about each customer.
--
-- Four readings — how likely she is to buy, how likely she is to leave, what
-- she is worth, and when she is awake — cached so the jobs and rankings that
-- consume them do not each recompute over a hundred thousand events.
--
-- A cache and never a source of truth: every figure is derived from orders and
-- analytics events that stay exactly where they are, and the whole table can
-- be dropped and rebuilt from them. `computed_at` is stored rather than implied
-- so a screen can say how old a reading is instead of presenting yesterday's
-- as today's.
--
-- The scoring itself lives in `customer-intelligence/kernel`, deterministic and
-- explainable, and its central idea is that a customer is judged against *her
-- own* cadence rather than a fixed number of days. Sixty days of silence from
-- a woman who buys every three weeks and from one who buys twice a year are
-- opposite facts, and a fixed "lapsed at 90 days" rule — which is what almost
-- every marketplace ships — is wrong about one of them whichever number it
-- picks.
-- CreateTable
CREATE TABLE "customer_profiles" (
    "user_id" UUID NOT NULL,
    "propensity_score" DOUBLE PRECISION NOT NULL,
    "propensity_band" TEXT NOT NULL,
    "churn_score" DOUBLE PRECISION NOT NULL,
    "churn_band" TEXT NOT NULL,
    "cadence_days" DOUBLE PRECISION,
    "realised_value" DECIMAL(18,4) NOT NULL,
    "projected_value" DECIMAL(18,4) NOT NULL,
    "value_horizon_days" INTEGER NOT NULL,
    "currency" "Currency" NOT NULL DEFAULT 'SYP',
    "best_contact_hour" INTEGER,
    "signals" JSONB NOT NULL,
    "confident" BOOLEAN NOT NULL DEFAULT false,
    "computed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "customer_profiles_pkey" PRIMARY KEY ("user_id")
);

-- CreateIndex
CREATE INDEX "customer_profiles_churn_band_churn_score_idx" ON "customer_profiles"("churn_band", "churn_score");

-- CreateIndex
CREATE INDEX "customer_profiles_propensity_band_propensity_score_idx" ON "customer_profiles"("propensity_band", "propensity_score");

-- CreateIndex
CREATE INDEX "customer_profiles_computed_at_idx" ON "customer_profiles"("computed_at");

-- AddForeignKey
ALTER TABLE "customer_profiles" ADD CONSTRAINT "customer_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '680d2f47c6b624966e11a0112080dc29b54e99ff59f9445286ba528e067ef93b', now(), '20260908160000_customer_profiles', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908160000_customer_profiles');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
