// Mirrors backend/prisma/migrations into supabase/migrations.
//
//   node scripts/generate-baseline.mjs          write/refresh the mirrored files
//   node scripts/generate-baseline.mjs --check  exit 1 if any mirror is stale
//
// The Supabase database gets *the same schema the backend's own migrations
// build* — same tables, columns, enums, foreign keys, indexes, constraints and
// SQL functions, in the same order — so the backend can later be pointed at
// this database (or a dump of it) and find exactly what it expects.
//
// One Supabase migration per Prisma migration, each named after it. Every
// file also records itself in `public._prisma_migrations` with the checksum
// Prisma computes (sha256 of the original file), so `prisma migrate deploy`
// run against Supabase reports "already applied" instead of re-running DDL.
//
// The only edit to the SQL: explicit BEGIN;/COMMIT; lines, which Prisma's
// generator emits around enum rewrites, are removed, because Supabase applies
// each migration file inside a transaction of its own.
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../../..');
const source = path.join(repo, 'backend', 'prisma', 'migrations');
const target = path.join(repo, 'supabase', 'migrations');
const checkOnly = process.argv.includes('--check');

const names = readdirSync(source, { withFileTypes: true })
  .filter((entry) => entry.isDirectory() && /^\d{14}_/.test(entry.name))
  .map((entry) => entry.name)
  .sort();

mkdirSync(target, { recursive: true });
let stale = 0;

for (const [index, name] of names.entries()) {
  const bytes = readFileSync(path.join(source, name, 'migration.sql'));
  const checksum = createHash('sha256').update(bytes).digest('hex');
  const sql = bytes
    .toString('utf8')
    .replace(/\r\n/g, '\n')
    .split('\n')
    .filter((line) => !/^\s*(BEGIN|COMMIT)\s*;\s*$/i.test(line))
    .join('\n');

  const prelude =
    index === 0
      ? [
          '-- Supabase keeps extensions in their own schema; the backend\'s own',
          '-- `CREATE EXTENSION IF NOT EXISTS pg_trgm` (arabic_search) then finds it present.',
          'CREATE SCHEMA IF NOT EXISTS extensions;',
          'CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;',
          '',
          '-- Prisma\'s migration ledger, exactly as `prisma migrate` creates it.',
          'CREATE TABLE IF NOT EXISTS public._prisma_migrations (',
          '  id                  varchar(36)  PRIMARY KEY NOT NULL,',
          '  checksum            varchar(64)  NOT NULL,',
          '  finished_at         timestamptz,',
          '  migration_name      varchar(255) NOT NULL,',
          '  logs                text,',
          '  rolled_back_at      timestamptz,',
          '  started_at          timestamptz  NOT NULL DEFAULT now(),',
          '  applied_steps_count integer      NOT NULL DEFAULT 0',
          ');',
          '',
        ].join('\n')
      : '';

  const body = [
    `-- GENERATED from backend/prisma/migrations/${name}/migration.sql`,
    '-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the',
    '-- Prisma schema, create a Prisma migration, and regenerate.',
    `-- prisma checksum: ${checksum}`,
    '',
    'SET search_path = public, extensions;',
    '',
    prelude,
    sql.trimEnd(),
    '',
    '',
    '-- Recorded for Prisma, so the backend sees this migration as applied.',
    'INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)',
    `SELECT gen_random_uuid()::text, '${checksum}', now(), '${name}', 1`,
    `WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '${name}');`,
    '',
    '-- Tables this migration created are not exposed to the Data API until a',
    '-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).',
    'DO $$ BEGIN',
    "  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN",
    '    PERFORM reem_supabase.lock_down_public();',
    '  END IF;',
    'END $$;',
    '',
  ].join('\n');

  const file = path.join(target, `${name}.sql`);
  const current = existsSync(file) ? readFileSync(file, 'utf8') : null;
  if (current === body) continue;
  stale += 1;
  if (!checkOnly) writeFileSync(file, body);
}

if (checkOnly && stale > 0) {
  console.error(`${stale} mirrored migration(s) are missing or stale — run npm run baseline`);
  process.exit(1);
}
console.log(`${names.length} Prisma migrations mirrored into supabase/migrations (${stale} written)`);
