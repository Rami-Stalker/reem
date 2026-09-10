#!/usr/bin/env node
/**
 * A backup of the whole database, and a note of what it contained.
 *
 * This platform keeps a double-entry ledger, escrow balances and cash orders,
 * so the database *is* the business: an hour of it lost is an hour of money
 * nobody can account for. There was no backup procedure at all before this —
 * not a bad one, none — which is the single most consequential gap the
 * pre-launch audit found, and the one no amount of application code fixes.
 *
 * What this is:
 *
 *   node scripts/backup.mjs [--out <dir>] [--keep <n>]
 *
 * It writes `reem-<timestamp>.dump` in PostgreSQL's custom format, which is
 * compressed and — the reason for choosing it over plain SQL — restorable
 * table by table, so recovering one clobbered table does not mean replaying
 * everything. Beside it goes a `.json` manifest recording the server version,
 * the migration the schema was at, and row counts for the tables that carry
 * money. The manifest is what makes a restore *verifiable*: without it, "the
 * restore worked" is an opinion.
 *
 * What this is NOT, and must not be mistaken for:
 *
 *   - **Off-host storage.** A dump on the same disk as the database survives a
 *     dropped table and nothing else. Copy it somewhere else; that step is
 *     deployment's, not this script's, and it is not optional.
 *   - **Point-in-time recovery.** A nightly dump means up to a day of orders
 *     can be lost. Real PITR is `archive_mode = on` plus WAL shipping, which
 *     is a server configuration and a second machine — recorded in
 *     `docs/DEPLOYMENT.md` as the decision it is, because it costs money and
 *     is the client's call.
 *   - **Tested.** A backup nobody has restored is a hypothesis. Run
 *     `scripts/restore.mjs --verify` against a scratch database on a schedule.
 */
import { execFile } from 'node:child_process';
import { mkdir, readdir, stat, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { promisify } from 'node:util';
import { toLibpq } from './pg-url.mjs';

const run = promisify(execFile);

/** Tables whose row count is worth recording, because they are the money. */
const WITNESS_TABLES = [
  'orders',
  'seller_orders',
  'order_items',
  'payments',
  'journal_entries',
  'journal_lines',
  'ledger_accounts',
  'wallets',
  'wallet_transactions',
  'commission_ledgers',
  'seller_payouts',
  'return_requests',
  'users',
  'products',
  'seller_offers',
];

function arg(name, fallback) {
  const at = process.argv.indexOf(`--${name}`);
  return at === -1 ? fallback : process.argv[at + 1];
}

function requireDatabaseUrl() {
  const raw = process.env.DATABASE_URL;
  if (!raw) {
    console.error(
      'DATABASE_URL is not set. This script talks to the same database the API does.',
    );
    process.exit(1);
  }
  // Prisma's URL is not libpq's — see `pg-url.mjs`.
  const { url, env } = toLibpq(raw);
  Object.assign(process.env, env);
  return url;
}

/** Row counts, exactly — an estimate is no use for verifying a restore. */
async function witness(url) {
  const selects = WITNESS_TABLES.map(
    (table) =>
      `SELECT '${table}' AS t, (SELECT count(*) FROM information_schema.tables ` +
      `WHERE table_schema='public' AND table_name='${table}') AS present, ` +
      `CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables ` +
      `WHERE table_schema='public' AND table_name='${table}') ` +
      `THEN (SELECT count(*) FROM public."${table}") ELSE NULL END AS n`,
  ).join(' UNION ALL ');

  const { stdout } = await run(
    'psql',
    ['--no-psqlrc', '--tuples-only', '--no-align', '--field-separator=|', '-c', selects, url],
    { maxBuffer: 1024 * 1024 },
  );

  const counts = {};
  for (const line of stdout.trim().split('\n')) {
    const [table, , n] = line.split('|');
    if (table) counts[table.trim()] = n?.trim() ? Number(n) : null;
  }
  return counts;
}

async function migrationState(url) {
  try {
    const { stdout } = await run(
      'psql',
      [
        '--no-psqlrc',
        '--tuples-only',
        '--no-align',
        '-c',
        'SELECT migration_name FROM public._prisma_migrations ' +
          'WHERE finished_at IS NOT NULL ORDER BY finished_at DESC LIMIT 1',
        url,
      ],
    );
    return stdout.trim() || null;
  } catch {
    return null;
  }
}

async function serverVersion(url) {
  const { stdout } = await run('psql', [
    '--no-psqlrc',
    '--tuples-only',
    '--no-align',
    '-c',
    'SHOW server_version',
    url,
  ]);
  return stdout.trim();
}

/**
 * Deletes all but the newest [keep] dumps.
 *
 * Retention is here rather than in cron because the manifest has to go with
 * its dump: a dump whose manifest was swept is unverifiable, and a manifest
 * whose dump was swept is a lie about what exists.
 */
async function prune(dir, keep) {
  if (!Number.isFinite(keep) || keep <= 0) return [];
  const entries = (await readdir(dir)).filter(
    (name) => name.startsWith('reem-') && name.endsWith('.dump'),
  );
  const dated = await Promise.all(
    entries.map(async (name) => ({
      name,
      at: (await stat(path.join(dir, name))).mtimeMs,
    })),
  );
  dated.sort((a, b) => b.at - a.at);

  const removed = [];
  for (const { name } of dated.slice(keep)) {
    await unlink(path.join(dir, name));
    await unlink(path.join(dir, name.replace(/\.dump$/, '.json'))).catch(
      () => undefined,
    );
    removed.push(name);
  }
  return removed;
}

async function main() {
  const url = requireDatabaseUrl();
  const dir = path.resolve(arg('out', 'backups'));
  const keep = Number(arg('keep', '14'));

  await mkdir(dir, { recursive: true });

  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const dumpPath = path.join(dir, `reem-${stamp}.dump`);

  const began = Date.now();
  const counts = await witness(url);
  const manifest = {
    created_at: new Date().toISOString(),
    dump: path.basename(dumpPath),
    format: 'pg_dump custom (-Fc), compression 9',
    server_version: await serverVersion(url),
    migration: await migrationState(url),
    row_counts: counts,
  };

  // `--no-owner` and `--no-privileges`: the restore target is a fresh database
  // whose role names are the deployment's business, and a dump that insists on
  // reproducing them fails on any host but the one it came from.
  await run(
    'pg_dump',
    ['--format=custom', '--compress=9', '--no-owner', '--no-privileges', '--file', dumpPath, url],
    { maxBuffer: 1024 * 1024 * 64 },
  );

  const bytes = (await stat(dumpPath)).size;
  manifest.bytes = bytes;
  manifest.duration_ms = Date.now() - began;
  await writeFile(
    dumpPath.replace(/\.dump$/, '.json'),
    `${JSON.stringify(manifest, null, 2)}\n`,
    'utf8',
  );

  const pruned = await prune(dir, keep);

  console.log(`wrote ${dumpPath}`);
  console.log(`  ${(bytes / 1024 / 1024).toFixed(1)} MB in ${manifest.duration_ms} ms`);
  console.log(`  migration: ${manifest.migration ?? 'unknown'}`);
  console.log(`  orders: ${counts.orders ?? '?'}  journal_lines: ${counts.journal_lines ?? '?'}`);
  if (pruned.length) console.log(`  pruned ${pruned.length} older dump(s)`);
  console.log(
    '\nThis dump is on the same host as the database. Copy it off, or it ' +
      'protects you from a dropped table and nothing else.',
  );
}

main().catch((error) => {
  console.error(`backup failed: ${error.message}`);
  if (error.stderr) console.error(String(error.stderr).trim());
  process.exit(1);
});
