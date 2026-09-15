-- GENERATED from backend/prisma/migrations/20260908180000_rank_scores/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 495f5fc7c0eebbd66eb214de6b9bc7bc0d7ebcd1c96916601c6f85ac308a177f

SET search_path = public, extensions;


-- Ordering by evidence rather than by whatever the database returned.
--
-- Stored as a column rather than computed per query for one reason: ordering a
-- catalogue by an expression is a sequential scan, and ordering it by a column
-- is an index. The score is refreshed by a sweep and `rank_scored_at` records
-- when, so a screen can tell a seller how fresh her position is instead of
-- implying it is live.
--
-- The breakdown is stored beside it because a seller will ask why her dress is
-- on page three, and an answer that requires re-deriving the score is an answer
-- nobody gives. See `ranking/kernel/rank.ts` for the weights — and for the
-- three corrections that stop it being gameable: conversion rather than
-- lifetime orders, ratings shrunk towards the catalogue mean so one review
-- from one friend cannot buy the top slot, and views deliberately weak because
-- views are the one signal a seller can manufacture.
-- AlterTable
ALTER TABLE "products" ADD COLUMN     "rank_breakdown" JSONB,
ADD COLUMN     "rank_score" DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN     "rank_scored_at" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "seller_rank_breakdown" JSONB,
ADD COLUMN     "seller_rank_score" DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN     "seller_rank_scored_at" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "products_status_rank_score_idx" ON "products"("status", "rank_score");

-- CreateIndex
CREATE INDEX "users_role_seller_rank_score_idx" ON "users"("role", "seller_rank_score");


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '495f5fc7c0eebbd66eb214de6b9bc7bc0d7ebcd1c96916601c6f85ac308a177f', now(), '20260908180000_rank_scores', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908180000_rank_scores');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
