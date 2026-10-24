// Copies the Ohara data — rows and uploaded files — from the local PostgreSQL
// into the Supabase project. Nothing local is changed or deleted.
//
//   node scripts/migrate-data.mjs export
//       Dumps every row of the local database (backend/.env DATABASE_URL) to
//       supabase/.temp/reem-data.sql. Schema is NOT dumped: Supabase's schema
//       comes from supabase/migrations, which reproduce it exactly.
//
//   SUPABASE_DB_URL="postgresql://postgres.<ref>:<password>@<pooler-host>:5432/postgres" \
//   SUPABASE_URL="https://<ref>.supabase.co" SUPABASE_SECRET_KEY="<sb_secret_…>" \
//   node scripts/migrate-data.mjs import [--skip-media] [--replace-existing-data]
//       Loads the dump into Supabase in one transaction, uploads the files
//       under backend/storage/media to the two Storage buckets, rewrites
//       stored URLs that point at a laptop, and compares row counts table by
//       table against the local database.
//
// The dump holds every customer's phone number, address and order history.
// It is written under supabase/.temp (git-ignored) and should be deleted once
// the import is verified.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../../..');
const dumpFile = path.join(repo, 'supabase', '.temp', 'reem-data.sql');
const command = process.argv[2];

function pgBin(name) {
  const candidates = [
    process.env.PG_BIN && path.join(process.env.PG_BIN, name),
    `C:\\Program Files\\PostgreSQL\\18\\bin\\${name}.exe`,
    `C:\\Program Files\\PostgreSQL\\17\\bin\\${name}.exe`,
    name,
  ].filter(Boolean);
  return candidates.find((candidate) => candidate === name || existsSync(candidate));
}

function localDatabaseUrl() {
  if (process.env.LOCAL_DATABASE_URL) return process.env.LOCAL_DATABASE_URL;
  const env = readFileSync(path.join(repo, 'backend', '.env'), 'utf8');
  const match = /^DATABASE_URL\s*=\s*"?([^"\n]+)"?/m.exec(env);
  if (!match) throw new Error('DATABASE_URL not found in backend/.env');
  return match[1].replace(/\?schema=public$/, '');
}

function run(bin, args, options = {}) {
  const result = spawnSync(pgBin(bin), args, { encoding: 'utf8', maxBuffer: 1024 * 1024 * 256, ...options });
  if (result.status !== 0) {
    throw new Error(`${bin} failed (${result.status}):\n${result.stderr || result.stdout}`);
  }
  return result.stdout;
}

function counts(url) {
  const sql = `
    SELECT format('%s|%s', c.relname,
      (xpath('/row/n/text()', query_to_xml(format('select count(*) as n from public.%I', c.relname), false, true, '')))[1]::text)
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relname <> '_prisma_migrations'
     ORDER BY 1`;
  return Object.fromEntries(
    run('psql', [url, '-Atc', sql])
      .trim()
      .split('\n')
      .filter(Boolean)
      .map((line) => {
        const [table, n] = line.split('|');
        return [table, Number(n)];
      }),
  );
}

async function exportData() {
  mkdirSync(path.dirname(dumpFile), { recursive: true });
  const url = localDatabaseUrl();
  run('pg_dump', [
    url,
    '--data-only',
    '--format=plain',
    '--no-owner',
    '--no-privileges',
    '--schema=public',
    '--exclude-table=public._prisma_migrations',
    `--file=${dumpFile}`,
  ]);
  const local = counts(url);
  const rows = Object.values(local).reduce((sum, n) => sum + n, 0);
  console.log(`Exported ${rows} rows from ${Object.keys(local).length} tables → ${path.relative(repo, dumpFile)} (${(statSync(dumpFile).size / 1024 / 1024).toFixed(1)} MB)`);
}

function walk(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory() ? walk(full) : [full];
  });
}

const CONTENT_TYPES = {
  jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp', gif: 'image/gif',
  mp4: 'video/mp4', mov: 'video/quicktime', m4a: 'audio/mp4', ogg: 'audio/ogg', wav: 'audio/wav',
  mp3: 'audio/mpeg', pdf: 'application/pdf',
};

async function uploadMedia(supabaseUrl, secretKey) {
  const root = path.join(repo, 'backend', 'storage', 'media');
  let uploaded = 0;
  let skipped = 0;
  for (const [folder, bucket] of [['public', 'reem-media-public'], ['private', 'reem-media-private']]) {
    for (const file of walk(path.join(root, folder))) {
      const key = path.relative(path.join(root, folder), file).split(path.sep).join('/');
      const extension = key.slice(key.lastIndexOf('.') + 1).toLowerCase();
      const response = await fetch(`${supabaseUrl}/storage/v1/object/${bucket}/${key}`, {
        method: 'POST',
        headers: {
          apikey: secretKey,
          Authorization: `Bearer ${secretKey}`,
          'Content-Type': CONTENT_TYPES[extension] ?? 'application/octet-stream',
          'x-upsert': 'true',
          'cache-control': 'max-age=31536000, immutable',
        },
        body: readFileSync(file),
      });
      if (response.ok) uploaded += 1;
      else {
        skipped += 1;
        console.warn(`  ! ${bucket}/${key}: ${response.status} ${await response.text()}`);
      }
    }
  }
  return { uploaded, skipped };
}

