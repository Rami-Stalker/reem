-- GENERATED from backend/prisma/migrations/20260907120000_arabic_search/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 11c826368c98abcc72fb6b28938032a2f7512283e926ba527645280ce68426e2

SET search_path = public, extensions;


-- Arabic search: a matching key, and an index that can serve it.
--
-- Search matched with `ILIKE '%q%'` against the raw column, which for an
-- Arabic-first catalogue meant it mostly did not match. Arabic writes the same
-- word several ways and every one of them is correct: عباية and عبايه differ
-- only in the last letter, أحمر and احمر only in a hamza the phone keyboard
-- may not have produced, and a listing typed with harakat matched nothing a
-- customer typed without them. A woman searching for عبايه was told the shop
-- had no abayas. It had plenty.
--
-- `reem_search_key` is the form both sides of a comparison are put into, and
-- it does two jobs.
--
-- The first is folding: harakat and tatweel dropped, the lam-alef ligatures
-- decomposed, the alef and yeh and teh-marbuta families collapsed to one
-- spelling each, Persian letterforms folded onto their Arabic counterparts,
-- Arabic-Indic digits rewritten as ASCII, case lowered, whitespace collapsed.
-- That alone is most of the win — it is what makes the three spellings of
-- عباية one word.
--
-- The second is transliteration into ASCII, and it is here because of how
-- this database was provisioned. `datctype` is `C`, so PostgreSQL classifies
-- only ASCII as word characters, and `pg_trgm` — which asks exactly that
-- question when it cuts a string into trigrams — returns an EMPTY trigram set
-- for Arabic text. Verified on this database: `show_trgm('عبايه')` is `{}`,
-- and `similarity('عبايه','عبايه')` is 0. A typo-tolerance feature built on
-- the folded Arabic would have matched nothing at all, silently, and looked
-- like an empty catalogue rather than a broken index. Rather than re-create
-- the cluster under a different ctype — which is a restore, not a migration,
-- and which would leave every other deployment to remember the same thing —
-- each letter is mapped to one ASCII alphanumeric. The key is never shown to
-- anyone; it exists only to be compared.
--
-- The mapping is one-to-one, so a substring of the key is a substring of the
-- word: `LIKE` on the key means what it meant before, and `similarity` now
-- means something where it previously meant nothing.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE OR REPLACE FUNCTION reem_search_key(input text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT btrim(
    regexp_replace(
      translate(
        translate(
          regexp_replace(
            replace(lower(coalesce(input, '')), 'ﻵ', 'لا'),
            '[ًٌٍَُِّْٰٕٖٜٟٓٔٗ٘ٙٚٛٝٞـﻵﻶﻷﻸﻹﻺﻻﻼ]', '', 'g'
          ),
          'أإآٱةىؤئکیڪ٠۰١۱٢۲٣۳٤۴٥۵٦۶٧۷٨۸٩۹',
          'ااااهيويكيك00112233445566778899'
        ),
        'ابتثجحخدذرزسشصضطظعغفقكلمنهويء',
        'abtvj7xdzr5sc96483gfqklmnhwy2'
      ),
      '\s+', ' ', 'g'
    )
  );
$$;

COMMENT ON FUNCTION reem_search_key(text) IS
  'Matching key for Arabic search: folded, then transliterated to ASCII so pg_trgm can index it under a C ctype. Mirrored in TypeScript by searchKey() in src/modules/search/arabic.ts, and the two are checked against each other by arabic.spec.ts.';

-- The previous attempt indexed the folded Arabic directly. Those indexes
-- cannot match anything, for the reason above; they are replaced rather than
-- kept beside the working ones.
DROP INDEX IF EXISTS products_title_folded_trgm_idx;
DROP INDEX IF EXISTS products_description_folded_trgm_idx;
DROP INDEX IF EXISTS categories_name_ar_folded_trgm_idx;
DROP INDEX IF EXISTS brands_name_ar_folded_trgm_idx;
DROP INDEX IF EXISTS brands_name_en_folded_trgm_idx;
DROP INDEX IF EXISTS users_name_folded_trgm_idx;
DROP FUNCTION IF EXISTS reem_fold_arabic(text);

CREATE INDEX IF NOT EXISTS products_title_search_key_idx
  ON products USING gin (reem_search_key(title) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS products_description_search_key_idx
  ON products USING gin (reem_search_key(description) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS categories_name_ar_search_key_idx
  ON categories USING gin (reem_search_key(name_ar) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS brands_name_ar_search_key_idx
  ON brands USING gin (reem_search_key(name_ar) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS users_name_search_key_idx
  ON users USING gin (reem_search_key(name) gin_trgm_ops);

-- Social content is searched by the same key, so a reel captioned عبايه is
-- reachable by someone who typed عباية.
CREATE INDEX IF NOT EXISTS commerce_contents_title_search_key_idx
  ON commerce_contents USING gin (reem_search_key(title) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS commerce_contents_body_search_key_idx
  ON commerce_contents USING gin (reem_search_key(body) gin_trgm_ops);

-- Boutique handles are matched alongside display names.
CREATE INDEX IF NOT EXISTS users_username_search_key_idx
  ON users USING gin (reem_search_key(username) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS categories_name_en_search_key_idx
  ON categories USING gin (reem_search_key(name_en) gin_trgm_ops);


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '11c826368c98abcc72fb6b28938032a2f7512283e926ba527645280ce68426e2', now(), '20260907120000_arabic_search', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260907120000_arabic_search');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
