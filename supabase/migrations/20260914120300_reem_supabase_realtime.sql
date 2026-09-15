-- ─────────────────────────────────────────────────────────────────────────────
-- Reem on Supabase · 4/5 · Realtime
--
-- Realtime is used for chat and nothing else. Every channel is private
-- (Realtime Authorization), so joining one runs these policies first.
--
--   reem:user:<reem user id>   Server → one woman: new messages, read receipts,
--                              presence of the people she talks to. Published
--                              by the api function with the project secret.
--                              Only she may join; nobody may publish.
--
--   reem:chat:<chat id>        Between the members of one conversation, while
--                              it is open: typing indicators, and presence.
--                              Members may join and publish; no one else.
--
-- No table is added to the `supabase_realtime` publication: nothing streams
-- row changes, so Realtime costs one broadcast per message and nothing per
-- write to the hundreds of tables that do not need it.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION reem_supabase.can_use_topic(p_topic text, p_publish boolean)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := reem_supabase.current_user_id();
  v_id uuid;
BEGIN
  IF v_me IS NULL OR p_topic IS NULL THEN
    RETURN false;
  END IF;

  IF p_topic ~ '^reem:user:[0-9a-f-]{36}$' THEN
    v_id := substring(p_topic FROM 11)::uuid;
    RETURN NOT p_publish AND v_id = v_me;
  END IF;

  IF p_topic ~ '^reem:chat:[0-9a-f-]{36}$' THEN
    v_id := substring(p_topic FROM 11)::uuid;
    RETURN reem_supabase.is_chat_member(v_id);
  END IF;

  RETURN false;
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN false;
END
$$;
REVOKE ALL ON FUNCTION reem_supabase.can_use_topic(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION reem_supabase.can_use_topic(text, boolean) TO authenticated, service_role;

DROP POLICY IF EXISTS reem_realtime_receive ON realtime.messages;
CREATE POLICY reem_realtime_receive ON realtime.messages
  FOR SELECT TO authenticated
  USING (
    realtime.messages.extension IN ('broadcast', 'presence')
    AND reem_supabase.can_use_topic((SELECT realtime.topic()), false)
  );

DROP POLICY IF EXISTS reem_realtime_publish ON realtime.messages;
CREATE POLICY reem_realtime_publish ON realtime.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    realtime.messages.extension IN ('broadcast', 'presence')
    AND reem_supabase.can_use_topic((SELECT realtime.topic()), true)
  );
