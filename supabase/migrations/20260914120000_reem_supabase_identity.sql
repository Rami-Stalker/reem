-- ─────────────────────────────────────────────────────────────────────────────
-- Reem on Supabase · 1/5 · identity
--
-- Everything Supabase-specific lives in the `reem_supabase` schema, never in
-- `public`: `public` is the backend's schema, owned by its Prisma migrations,
-- and must stay byte-for-byte what the backend expects if it is ever pointed at
-- this database again. Prisma does not see this schema; RLS policies do.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS reem_supabase;
REVOKE ALL ON SCHEMA reem_supabase FROM PUBLIC;
-- Policies are evaluated as the querying role, and call the helpers below.
GRANT USAGE ON SCHEMA reem_supabase TO anon, authenticated, service_role;

-- Which Supabase auth user is which Reem user. Written only by the API
-- (`POST /auth/supabase/exchange` and `/auth/supabase/link`), read only through
-- the SECURITY DEFINER helpers below. No client role can touch it.
CREATE TABLE IF NOT EXISTS reem_supabase.identity_links (
  auth_user_id uuid        PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  user_id      uuid        NOT NULL UNIQUE REFERENCES public.users (id) ON DELETE CASCADE,
  linked_at    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE reem_supabase.identity_links ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON reem_supabase.identity_links FROM anon, authenticated;
GRANT ALL ON reem_supabase.identity_links TO service_role;

COMMENT ON TABLE reem_supabase.identity_links IS
  'Supabase auth user ↔ Reem user. Maintained by the api Edge Function; read by RLS helpers.';

-- ── RLS helpers ──────────────────────────────────────────────────────────────
-- SECURITY DEFINER so a policy can resolve the caller without the caller being
-- able to read the tables involved; `search_path = ''` so nothing on the
-- caller's path can shadow a name. STABLE so Postgres evaluates them once per
-- statement when wrapped as `(SELECT reem_supabase.current_user_id())`.

-- The Reem user behind the current Supabase session, or NULL. NULL — and so
-- no access — when there is no link, when the account is disabled, or when the
-- auth user's phone no longer matches the account's (a number that changed
-- hands must not carry its old sessions into someone else's account).
CREATE OR REPLACE FUNCTION reem_supabase.current_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT l.user_id
    FROM reem_supabase.identity_links l
    JOIN auth.users   a ON a.id = l.auth_user_id
    JOIN public.users u ON u.id = l.user_id
   WHERE l.auth_user_id = auth.uid()
     AND u.disabled_at IS NULL
     AND a.phone IS NOT NULL
     AND u.phone = '+' || a.phone
$$;

CREATE OR REPLACE FUNCTION reem_supabase.app_role()
RETURNS public."UserRole"
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT u.role FROM public.users u WHERE u.id = reem_supabase.current_user_id()
$$;

-- Staff: every role the backend treats as platform staff.
CREATE OR REPLACE FUNCTION reem_supabase.is_staff()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(
    reem_supabase.app_role() IN (
      'SUPER_ADMIN', 'OPERATIONS_ADMIN', 'SUPPORT_ADMIN', 'FINANCE_ADMIN',
      'CONTENT_MODERATOR', 'ADMIN', 'SUPPORT'
    ),
    false
  )
$$;

CREATE OR REPLACE FUNCTION reem_supabase.is_seller()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(reem_supabase.app_role() = 'SELLER', false)
$$;

CREATE OR REPLACE FUNCTION reem_supabase.is_chat_member(p_chat_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.chat_participants p
     WHERE p.chat_id = p_chat_id
       AND p.user_id = reem_supabase.current_user_id()
  )
$$;

REVOKE ALL ON FUNCTION reem_supabase.current_user_id()        FROM PUBLIC;
REVOKE ALL ON FUNCTION reem_supabase.app_role()           FROM PUBLIC;
REVOKE ALL ON FUNCTION reem_supabase.is_staff()               FROM PUBLIC;
REVOKE ALL ON FUNCTION reem_supabase.is_seller()              FROM PUBLIC;
REVOKE ALL ON FUNCTION reem_supabase.is_chat_member(uuid)     FROM PUBLIC;
GRANT EXECUTE ON FUNCTION reem_supabase.current_user_id()     TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION reem_supabase.app_role()        TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION reem_supabase.is_staff()            TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION reem_supabase.is_seller()           TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION reem_supabase.is_chat_member(uuid)  TO authenticated, service_role;
