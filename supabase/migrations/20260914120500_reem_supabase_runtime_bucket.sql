-- ─────────────────────────────────────────────────────────────────────────────
-- Reem on Supabase · runtime assets
--
-- `reem-runtime` holds files the api function loads at cold start instead of
-- carrying them in its bundle — today, Prisma's WASM query compiler (see
-- supabase/edge/src/runtime/prisma-wasm.ts), which keeps the bundle under the
-- 5 MB limit for deploys without Docker. (Made public in the next migration.)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('reem-runtime', 'reem-runtime', false, 10485760, ARRAY['application/wasm'])
ON CONFLICT (id) DO UPDATE
  SET public             = false,
      file_size_limit    = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;
