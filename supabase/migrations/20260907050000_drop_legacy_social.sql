-- GENERATED from backend/prisma/migrations/20260907050000_drop_legacy_social/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 76f2da24ca58f986e6643442bd62592d3cf29ac5d63adfe10b21c452986e33a8

SET search_path = public, extensions;


-- The legacy social tables go.
--
-- Nothing writes them: `/posts/*`, `/stories/*`, `/seller/posts`,
-- `/seller/stories`, favourites, guest saves, search, the value collector and
-- the authorization ownership checks were all moved onto `commerce_contents`
-- in the release that precedes this one. Every row was copied by
-- `20260907030000_backfill_social_content`, with ids preserved, and the
-- contract fixtures were regenerated from the new implementation with no key
-- dropped or renamed on any of the eight endpoints.
--
-- **This is the one irreversible step**, and the mitigations are the release
-- gap before it and the snapshot taken beside it. Everything up to here can be
-- undone: the backfilled rows are exactly those whose `payload->>'legacy'` is
-- set, so `DELETE FROM commerce_contents WHERE payload->>'legacy' IS NOT NULL`
-- unwinds it and the cascades clean the children. After this, the way back is
-- a restore.
--
-- CASCADE is doing real work here: it takes the four child tables
-- (`post_likes`, `post_saves`, `comments`, `story_views`, `story_reactions`)
-- along with their parents, which is why they are named explicitly above it —
-- a reader should not have to know the FK graph to know what this deletes.

DROP TABLE IF EXISTS "story_reactions" CASCADE;
DROP TABLE IF EXISTS "story_views" CASCADE;
DROP TABLE IF EXISTS "stories" CASCADE;
DROP TABLE IF EXISTS "comments" CASCADE;
DROP TABLE IF EXISTS "post_saves" CASCADE;
DROP TABLE IF EXISTS "post_likes" CASCADE;
DROP TABLE IF EXISTS "posts" CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '76f2da24ca58f986e6643442bd62592d3cf29ac5d63adfe10b21c452986e33a8', now(), '20260907050000_drop_legacy_social', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260907050000_drop_legacy_social');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
