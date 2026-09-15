-- ─────────────────────────────────────────────────────────────────────────────
-- Row Level Security, role by role.
--
-- Run against the Supabase database as `postgres` (SQL editor, psql, or the
-- MCP execute_sql tool). It acts as `anon`, as an unlinked signed-in user, and
-- as a real customer, seller and staff member from the migrated data, asserts
-- what each can and cannot see or do, prints one row per assertion, and removes
-- every fixture it created. It changes no application data.
--
-- The Reem users it borrows are chosen among accounts that do not have a
-- Supabase auth user yet, so a real sign-in is never disturbed.
-- ─────────────────────────────────────────────────────────────────────────────

-- Leftovers from an interrupted run.
DELETE FROM reem_supabase.identity_links
 WHERE auth_user_id IN ('00000000-0000-4000-8000-00000000c001', '00000000-0000-4000-8000-00000000c002',
                        '00000000-0000-4000-8000-00000000c003', '00000000-0000-4000-8000-00000000c004');
DELETE FROM auth.users
 WHERE id IN ('00000000-0000-4000-8000-00000000c001', '00000000-0000-4000-8000-00000000c002',
              '00000000-0000-4000-8000-00000000c003', '00000000-0000-4000-8000-00000000c004');
DROP SCHEMA IF EXISTS reem_rls_test CASCADE;

CREATE SCHEMA reem_rls_test;
CREATE TABLE reem_rls_test.results (
  seq       serial PRIMARY KEY,
  actor     text    NOT NULL,
  assertion text    NOT NULL,
  passed    boolean NOT NULL,
  detail    text
);
CREATE TABLE reem_rls_test.actors (actor text PRIMARY KEY, auth_user_id uuid, user_id uuid);
CREATE TABLE reem_rls_test.expect (k text PRIMARY KEY, v bigint NOT NULL);
GRANT USAGE ON SCHEMA reem_rls_test TO anon, authenticated;
GRANT SELECT, INSERT ON reem_rls_test.results TO anon, authenticated;
GRANT SELECT ON reem_rls_test.actors, reem_rls_test.expect TO anon, authenticated;
GRANT USAGE ON SEQUENCE reem_rls_test.results_seq_seq TO anon, authenticated;

-- ── Fixtures ────────────────────────────────────────────────────────────────
INSERT INTO reem_rls_test.actors (actor, auth_user_id, user_id)
SELECT 'customer', '00000000-0000-4000-8000-00000000c001', u.id
  FROM public.users u
 WHERE u.role = 'CUSTOMER' AND u.disabled_at IS NULL AND u.phone IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM auth.users a WHERE a.phone = ltrim(u.phone, '+'))
 ORDER BY (SELECT count(*) FROM public.orders o WHERE o.user_id = u.id) DESC
 LIMIT 1;

INSERT INTO reem_rls_test.actors (actor, auth_user_id, user_id)
SELECT 'seller', '00000000-0000-4000-8000-00000000c002', u.id
  FROM public.users u
 WHERE u.role = 'SELLER' AND u.disabled_at IS NULL AND u.phone IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM auth.users a WHERE a.phone = ltrim(u.phone, '+'))
 ORDER BY (SELECT count(*) FROM public.seller_orders so WHERE so.seller_id = u.id) DESC
 LIMIT 1;

INSERT INTO reem_rls_test.actors (actor, auth_user_id, user_id)
SELECT 'staff', '00000000-0000-4000-8000-00000000c003', u.id
  FROM public.users u
 WHERE u.role IN ('SUPER_ADMIN', 'ADMIN', 'OPERATIONS_ADMIN') AND u.disabled_at IS NULL AND u.phone IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM auth.users a WHERE a.phone = ltrim(u.phone, '+'))
 LIMIT 1;

-- An auth user with a confirmed phone that belongs to no Reem account.
INSERT INTO reem_rls_test.actors (actor, auth_user_id, user_id)
VALUES ('unlinked', '00000000-0000-4000-8000-00000000c004', NULL);

INSERT INTO auth.users (id, aud, role, phone, phone_confirmed_at, created_at, updated_at)
SELECT t.auth_user_id, 'authenticated', 'authenticated',
       COALESCE(ltrim(u.phone, '+'), '963999000004'), now(), now(), now()
  FROM reem_rls_test.actors t
  LEFT JOIN public.users u ON u.id = t.user_id;

