-- Bring the RBAC tables level with `AppPermission` and `role-permissions.ts`.
--
-- `resolvePermissions` reads `roles` → `role_permissions` → `permissions` and
-- only falls back to the code defaults when a role has **no rows at all**. So a
-- table that is present and stale silently overrides the code, which is exactly
-- what happened here: a customer holds `content:author` and `content:interact`
-- in the source and neither in the database, so every like, comment and reshare
-- answered 403 while the code said otherwise.
--
-- Three permissions that predate this feature were missing too. They were added
-- to the code and never to a seeded database, so `trends:manage`,
-- `security_forensics:read` and `account_recovery:review` had never been
-- grantable to anyone but a SUPER_ADMIN (who bypasses the check entirely, which
-- is why nobody noticed). The seed derives from the code now; this catches the
-- databases that already exist.

INSERT INTO "permissions" ("id", "key", "description", "created_at")
SELECT gen_random_uuid(), key, NULL, now()
FROM (VALUES
  ('content:author'),
  ('content:interact'),
  ('trends:manage'),
  ('security_forensics:read'),
  ('account_recovery:review')
) AS t(key)
ON CONFLICT ("key") DO NOTHING;

-- ── Who gets what ───────────────────────────────────────────────────────────
-- Mirrors `rolePermissions` in `src/common/role-permissions.ts`. Written as a
-- table so the grants read as data rather than as five near-identical INSERTs.
INSERT INTO "role_permissions" ("id", "role_id", "permission_id")
SELECT gen_random_uuid(), r."id", p."id"
FROM (VALUES
  ('CUSTOMER',          'content:author'),
  ('CUSTOMER',          'content:interact'),
  ('SELLER',            'content:author'),
  ('SELLER',            'content:interact'),
  ('OPERATIONS_ADMIN',  'trends:manage'),
  ('SUPPORT_ADMIN',     'security_forensics:read'),
  ('SUPPORT_ADMIN',     'account_recovery:review'),
  ('SUPER_ADMIN',       'content:author'),
  ('SUPER_ADMIN',       'content:interact'),
  ('SUPER_ADMIN',       'trends:manage'),
  ('SUPER_ADMIN',       'security_forensics:read'),
  ('SUPER_ADMIN',       'account_recovery:review')
) AS grant_list(role_name, permission_key)
JOIN "roles" r        ON r."name" = grant_list.role_name
JOIN "permissions" p  ON p."key"  = grant_list.permission_key
WHERE NOT EXISTS (
  SELECT 1 FROM "role_permissions" rp
   WHERE rp."role_id" = r."id" AND rp."permission_id" = p."id"
);
