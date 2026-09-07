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
