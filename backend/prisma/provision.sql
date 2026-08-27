-- ============================================================================
-- One-time provisioning for the Reem development database.
--
-- Run this ONCE as the `postgres` superuser, on the native PostgreSQL 18
-- service. Everything after this point (migrations, seeding) is handled by
-- `npm run db:setup` and needs no superuser rights.
--
-- In DBeaver:  connect as `postgres` → open SQL Editor → paste → Alt+X
-- In a shell:  psql -U postgres -f prisma/provision.sql
-- ============================================================================

-- The application role. Given CREATEDB so `prisma migrate dev` can create its
-- shadow database — without it the CLI fails with P3014 and every schema change
-- has to go through the `migrate diff --script` + `migrate deploy` workaround.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'reem_user') THEN
    CREATE ROLE reem_user WITH LOGIN PASSWORD '12345678' CREATEDB;
  ELSE
    ALTER ROLE reem_user WITH LOGIN PASSWORD '12345678' CREATEDB;
  END IF;
END
$$;

-- The database, owned by the application role.
--
-- ICU collation `ar-SY`: the catalog is Arabic-first, and without this
-- `ORDER BY title` sorts Arabic by raw byte value — أحذية, إكسسوارات and ملابس
-- come back in an order no Arabic reader would call alphabetical. The Windows
-- installer defaults the cluster to a `1256` locale, so the database has to
-- override it explicitly, which requires TEMPLATE template0.
--
-- `CREATE DATABASE` cannot run inside a transaction or a DO block, so this is
-- guarded by \gexec rather than an IF.
--
-- If this line fails with "ICU is not supported in this build", drop the
-- LOCALE_PROVIDER / ICU_LOCALE clauses and keep the rest:
--   CREATE DATABASE reem_db OWNER reem_user TEMPLATE template0 ENCODING 'UTF8'
--     LC_COLLATE 'C' LC_CTYPE 'C';
-- Arabic will then sort by code point instead of alphabetically — workable, but
-- category and product lists will look unordered to an Arabic reader.
SELECT format(
  'CREATE DATABASE reem_db OWNER reem_user TEMPLATE template0 '
  'ENCODING ''UTF8'' LOCALE_PROVIDER icu ICU_LOCALE ''ar-SY'' '
  'LC_COLLATE ''C'' LC_CTYPE ''C'''
)
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'reem_db')
\gexec

-- Prisma creates its tables in `public`. On PostgreSQL 15+ `public` is owned by
-- the bootstrap superuser and no longer world-writable, so the application role
-- needs an explicit grant or every migration fails with
-- "permission denied for schema public".
\connect reem_db

ALTER SCHEMA public OWNER TO reem_user;
GRANT USAGE, CREATE ON SCHEMA public TO reem_user;
GRANT ALL PRIVILEGES ON DATABASE reem_db TO reem_user;

-- Report what was provisioned.
SELECT
  d.datname                          AS database,
  pg_get_userbyid(d.datdba)          AS owner,
  pg_encoding_to_char(d.encoding)    AS encoding,
  d.datlocprovider                   AS locale_provider,
  d.datlocale                        AS icu_locale
FROM pg_database d
WHERE d.datname = 'reem_db';
