-- ─────────────────────────────────────────────────────────────────────────────
-- Reem on Supabase · runtime assets are served from the CDN
--
-- Supabase starts a fresh isolate for most requests, so the Prisma query
-- compiler is fetched on nearly every API call. A public object is served from
-- Storage's CDN instead of the authenticated endpoint. It is Prisma's
-- open-source compiler, nothing secret; only the deploy script (secret key)
-- writes the bucket, and the function verifies each object's SHA-256 against
-- the digest compiled into its bundle, so a replaced object cannot run.
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE storage.buckets SET public = true WHERE id = 'reem-runtime';
