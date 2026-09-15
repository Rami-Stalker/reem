-- GENERATED from backend/prisma/migrations/20260908090000_search_synonyms_and_duplicates/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: cefbe37d2d7bc9f787c19cc29b16cc4b5a8bde392dcbdcd23fc7d897e8df66b5

SET search_path = public, extensions;


-- Two things folding cannot do: know that شنطة means حقيبة, and notice that
-- two boutiques have listed the same dress twice.
--
-- `reem_search_key` makes every *spelling* of one word agree. It has nothing
-- to say about two different words for one garment — شنطة and حقيبة share no
-- letters, so no amount of trigram similarity will ever connect them — and
-- Levantine retail runs on those pairs. That has to be told to the system,
-- which is what `search_synonym_groups` is for.
--
-- It is a table and not a constant because the platform already knows which
-- words it is missing: every search that returned nothing is recorded by
-- `TrendSignalService`. A merchandiser reading that list can now answer it
-- without waiting for a release.
--
-- `product_duplicate_verdicts` holds the other half: detection is recomputed
-- from the catalogue as it stands, but a pair somebody has already ruled on
-- must stop coming back, or the queue re-serves the same two dresses every
-- morning and nobody reads it twice.

-- CreateEnum
CREATE TYPE "DuplicateVerdict" AS ENUM ('DUPLICATE', 'DISTINCT');

