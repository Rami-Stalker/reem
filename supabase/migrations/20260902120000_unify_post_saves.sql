-- GENERATED from backend/prisma/migrations/20260902120000_unify_post_saves/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 9863ee82f0e27afbb748a37cbac7b12dedfdd92731edaa00e982035fb597511a

SET search_path = public, extensions;


-- One table for "she saved this post".
--
-- `post_favorites` and `post_saves` recorded the same gesture from two
-- different surfaces: the feed card wrote `post_saves` via /posts/:id/save,
-- the wishlist endpoints wrote `post_favorites`. Neither read the other, so a
-- post bookmarked in the feed never reached «منشورات محفوظة», and one saved
-- from the wishlist came back from the feed showing an empty bookmark.
--
-- Rows are moved rather than dropped, duplicates collapse on the unique pair,
-- and `saves_count` is recomputed from the surviving table — it had been
-- incremented by both writers, so a post saved through each route counted two.

INSERT INTO "post_saves" ("id", "post_id", "user_id", "created_at")
SELECT gen_random_uuid(), "post_id", "user_id", "created_at"
FROM "post_favorites"
ON CONFLICT ("post_id", "user_id") DO NOTHING;

UPDATE "posts" p
SET "saves_count" = (
  SELECT COUNT(*) FROM "post_saves" ps WHERE ps."post_id" = p."id"
);

DROP TABLE "post_favorites";


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '9863ee82f0e27afbb748a37cbac7b12dedfdd92731edaa00e982035fb597511a', now(), '20260902120000_unify_post_saves', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260902120000_unify_post_saves');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
