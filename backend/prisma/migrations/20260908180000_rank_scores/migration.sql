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