-- CreateTable
CREATE TABLE "search_synonym_groups" (
    "id" UUID NOT NULL,
    "note" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "created_by_id" UUID,

    CONSTRAINT "search_synonym_groups_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "search_synonym_terms" (
    "id" UUID NOT NULL,
    "group_id" UUID NOT NULL,
    "term" TEXT NOT NULL,
    "term_key" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "search_synonym_terms_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_duplicate_verdicts" (
    "id" UUID NOT NULL,
    "left_product_id" UUID NOT NULL,
    "right_product_id" UUID NOT NULL,
    "verdict" "DuplicateVerdict" NOT NULL,
    "note" TEXT,
    "decided_by_id" UUID,
    "decided_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "product_duplicate_verdicts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "search_synonym_groups_is_active_idx" ON "search_synonym_groups"("is_active");

-- CreateIndex
CREATE INDEX "search_synonym_groups_created_by_id_idx" ON "search_synonym_groups"("created_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "search_synonym_terms_term_key_key" ON "search_synonym_terms"("term_key");

-- CreateIndex
CREATE INDEX "search_synonym_terms_group_id_idx" ON "search_synonym_terms"("group_id");

-- CreateIndex
CREATE INDEX "product_duplicate_verdicts_right_product_id_idx" ON "product_duplicate_verdicts"("right_product_id");

-- CreateIndex
CREATE INDEX "product_duplicate_verdicts_decided_by_id_idx" ON "product_duplicate_verdicts"("decided_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "product_duplicate_verdicts_left_product_id_right_product_id_key" ON "product_duplicate_verdicts"("left_product_id", "right_product_id");

-- AddForeignKey
ALTER TABLE "search_synonym_groups" ADD CONSTRAINT "search_synonym_groups_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "search_synonym_terms" ADD CONSTRAINT "search_synonym_terms_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "search_synonym_groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_duplicate_verdicts" ADD CONSTRAINT "product_duplicate_verdicts_left_product_id_fkey" FOREIGN KEY ("left_product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_duplicate_verdicts" ADD CONSTRAINT "product_duplicate_verdicts_right_product_id_fkey" FOREIGN KEY ("right_product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_duplicate_verdicts" ADD CONSTRAINT "product_duplicate_verdicts_decided_by_id_fkey" FOREIGN KEY ("decided_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;



-- ── A starting vocabulary ─────────────────────────────────────────────
-- Folded through `reem_search_key` in the statement itself, so a seeded key
-- can never disagree with the function that will be asked to match it.
-- `ON CONFLICT DO NOTHING`: a word belongs to one meaning, and a re-run or a
-- word a merchandiser has already claimed must not raise.

WITH g AS (
  INSERT INTO "search_synonym_groups" (id, note, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'حقيبة يد', true, now(), now())
  RETURNING id
)
INSERT INTO "search_synonym_terms" (id, group_id, term, term_key, created_at)
SELECT gen_random_uuid(), g.id, t.term, reem_search_key(t.term), now()
FROM g, (VALUES ('حقيبة'),('شنطة')) AS t(term)
ON CONFLICT (term_key) DO NOTHING;

WITH g AS (
  INSERT INTO "search_synonym_groups" (id, note, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'حذاء', true, now(), now())
  RETURNING id
)
INSERT INTO "search_synonym_terms" (id, group_id, term, term_key, created_at)
SELECT gen_random_uuid(), g.id, t.term, reem_search_key(t.term), now()
FROM g, (VALUES ('حذاء'),('جزمة'),('صباط'),('كندرة')) AS t(term)
ON CONFLICT (term_key) DO NOTHING;

WITH g AS (
  INSERT INTO "search_synonym_groups" (id, note, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'تنورة', true, now(), now())
  RETURNING id
)
INSERT INTO "search_synonym_terms" (id, group_id, term, term_key, created_at)
SELECT gen_random_uuid(), g.id, t.term, reem_search_key(t.term), now()
FROM g, (VALUES ('تنورة'),('جيبة'),('جونلة')) AS t(term)
ON CONFLICT (term_key) DO NOTHING;

WITH g AS (
  INSERT INTO "search_synonym_groups" (id, note, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'بنطلون', true, now(), now())
  RETURNING id
)
INSERT INTO "search_synonym_terms" (id, group_id, term, term_key, created_at)
SELECT gen_random_uuid(), g.id, t.term, reem_search_key(t.term), now()
FROM g, (VALUES ('بنطلون'),('بنطال')) AS t(term)
ON CONFLICT (term_key) DO NOTHING;

WITH g AS (
  INSERT INTO "search_synonym_groups" (id, note, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'عطر', true, now(), now())
  RETURNING id
)
INSERT INTO "search_synonym_terms" (id, group_id, term, term_key, created_at)
SELECT gen_random_uuid(), g.id, t.term, reem_search_key(t.term), now()
FROM g, (VALUES ('عطر'),('بارفان'),('برفان')) AS t(term)
ON CONFLICT (term_key) DO NOTHING;

WITH g AS (
  INSERT INTO "search_synonym_groups" (id, note, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'مكياج', true, now(), now())
  RETURNING id
)
INSERT INTO "search_synonym_terms" (id, group_id, term, term_key, created_at)
SELECT gen_random_uuid(), g.id, t.term, reem_search_key(t.term), now()
FROM g, (VALUES ('مكياج'),('ماكياج')) AS t(term)
ON CONFLICT (term_key) DO NOTHING;

WITH g AS (
  INSERT INTO "search_synonym_groups" (id, note, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'محفظة', true, now(), now())
  RETURNING id
)
INSERT INTO "search_synonym_terms" (id, group_id, term, term_key, created_at)
SELECT gen_random_uuid(), g.id, t.term, reem_search_key(t.term), now()
FROM g, (VALUES ('محفظة'),('جزدان')) AS t(term)
ON CONFLICT (term_key) DO NOTHING;

WITH g AS (
  INSERT INTO "search_synonym_groups" (id, note, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'نظارة', true, now(), now())
  RETURNING id
)
INSERT INTO "search_synonym_terms" (id, group_id, term, term_key, created_at)
SELECT gen_random_uuid(), g.id, t.term, reem_search_key(t.term), now()
FROM g, (VALUES ('نظارة'),('عوينات')) AS t(term)
ON CONFLICT (term_key) DO NOTHING;

WITH g AS (
  INSERT INTO "search_synonym_groups" (id, note, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'خاتم', true, now(), now())
  RETURNING id
)
INSERT INTO "search_synonym_terms" (id, group_id, term, term_key, created_at)
SELECT gen_random_uuid(), g.id, t.term, reem_search_key(t.term), now()
FROM g, (VALUES ('خاتم'),('محبس')) AS t(term)
ON CONFLICT (term_key) DO NOTHING;

WITH g AS (
  INSERT INTO "search_synonym_groups" (id, note, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'قرط', true, now(), now())
  RETURNING id
)
INSERT INTO "search_synonym_terms" (id, group_id, term, term_key, created_at)
SELECT gen_random_uuid(), g.id, t.term, reem_search_key(t.term), now()
FROM g, (VALUES ('قرط'),('حلق')) AS t(term)
ON CONFLICT (term_key) DO NOTHING;

WITH g AS (
  INSERT INTO "search_synonym_groups" (id, note, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'سوار', true, now(), now())
  RETURNING id
)
INSERT INTO "search_synonym_terms" (id, group_id, term, term_key, created_at)
SELECT gen_random_uuid(), g.id, t.term, reem_search_key(t.term), now()
FROM g, (VALUES ('سوار'),('أسورة')) AS t(term)
ON CONFLICT (term_key) DO NOTHING;

WITH g AS (
  INSERT INTO "search_synonym_groups" (id, note, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'عباءة', true, now(), now())
  RETURNING id
)
INSERT INTO "search_synonym_terms" (id, group_id, term, term_key, created_at)
SELECT gen_random_uuid(), g.id, t.term, reem_search_key(t.term), now()
FROM g, (VALUES ('عباية'),('عباءة')) AS t(term)
ON CONFLICT (term_key) DO NOTHING;

WITH g AS (
  INSERT INTO "search_synonym_groups" (id, note, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'وشاح', true, now(), now())
  RETURNING id
)
INSERT INTO "search_synonym_terms" (id, group_id, term, term_key, created_at)
SELECT gen_random_uuid(), g.id, t.term, reem_search_key(t.term), now()
FROM g, (VALUES ('وشاح'),('شال'),('إيشارب')) AS t(term)
ON CONFLICT (term_key) DO NOTHING;

WITH g AS (
  INSERT INTO "search_synonym_groups" (id, note, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'معطف', true, now(), now())
  RETURNING id
)
INSERT INTO "search_synonym_terms" (id, group_id, term, term_key, created_at)
SELECT gen_random_uuid(), g.id, t.term, reem_search_key(t.term), now()
FROM g, (VALUES ('معطف'),('جاكيت'),('كبوت')) AS t(term)
ON CONFLICT (term_key) DO NOTHING;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'cefbe37d2d7bc9f787c19cc29b16cc4b5a8bde392dcbdcd23fc7d897e8df66b5', now(), '20260908090000_search_synonyms_and_duplicates', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908090000_search_synonyms_and_duplicates');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