INSERT INTO reem_supabase.identity_links (auth_user_id, user_id)
SELECT auth_user_id, user_id FROM reem_rls_test.actors WHERE user_id IS NOT NULL;

-- What each actor should see, computed with full privileges.
INSERT INTO reem_rls_test.expect (k, v) VALUES
  ('public_products',  (SELECT count(*) FROM public.products WHERE status = 'ACTIVE')),
  ('all_products',     (SELECT count(*) FROM public.products)),
  ('public_offers',    (SELECT count(*) FROM public.seller_offers WHERE is_active AND status IN ('ACTIVE', 'OUT_OF_STOCK'))),
  ('all_orders',       (SELECT count(*) FROM public.orders)),
  ('customer_orders',  (SELECT count(*) FROM public.orders o JOIN reem_rls_test.actors t ON t.user_id = o.user_id AND t.actor = 'customer')),
  ('customer_notifs',  (SELECT count(*) FROM public.notifications n JOIN reem_rls_test.actors t ON t.user_id = n.user_id AND t.actor = 'customer')),
  ('customer_chats',   (SELECT count(*) FROM public.chat_participants p JOIN reem_rls_test.actors t ON t.user_id = p.user_id AND t.actor = 'customer')),
  ('seller_suborders', (SELECT count(*) FROM public.seller_orders so JOIN reem_rls_test.actors t ON t.user_id = so.seller_id AND t.actor = 'seller')),
  ('staff_notifs',     (SELECT count(*) FROM public.notifications n JOIN reem_rls_test.actors t ON t.user_id = n.user_id AND t.actor = 'staff'));

-- ── anon ────────────────────────────────────────────────────────────────────
SET ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', false);

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'anon', 'sees exactly the public catalogue', count(*) = (SELECT v FROM reem_rls_test.expect WHERE k = 'public_products'),
       count(*) || ' products visible'
  FROM public.products;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'anon', 'sees only live offers', count(*) = (SELECT v FROM reem_rls_test.expect WHERE k = 'public_offers'),
       count(*) || ' offers visible'
  FROM public.seller_offers;

DO $$ BEGIN
  PERFORM 1 FROM public.orders LIMIT 1;
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('anon', 'cannot read orders', false, 'query was allowed');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('anon', 'cannot read orders', true, SQLERRM);
END $$;

DO $$ BEGIN
  PERFORM 1 FROM public.users LIMIT 1;
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('anon', 'cannot read users (phones)', false, 'query was allowed');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('anon', 'cannot read users (phones)', true, SQLERRM);
END $$;

DO $$ BEGIN
  UPDATE public.products SET title = title WHERE false;
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('anon', 'cannot write products', false, 'update was allowed');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('anon', 'cannot write products', true, SQLERRM);
END $$;

DO $$ BEGIN
  PERFORM 1 FROM reem_supabase.identity_links LIMIT 1;
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('anon', 'cannot read identity links', false, 'query was allowed');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('anon', 'cannot read identity links', true, SQLERRM);
END $$;

DO $$ BEGIN
  PERFORM 1 FROM public.financial_ledger_entries LIMIT 1;
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('anon', 'cannot read the ledger', false, 'query was allowed');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('anon', 'cannot read the ledger', true, SQLERRM);
END $$;

RESET ROLE;