async function importData() {
  const target = process.env.SUPABASE_DB_URL;
  const supabaseUrl = process.env.SUPABASE_URL?.replace(/\/+$/, '');
  const secretKey = process.env.SUPABASE_SECRET_KEY;
  if (!target || !supabaseUrl || !secretKey) {
    throw new Error('Set SUPABASE_DB_URL, SUPABASE_URL and SUPABASE_SECRET_KEY in the environment.');
  }
  if (!existsSync(dumpFile)) throw new Error('Run `node scripts/migrate-data.mjs export` first.');

  const before = counts(target);
  const nonEmpty = Object.entries(before).filter(([, n]) => n > 0);
  // Migrations seed a few reference rows (content types, synonyms, permissions)
  // and the API's first boot a few more; anything beyond that is real data.
  if (nonEmpty.reduce((sum, [, n]) => sum + n, 0) > 50 && !process.argv.includes('--replace-existing-data')) {
    throw new Error(`The Supabase database already holds data (${nonEmpty.length} non-empty tables). Pass --replace-existing-data to empty the Supabase tables and import anyway.`);
  }

  console.log('• Emptying tables the API seeded at boot …');
  run('psql', [target, '-v', 'ON_ERROR_STOP=1', '-qc', `
    DO $$ DECLARE t record; BEGIN
      FOR t IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relname <> '_prisma_migrations' LOOP
        EXECUTE format('TRUNCATE public.%I CASCADE', t.relname);
      END LOOP;
    END $$;`]);

  console.log('• Loading rows (one transaction) …');
  // pg_dump orders tables so every foreign key's target loads first, and the
  // whole file runs as one transaction: either every row arrives, with every
  // constraint checked, or none does.
  run('psql', [
    target, '--single-transaction', '-v', 'ON_ERROR_STOP=1', '-q',
    '-c', 'SET client_min_messages = warning',
    '-f', dumpFile,
  ]);

  if (!process.argv.includes('--skip-media')) {
    console.log('• Uploading media files …');
    const media = await uploadMedia(supabaseUrl, secretKey);
    console.log(`  ${media.uploaded} uploaded, ${media.skipped} failed`);
  }

  console.log('• Rewriting stored URLs that point at a development machine …');
  const publicBase = `${supabaseUrl}/storage/v1/object/public/reem-media-public/`;
  const apiBase = `${supabaseUrl}/functions/v1/api/media/`;
  const rewrite = `
    DO $$
    DECLARE c record; n bigint; total bigint := 0;
    BEGIN
      FOR c IN
        SELECT table_name, column_name, data_type FROM information_schema.columns
         WHERE table_schema = 'public' AND data_type IN ('text', 'character varying')
           AND (column_name ILIKE '%url%' OR column_name ILIKE '%image%' OR column_name IN ('image_snapshot'))
      LOOP
        EXECUTE format($f$
          UPDATE public.%1$I SET %2$I =
            regexp_replace(
              regexp_replace(%2$I, '^https?://[^/]+/media/files/', %3$L),
              '^https?://(localhost|127\\.0\\.0\\.1|10\\.0\\.2\\.2|192\\.168\\.[0-9.]+|0\\.0\\.0\\.0)(:[0-9]+)?/media/', %4$L)
           WHERE %2$I ~ '^https?://[^/]+/media/files/'
              OR %2$I ~ '^https?://(localhost|127\\.0\\.0\\.1|10\\.0\\.2\\.2|192\\.168\\.[0-9.]+|0\\.0\\.0\\.0)(:[0-9]+)?/media/'
        $f$, c.table_name, c.column_name, '${publicBase}', '${apiBase}');
        GET DIAGNOSTICS n = ROW_COUNT;
        total := total + n;
      END LOOP;
      UPDATE public.media_assets SET driver = 'supabase' WHERE driver = 'local';
      RAISE NOTICE 'rewrote % stored URLs', total;
    END $$;`;
  process.stdout.write(run('psql', [target, '-v', 'ON_ERROR_STOP=1', '-c', rewrite]));

  console.log('• Comparing row counts …');
  const local = counts(localDatabaseUrl());
  const remote = counts(target);
  let mismatches = 0;
  for (const [table, n] of Object.entries(local)) {
    if (remote[table] !== n) {
      mismatches += 1;
      console.log(`  ✗ ${table}: local ${n}, supabase ${remote[table]}`);
    }
  }
  const rows = Object.values(remote).reduce((sum, n) => sum + n, 0);
  console.log(mismatches === 0
    ? `  ✓ all ${Object.keys(local).length} tables match (${rows} rows)`
    : `  ${mismatches} table(s) differ — the API may have written rows since the export`);
}

try {
  if (command === 'export') await exportData();
  else if (command === 'import') await importData();
  else {
    console.log('usage: node scripts/migrate-data.mjs export | import [--skip-media] [--replace-existing-data]');
    process.exitCode = 1;
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
