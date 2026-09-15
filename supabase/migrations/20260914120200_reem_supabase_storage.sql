-- ─────────────────────────────────────────────────────────────────────────────
-- Reem on Supabase · 3/5 · Storage
--
-- Two buckets, mirroring the two roots `LocalDiskDriver` keeps on a server:
--
--   reem-media-public    product photographs, content media, avatars. Public:
--                        served straight from Storage's CDN at
--                        /storage/v1/object/public/reem-media-public/<key>.
--   reem-media-private   seller identity documents, chat attachments, closet
--                        and visual-search photographs. Private: no URL works
--                        without the project secret; the API streams bytes to
--                        a client only after its own authorisation check.
--
-- Both are written only by the api function (the backend's upload pipeline
-- sniffs bytes, enforces quotas and records ownership before anything is
-- stored). `storage.objects` therefore has no policy for `anon` or
-- `authenticated` at all: a client with the publishable key can neither list,
-- read through the authenticated endpoint, upload, overwrite nor delete.
-- Public objects remain readable through the public endpoint, which is the
-- point of the public bucket.
--
-- The size limit is 50 MB, the Free plan's ceiling. The backend accepts video
-- up to 64 MB (MEDIA_MAX_VIDEO_BYTES); on Pro, raise the project limit in the
-- dashboard and this bucket limit together.
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  (
    'reem-media-public', 'reem-media-public', true, 52428800,
    ARRAY[
      'image/jpeg', 'image/png', 'image/gif', 'image/webp',
      'video/mp4', 'video/quicktime',
      'audio/mp4', 'audio/ogg', 'audio/wav', 'audio/mpeg'
    ]
  ),
  (
    'reem-media-private', 'reem-media-private', false, 52428800,
    ARRAY[
      'image/jpeg', 'image/png', 'image/gif', 'image/webp',
      'video/mp4', 'video/quicktime',
      'audio/mp4', 'audio/ogg', 'audio/wav', 'audio/mpeg',
      'application/pdf'
    ]
  )
ON CONFLICT (id) DO UPDATE
  SET public             = EXCLUDED.public,
      file_size_limit    = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;
