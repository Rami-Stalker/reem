#!/usr/bin/env node
/**
 * Restores a dump, and — the part that matters — checks that it worked.
 *
 * A backup nobody has restored is a hypothesis. The failure mode is not that
 * `pg_restore` errors; it is that it succeeds, and six tables are empty
 * because the dump was taken while a migration was half-applied, or because
 * retention swept the file that had the rows. Nobody discovers that during an
 * incident and lives to tell it calmly.
 *
 * So `--verify` is the mode this script exists for. Point it at a scratch
 * database on a schedule; it restores, compares every row count against the
 * manifest written at backup time, and fails loudly on any difference.
 *
 *   # Verify last night's backup against a throwaway database
 *   node scripts/restore.mjs --verify --into postgres://…/reem_restore_check
 *
 *   # Actually recover, into a database you have already created and emptied
 *   node scripts/restore.mjs --file backups/reem-….dump --into postgres://…/reem_db
 *
 * The target is always explicit. There is no default and it never falls back
 * to `DATABASE_URL`: the one thing this script must be incapable of is
 * overwriting production because somebody forgot a flag.
 */
import { execFile } from 'node:child_process';
import { readFile, readdir, stat } from 'node:fs/promises';
import path from 'node:path';
import { promisify } from 'node:util';
import { toLibpq } from './pg-url.mjs';

const run = promisify(execFile);

function arg(name, fallback) {
  const at = process.argv.indexOf(`--${name}`);
  return at === -1 ? fallback : process.argv[at + 1];
}
const flag = (name) => process.argv.includes(`--${name}`);

/** The newest dump in [dir], with its manifest. */
async function newest(dir) {
  const entries = (await readdir(dir)).filter(
    (name) => name.startsWith('reem-') && name.endsWith('.dump'),
  );
  if (entries.length === 0) {
    throw new Error(`no dumps found in ${dir}`);
  }
  const dated = await Promise.all(
    entries.map(async (name) => ({
      name,
      at: (await stat(path.join(dir, name))).mtimeMs,
    })),
  );
  dated.sort((a, b) => b.at - a.at);
  return path.join(dir, dated[0].name);
}

async function readManifest(dumpPath) {
  try {
    return JSON.parse(
      await readFile(dumpPath.replace(/\.dump$/, '.json'), 'utf8'),
    );
  } catch {
    return null;
  }
}

async function counts(url, tables) {
  const selects = tables
    .map(
      (table) =>
        `SELECT '${table}' AS t, CASE WHEN EXISTS (SELECT 1 FROM ` +
        `information_schema.tables WHERE table_schema='public' AND ` +
        `table_name='${table}') THEN (SELECT count(*) FROM public."${table}") ` +
        `ELSE NULL END AS n`,
    )
    .join(' UNION ALL ');

  const { stdout } = await run(
    'psql',
    ['--no-psqlrc', '--tuples-only', '--no-align', '--field-separator=|', '-c', selects, url],
    { maxBuffer: 1024 * 1024 },
  );

  const out = {};
  for (const line of stdout.trim().split('\n')) {
    const [table, n] = line.split('|');
    if (table) out[table.trim()] = n?.trim() ? Number(n) : null;
  }
  return out;
}

async function main() {
  const intoRaw = arg('into');
  if (!intoRaw) {
    console.error(
      [
        'Pass --into <connection string>.',
        '',
        'There is deliberately no default. This script writes over whatever it',
        'is pointed at, and the one mistake it must be incapable of is',
        'overwriting production because a flag was forgotten.',
      ].join('\n'),
    );
    process.exit(1);
  }
  if (
    process.env.DATABASE_URL &&
    intoRaw === process.env.DATABASE_URL &&
    flag('verify')
  ) {
    console.error(
      '--verify restores over the target. Point it at a scratch database, not DATABASE_URL.',
    );
    process.exit(1);
  }

  // Prisma's URL is not libpq's — see `pg-url.mjs`.
  const { url: into, env } = toLibpq(intoRaw);
  Object.assign(process.env, env);

  const dumpPath = arg('file') ?? (await newest(path.resolve(arg('dir', 'backups'))));
  const manifest = await readManifest(dumpPath);

  console.log(`restoring ${dumpPath}`);
  if (manifest) {
    console.log(`  taken ${manifest.created_at}, migration ${manifest.migration ?? 'unknown'}`);
  } else {
    console.log('  no manifest beside this dump — nothing to verify against');
  }

  const began = Date.now();
  // `--clean --if-exists` so a re-verify into the same scratch database works
  // without recreating it. `--exit-on-error` because a partial restore that
  // reports success is the exact failure this script exists to prevent.
  //
  // Not `--single-transaction`: with `--clean` the drops and the loads in one
  // transaction take an exclusive lock on everything for the whole restore, and
  // on a real dataset that is the difference between minutes and an outage.
  await run(
    'pg_restore',
    [
      '--dbname', into,
      '--clean',
      '--if-exists',
      '--no-owner',
      '--no-privileges',
      '--exit-on-error',
      dumpPath,
    ],
    { maxBuffer: 1024 * 1024 * 64 },
  );
  const elapsed = Date.now() - began;
  console.log(`  restored in ${(elapsed / 1000).toFixed(1)}s`);

  if (!manifest?.row_counts) {
    console.log(
      '\nRestore completed. Unverified: no manifest. Treat this as untested.',
    );
    return;
  }

  const tables = Object.keys(manifest.row_counts);
  const after = await counts(into, tables);

  const mismatches = [];
  for (const table of tables) {
    const expected = manifest.row_counts[table];
    const actual = after[table];
    if (expected === null && actual === null) continue;
    if (expected !== actual) mismatches.push({ table, expected, actual });
  }

  if (mismatches.length === 0) {
    console.log(`\nVerified: ${tables.length} tables match the manifest exactly.`);
    console.log(
      `  orders ${after.orders ?? '?'}, journal_lines ${after.journal_lines ?? '?'}, ` +
        `wallets ${after.wallets ?? '?'}`,
    );
    return;
  }

  console.error('\nVERIFICATION FAILED — the restore is not the backup:');
  for (const row of mismatches) {
    console.error(
      `  ${row.table}: manifest ${String(row.expected)}, restored ${String(row.actual)}`,
    );
  }
  console.error(
    '\nDo not treat this dump as a usable backup until the difference is explained.',
  );
  process.exit(1);
}

main().catch((error) => {
  console.error(`restore failed: ${error.message}`);
  if (error.stderr) console.error(String(error.stderr).trim());
  process.exit(1);
});
