#!/usr/bin/env node
/**
 * Prisma migrations, applied through Supabase's transaction pooler.
 *
 *   npm run db:pooled:status          list pending migrations (read-only; the default)
 *   npm run db:pooled:deploy          apply them
 *
 * Why this exists. The API reaches its Supabase database through the
 * transaction pooler (port 6543): the direct host is IPv6-only and the session
 * pooler refuses this network. `prisma migrate deploy` needs a session — its
 * schema engine takes an advisory lock and prepares statements — and over the
 * transaction pooler it hangs rather than failing. So this does what
 * `migrate deploy` does, in the one shape the pooler supports:
 *
 *  - pending = every directory in prisma/migrations with no finished row in
 *    `_prisma_migrations`, in name order, exactly Prisma's rule;
 *  - each one runs in its own transaction — its SQL, then the ledger row with
 *    the checksum Prisma computes (sha256 of the file), so `prisma migrate
 *    status` from anywhere with a session agrees afterwards;
 *  - a migration that fails rolls back whole, and nothing after it runs;
 *  - a row Prisma left unfinished, or an applied migration whose file changed,
 *    stops everything before any DDL — those need a person, not a retry.
 *
 * On Supabase it also keeps the two things the project's own migrations
 * maintain: new tables are locked away from the Data API
 * (`reem_supabase.lock_down_public()`), and the Supabase CLI's ledger gains
 * the same version, so `supabase db push` never re-runs it.
 *
 * It never drops, resets or rewrites anything it did not just create.
 */
// `.env` on a developer machine; the platform's environment in a container,
// where dotenv (a dev dependency) is not installed.
try {
  await import('dotenv/config');
} catch {
  // No dotenv: the environment is already set.
}
import { createHash } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const here = path.dirname(fileURLToPath(import.meta.url));
const prismaDir = path.resolve(here, '..', 'prisma');
const migrationsDir = path.join(prismaDir, 'migrations');
const apply = process.argv.includes('--apply');

function clientConfig(databaseUrl) {
  if (!databaseUrl) throw new Error('DATABASE_URL is not set.');
  const url = new URL(databaseUrl);
  const params = url.searchParams;
  const config = {
    host: url.hostname,
    port: Number(url.port || 5432),
    user: decodeURIComponent(url.username),
    password: decodeURIComponent(url.password),
    database: decodeURIComponent(url.pathname.slice(1)) || 'postgres',
    application_name: 'reem-migrate-pooled',
  };
  const sslmode = params.get('sslmode');
  if (sslmode && sslmode !== 'disable') {
    const cert = params.get('sslcert');
    config.ssl = {
      // Prisma resolves `sslcert` against the schema directory; so does this.
      ca: cert ? readFileSync(path.resolve(prismaDir, cert), 'utf8') : undefined,
      rejectUnauthorized: params.get('sslaccept') !== 'accept_invalid_certs',
      servername: url.hostname,
    };
  }
  return config;
}

function localMigrations() {
  return readdirSync(migrationsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && /^\d{14}_/.test(entry.name))
    .map((entry) => entry.name)
    .sort()
    .map((name) => {
      const file = path.join(migrationsDir, name, 'migration.sql');
      const bytes = readFileSync(file);
      return {
        name,
        checksum: createHash('sha256').update(bytes).digest('hex'),
        // Prisma's generator wraps enum rewrites in BEGIN;/COMMIT;. The whole
        // migration already runs inside one transaction here, and a COMMIT in
        // the middle would end it early.
        sql: bytes
          .toString('utf8')
          .replace(/\r\n/g, '\n')
          .split('\n')
          .filter((line) => !/^\s*(BEGIN|COMMIT)\s*;\s*$/i.test(line))
          .join('\n'),
      };
    });
}

async function exists(client, sql) {
  const { rows } = await client.query(sql);
  return Boolean(rows[0]?.present);
}

async function main() {
  const client = new pg.Client(clientConfig(process.env.DATABASE_URL));
  await client.connect();
  try {
    const { rows: applied } = await client.query(
      'SELECT migration_name, checksum, finished_at, rolled_back_at FROM public._prisma_migrations',
    );
    const byName = new Map(applied.map((row) => [row.migration_name, row]));
    const local = localMigrations();

    const unfinished = applied.filter((row) => !row.finished_at && !row.rolled_back_at);
    if (unfinished.length > 0) {
      throw new Error(
        `Prisma recorded unfinished migrations: ${unfinished.map((r) => r.migration_name).join(', ')}. ` +
          'Inspect the database and resolve them before applying anything.',
      );
    }
    const drifted = local.filter((m) => {
      const row = byName.get(m.name);
      return row?.finished_at && row.checksum !== m.checksum;
    });
    if (drifted.length > 0) {
      throw new Error(
        `Applied migrations were edited after they ran: ${drifted.map((m) => m.name).join(', ')}. ` +
          'Restore the original files; create a new migration for the change.',
      );
    }

    const pending = local.filter((m) => !byName.get(m.name)?.finished_at);
    console.log(`${local.length} local migrations, ${pending.length} pending.`);
    for (const m of pending) console.log(`  • ${m.name}`);
    if (pending.length === 0 || !apply) {
      if (pending.length > 0) console.log('Run with --apply to apply them.');
      return;
    }

    const supabaseLockDown = await exists(
      client,
      "SELECT to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL AS present",
    );
    const supabaseLedger = await exists(
      client,
      "SELECT to_regclass('supabase_migrations.schema_migrations') IS NOT NULL AS present",
    );

    for (const m of pending) {
      process.stdout.write(`Applying ${m.name} … `);
      await client.query('BEGIN');
      try {
        // Supabase keeps extensions (pg_trgm) in their own schema.
        await client.query('SET LOCAL search_path = public, extensions');
        await client.query(m.sql);
        await client.query(
          `INSERT INTO public._prisma_migrations (id, checksum, started_at, finished_at, migration_name, applied_steps_count)
           VALUES (gen_random_uuid()::text, $1, now(), now(), $2, 1)`,
          [m.checksum, m.name],
        );
        if (supabaseLockDown) await client.query('SELECT reem_supabase.lock_down_public()');
        if (supabaseLedger) {
          const [version, ...rest] = m.name.split('_');
          await client.query(
            `INSERT INTO supabase_migrations.schema_migrations (version, name, statements)
             SELECT $1, $2, ARRAY[]::text[]
             WHERE NOT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version = $1)`,
            [version, rest.join('_')],
          );
        }
        await client.query('COMMIT');
        console.log('done');
      } catch (error) {
        await client.query('ROLLBACK').catch(() => {});
        console.log('rolled back');
        throw error;
      }
    }
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