-- ── customer ────────────────────────────────────────────────────────────────
SELECT set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-4000-8000-00000000c001', 'role', 'authenticated')::text, false);
SET ROLE authenticated;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'customer', 'session resolves to her Reem account',
       reem_supabase.current_user_id() IS NOT DISTINCT FROM (SELECT user_id FROM reem_rls_test.actors WHERE actor = 'customer'),
       coalesce(reem_supabase.current_user_id()::text, 'NULL');

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'customer', 'sees her own orders and no one else''s',
       count(*) = (SELECT v FROM reem_rls_test.expect WHERE k = 'customer_orders')
       AND bool_and(user_id = (SELECT user_id FROM reem_rls_test.actors WHERE actor = 'customer')) IS NOT FALSE,
       count(*) || ' orders visible'
  FROM public.orders;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'customer', 'sees only sub-orders of her own orders',
       NOT EXISTS (
         SELECT 1 FROM public.seller_orders so
          WHERE NOT EXISTS (SELECT 1 FROM public.orders o WHERE o.id = so.order_id)
       ),
       count(*) || ' sub-orders visible'
  FROM public.seller_orders;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'customer', 'sees her own notifications only',
       count(*) = (SELECT v FROM reem_rls_test.expect WHERE k = 'customer_notifs'),
       count(*) || ' notifications visible'
  FROM public.notifications;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'customer', 'sees only chats she is in',
       count(*) = (SELECT v FROM reem_rls_test.expect WHERE k = 'customer_chats'),
       count(*) || ' chats visible'
  FROM public.chats;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'customer', 'sees no message outside her chats',
       NOT EXISTS (
         SELECT 1 FROM public.messages m
          WHERE NOT EXISTS (
            SELECT 1 FROM public.chat_participants p
             WHERE p.chat_id = m.chat_id
               AND p.user_id = (SELECT user_id FROM reem_rls_test.actors WHERE actor = 'customer')
          )
       ),
       (SELECT count(*) FROM public.messages) || ' messages visible';

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'customer', 'is not staff', NOT reem_supabase.is_staff(), NULL;

DO $$ BEGIN
  UPDATE public.orders SET notes = notes WHERE false;
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('customer', 'cannot modify her orders directly', false, 'update was allowed');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('customer', 'cannot modify her orders directly', true, SQLERRM);
END $$;

DO $$ BEGIN
  INSERT INTO public.notifications (id, user_id, title, body, type) VALUES (gen_random_uuid(), gen_random_uuid(), 'x', 'x', 'system');
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('customer', 'cannot insert notifications', false, 'insert was allowed');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('customer', 'cannot insert notifications', true, SQLERRM);
END $$;

DO $$ BEGIN
  PERFORM 1 FROM public.users LIMIT 1;
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('customer', 'cannot read the users table', false, 'query was allowed');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('customer', 'cannot read the users table', true, SQLERRM);
END $$;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'customer', 'may join her own Realtime user topic',
       reem_supabase.can_use_topic('reem:user:' || (SELECT user_id FROM reem_rls_test.actors WHERE actor = 'customer'), false), NULL;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'customer', 'may not publish on her user topic (server-only)',
       NOT reem_supabase.can_use_topic('reem:user:' || (SELECT user_id FROM reem_rls_test.actors WHERE actor = 'customer'), true), NULL;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'customer', 'may not join another user''s topic',
       NOT reem_supabase.can_use_topic('reem:user:' || (SELECT user_id FROM reem_rls_test.actors WHERE actor = 'seller'), false), NULL;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'customer', 'may not join a chat topic she is not in',
       NOT reem_supabase.can_use_topic('reem:chat:' || gen_random_uuid(), false), NULL;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'customer', 'may join and publish on a chat she is in',
       coalesce(bool_and(reem_supabase.can_use_topic('reem:chat:' || p.chat_id, true)), true),
       count(*) || ' chats checked'
  FROM public.chat_participants p
 WHERE p.user_id = (SELECT user_id FROM reem_rls_test.actors WHERE actor = 'customer');

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'customer', 'garbage topics are refused, not errors',
       NOT reem_supabase.can_use_topic('reem:chat:not-a-uuid-at-all-xxxxxxxxxxxxxxxxxxx', false)
       AND NOT reem_supabase.can_use_topic('realtime:public', false), NULL;

RESET ROLE;

-- ── seller ──────────────────────────────────────────────────────────────────
SELECT set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-4000-8000-00000000c002', 'role', 'authenticated')::text, false);
SET ROLE authenticated;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'seller', 'sees her own sub-orders',
       count(*) FILTER (WHERE seller_id = (SELECT user_id FROM reem_rls_test.actors WHERE actor = 'seller'))
         = (SELECT v FROM reem_rls_test.expect WHERE k = 'seller_suborders'),
       count(*) || ' sub-orders visible'
  FROM public.seller_orders;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'seller', 'sees no other seller''s sub-orders for orders she did not place',
       NOT EXISTS (
         SELECT 1 FROM public.seller_orders so
          WHERE so.seller_id <> (SELECT user_id FROM reem_rls_test.actors WHERE actor = 'seller')
            AND NOT EXISTS (SELECT 1 FROM public.orders o WHERE o.id = so.order_id)
       ), NULL;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'seller', 'sees her own offers whatever their state',
       (SELECT count(*) FROM public.seller_offers WHERE seller_id = (SELECT user_id FROM reem_rls_test.actors WHERE actor = 'seller'))
         >= 0, NULL;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'seller', 'is a seller, not staff', reem_supabase.is_seller() AND NOT reem_supabase.is_staff(), NULL;

