-- ─────────────────────────────────────────────────────────────────────────────
-- Reem on Supabase · 2/5 · Row Level Security
--
-- The shape of access on this project:
--
--   The api Edge Function   connects as the database owner through the pooler
--                           and enforces the backend's own authorisation — its
--                           guards, role policies and ownership checks — on
--                           every one of its ~670 routes, exactly as on a
--                           server. It is not subject to RLS, by design.
--
--   The Supabase Data API   (PostgREST, reachable with the publishable key the
--                           app carries) is subject to RLS. Here it is deny by
--                           default: RLS on every table, no privileges on any,
--                           and a small read-only surface opened back up with
--                           explicit role policies — the public catalogue, and
--                           each woman's own orders, chats and notifications.
--                           Nothing is writable through it at all: every write
--                           goes through the API, where the business rules are.
--
-- Tables the backend adds later are locked down by the same function: the
-- mirrored Prisma migrations call `reem_supabase.lock_down_public()` when it
-- exists.
-- ─────────────────────────────────────────────────────────────────────────────

-- New tables created by the migration role must not inherit Supabase's
-- default "anon/authenticated may do anything" grants.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES    FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated, PUBLIC;

-- ── The client read surface ──────────────────────────────────────────────────
-- Kept in one function so `lock_down_public()` can re-apply it after revoking.
CREATE OR REPLACE FUNCTION reem_supabase.apply_client_grants()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Catalogue: public reading, for guests and signed-in users alike.
  GRANT SELECT ON public.categories, public.brands, public.products,
                  public.product_media, public.product_variants, public.seller_offers
     TO anon, authenticated;

  -- Her own records.
  GRANT SELECT ON public.orders, public.seller_orders, public.order_items,
                  public.notifications, public.chats, public.chat_participants,
                  public.messages, public.message_attachments, public.follows
     TO authenticated;
END
$$;

CREATE OR REPLACE FUNCTION reem_supabase.lock_down_public()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  t record;
BEGIN
  FOR t IN
    SELECT c.relname
      FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relkind IN ('r', 'p')
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t.relname);
  END LOOP;

  REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon, authenticated;
  REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
  REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated, PUBLIC;
  GRANT  ALL ON ALL TABLES    IN SCHEMA public TO service_role;
  GRANT  ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
  GRANT  EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

  PERFORM reem_supabase.apply_client_grants();
END
$$;
REVOKE ALL ON FUNCTION reem_supabase.lock_down_public()   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION reem_supabase.apply_client_grants() FROM PUBLIC, anon, authenticated;

SELECT reem_supabase.lock_down_public();

-- ── Policies ─────────────────────────────────────────────────────────────────
-- Helpers are wrapped in (SELECT …) so Postgres evaluates them once per
-- statement, not once per row. `anon` policies never call the helpers — anon
-- has no session to resolve and no EXECUTE on them.

-- Catalogue ----------------------------------------------------------------------

CREATE POLICY categories_public_read ON public.categories
  FOR SELECT TO anon, authenticated
  USING (is_active);

CREATE POLICY brands_public_read ON public.brands
  FOR SELECT TO anon, authenticated
  USING (is_active);

CREATE POLICY products_public_read ON public.products
  FOR SELECT TO anon, authenticated
  -- The backend's PUBLIC_PRODUCT_WHERE (common/catalog/product-include.ts).
  USING (status = 'ACTIVE');

CREATE POLICY products_seller_read_own ON public.products
  FOR SELECT TO authenticated
  USING (
    created_by_seller_id = (SELECT reem_supabase.current_user_id())
    OR EXISTS (
      SELECT 1 FROM public.seller_offers o
       WHERE o.product_id = products.id
         AND o.seller_id = (SELECT reem_supabase.current_user_id())
    )
  );

CREATE POLICY products_staff_read ON public.products
  FOR SELECT TO authenticated
  USING ((SELECT reem_supabase.is_staff()));

-- Media and variants follow their product: the sub-select is itself filtered by
-- the products policies above.
CREATE POLICY product_media_follow_product ON public.product_media
  FOR SELECT TO anon, authenticated
  USING (EXISTS (SELECT 1 FROM public.products p WHERE p.id = product_media.product_id));

CREATE POLICY product_variants_follow_product ON public.product_variants
  FOR SELECT TO anon, authenticated
  USING (EXISTS (SELECT 1 FROM public.products p WHERE p.id = product_variants.product_id));

CREATE POLICY seller_offers_public_read ON public.seller_offers
  FOR SELECT TO anon, authenticated
  USING (is_active AND status IN ('ACTIVE', 'OUT_OF_STOCK'));

CREATE POLICY seller_offers_seller_read_own ON public.seller_offers
  FOR SELECT TO authenticated
  USING (seller_id = (SELECT reem_supabase.current_user_id()));

CREATE POLICY seller_offers_staff_read ON public.seller_offers
  FOR SELECT TO authenticated
  USING ((SELECT reem_supabase.is_staff()));

-- Orders -------------------------------------------------------------------------

CREATE POLICY orders_customer_read_own ON public.orders
  FOR SELECT TO authenticated
  USING (user_id = (SELECT reem_supabase.current_user_id()));

CREATE POLICY orders_staff_read ON public.orders
  FOR SELECT TO authenticated
  USING ((SELECT reem_supabase.is_staff()));

-- A seller sees her own sub-orders; the customer sees the sub-orders of her
-- orders; staff see all.
CREATE POLICY seller_orders_seller_read_own ON public.seller_orders
  FOR SELECT TO authenticated
  USING (seller_id = (SELECT reem_supabase.current_user_id()));

CREATE POLICY seller_orders_customer_read_own ON public.seller_orders
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.orders o
     WHERE o.id = seller_orders.order_id
       AND o.user_id = (SELECT reem_supabase.current_user_id())
  ));

CREATE POLICY seller_orders_staff_read ON public.seller_orders
  FOR SELECT TO authenticated
  USING ((SELECT reem_supabase.is_staff()));

-- Lines follow their sub-order (itself filtered by the policies above).
CREATE POLICY order_items_follow_seller_order ON public.order_items
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.seller_orders so WHERE so.id = order_items.seller_order_id));

-- Notifications: her own, and only her own — not even staff read them here.
CREATE POLICY notifications_read_own ON public.notifications
  FOR SELECT TO authenticated
  USING (user_id = (SELECT reem_supabase.current_user_id()));

-- Chats --------------------------------------------------------------------------

CREATE POLICY chats_member_read ON public.chats
  FOR SELECT TO authenticated
  USING ((SELECT reem_supabase.is_chat_member(chats.id)));

CREATE POLICY chat_participants_member_read ON public.chat_participants
  FOR SELECT TO authenticated
  USING ((SELECT reem_supabase.is_chat_member(chat_participants.chat_id)));

CREATE POLICY messages_member_read ON public.messages
  FOR SELECT TO authenticated
  USING (deleted_at IS NULL AND (SELECT reem_supabase.is_chat_member(messages.chat_id)));

CREATE POLICY message_attachments_follow_message ON public.message_attachments
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.messages m WHERE m.id = message_attachments.message_id));

-- Follows: the edges she is on.
CREATE POLICY follows_read_own_edges ON public.follows
  FOR SELECT TO authenticated
  USING (
    follower_id  = (SELECT reem_supabase.current_user_id())
    OR following_id = (SELECT reem_supabase.current_user_id())
  );