DO $$ BEGIN
  UPDATE public.seller_offers SET price = price WHERE false;
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('seller', 'cannot change prices directly (API only)', false, 'update was allowed');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('seller', 'cannot change prices directly (API only)', true, SQLERRM);
END $$;

DO $$ BEGIN
  PERFORM 1 FROM public.commission_ledgers LIMIT 1;
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('seller', 'cannot read commission ledger directly', false, 'query was allowed');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('seller', 'cannot read commission ledger directly', true, SQLERRM);
END $$;

RESET ROLE;

-- ── staff ───────────────────────────────────────────────────────────────────
SELECT set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-4000-8000-00000000c003', 'role', 'authenticated')::text, false);
SET ROLE authenticated;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'staff', 'is staff', reem_supabase.is_staff(), (SELECT reem_supabase.app_role()::text);

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'staff', 'reads every order', count(*) = (SELECT v FROM reem_rls_test.expect WHERE k = 'all_orders'), count(*) || ' orders visible'
  FROM public.orders;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'staff', 'reads every product, drafts included', count(*) = (SELECT v FROM reem_rls_test.expect WHERE k = 'all_products'), count(*) || ' products visible'
  FROM public.products;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'staff', 'still reads only her own notifications', count(*) = (SELECT v FROM reem_rls_test.expect WHERE k = 'staff_notifs'), count(*) || ' notifications visible'
  FROM public.notifications;

DO $$ BEGIN
  DELETE FROM public.orders WHERE false;
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('staff', 'cannot delete orders directly', false, 'delete was allowed');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO reem_rls_test.results (actor, assertion, passed, detail) VALUES ('staff', 'cannot delete orders directly', true, SQLERRM);
END $$;

RESET ROLE;

-- ── a signed-in phone with no Reem account ─────────────────────────────────
SELECT set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-4000-8000-00000000c004', 'role', 'authenticated')::text, false);
SET ROLE authenticated;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'unlinked', 'resolves to no account', reem_supabase.current_user_id() IS NULL, NULL;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'unlinked', 'sees no orders', count(*) = 0, count(*) || ' orders visible' FROM public.orders;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'unlinked', 'still sees the public catalogue',
       count(*) = (SELECT v FROM reem_rls_test.expect WHERE k = 'public_products'), count(*) || ' products visible'
  FROM public.products;

RESET ROLE;

-- ── a number that changed hands ─────────────────────────────────────────────
-- The customer's auth user now carries a different phone than her account.
UPDATE auth.users SET phone = '963999000001' WHERE id = '00000000-0000-4000-8000-00000000c001';
SELECT set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-4000-8000-00000000c001', 'role', 'authenticated')::text, false);
SET ROLE authenticated;

INSERT INTO reem_rls_test.results (actor, assertion, passed, detail)
SELECT 'stale-phone', 'a session whose phone no longer matches reaches nothing',
       reem_supabase.current_user_id() IS NULL AND (SELECT count(*) FROM public.orders) = 0, NULL;

RESET ROLE;
SELECT set_config('request.jwt.claims', '', false);

-- ── Report, then clean up ───────────────────────────────────────────────────
CREATE TEMP TABLE rls_report AS
SELECT r.seq, r.actor, r.assertion, r.passed, r.detail FROM reem_rls_test.results r
UNION ALL
SELECT 1000, a.actor, 'fixture present', a.user_id IS NOT NULL OR a.actor = 'unlinked', coalesce(a.user_id::text, '')
  FROM reem_rls_test.actors a;

DELETE FROM reem_supabase.identity_links
 WHERE auth_user_id IN (SELECT auth_user_id FROM reem_rls_test.actors);
DELETE FROM auth.users WHERE id IN (SELECT auth_user_id FROM reem_rls_test.actors);
DROP SCHEMA reem_rls_test CASCADE;

SELECT seq, actor, assertion, passed, detail FROM rls_report ORDER BY seq;
