// Deploys the Reem API to a Supabase project, without Docker.
//
//   SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SECRET_KEY=<secret key> \
//   SUPABASE_ACCESS_TOKEN=<token, or run `supabase login` once> \
//   node scripts/deploy.mjs --project-ref <ref> [--skip-build]
//
//  1. builds the bundle (build.mjs) unless --skip-build;
//  2. uploads the runtime assets listed in .build/assets/manifest.json to the
//     private `reem-runtime` bucket (content-addressed names, so a new build
//     never overwrites what a running isolate is still loading);
//  3. deploys the `api` function with server-side bundling (`--use-api`),
//     which accepts sources up to 5 MB.
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const edge = path.resolve(here, '..');
const repo = path.resolve(edge, '../..');
const args = process.argv.slice(2);
const flag = (name) => {
  const index = args.indexOf(`--${name}`);
  return index === -1 ? undefined : args[index + 1];
};

const projectRef = flag('project-ref') ?? process.env.SUPABASE_PROJECT_REF;
const supabaseUrl = process.env.SUPABASE_URL?.replace(/\/+$/, '');
const secretKey = process.env.SUPABASE_SECRET_KEY;
if (!projectRef || !supabaseUrl || !secretKey) {
  console.error('Need --project-ref, SUPABASE_URL and SUPABASE_SECRET_KEY.');
  process.exit(1);
}

function run(label, command, commandArgs, options = {}) {
  process.stdout.write(`• ${label} … `);
  const result = spawnSync(command, commandArgs, { stdio: 'pipe', encoding: 'utf8', cwd: repo, ...options });
  if (result.status !== 0) {
    process.stdout.write('failed\n');
    process.stderr.write(`${result.stdout ?? ''}${result.stderr ?? ''}`);
    process.exit(result.status ?? 1);
  }
  process.stdout.write('done\n');
  return result.stdout;
}

if (!args.includes('--skip-build')) {
  run('Building', process.execPath, [path.join(edge, 'build.mjs')]);
}

const bundle = path.join(repo, 'supabase', 'functions', 'api', 'reem-api.mjs');
const bytes = statSync(bundle).size;
if (bytes >= 5_000_000) {
  console.error(`The bundle is ${bytes} bytes; deploys without Docker accept under 5,000,000.`);
  process.exit(1);
}

const manifestFile = path.join(edge, '.build', 'assets', 'manifest.json');
if (!existsSync(manifestFile)) {
  console.error('No .build/assets/manifest.json — run the build first.');
  process.exit(1);
}
const manifest = JSON.parse(readFileSync(manifestFile, 'utf8'));
for (const object of manifest.objects) {
  process.stdout.write(`• Uploading ${manifest.bucket}/${object} … `);
  const response = await fetch(`${supabaseUrl}/storage/v1/object/${manifest.bucket}/${object}`, {
    method: 'POST',
    headers: {
      apikey: secretKey,
      Authorization: `Bearer ${secretKey}`,
      'Content-Type': 'application/wasm',
      'x-upsert': 'true',
      'cache-control': 'public, max-age=31536000, immutable',
    },
    body: readFileSync(path.join(edge, '.build', 'assets', object)),
  });
  if (!response.ok) {
    process.stdout.write('failed\n');
    console.error(await response.text());
    process.exit(1);
  }
  process.stdout.write('done\n');
}

const cli = path.join(edge, 'node_modules', '.bin', process.platform === 'win32' ? 'supabase.cmd' : 'supabase');
run(`Deploying api to ${projectRef} (${(bytes / 1024 / 1024).toFixed(2)} MB)`, cli, [
  'functions', 'deploy', 'api', '--project-ref', projectRef, '--use-api', '--no-verify-jwt',
], { shell: process.platform === 'win32' });

// The start-up seeds a server runs at every boot run once per deploy here
// (src/runtime/boot-seeds.ts).
const cronSecret = process.env.REEM_CRON_SECRET;
if (cronSecret) {
  process.stdout.write('• Running start-up seeds … ');
  const seeded = await fetch(`${supabaseUrl}/functions/v1/api/internal/cron/boot-seeds`, {
    method: 'POST',
    headers: { 'x-reem-cron-secret': cronSecret },
  });
  process.stdout.write(seeded.ok ? 'done\n' : `failed (${seeded.status})\n`);
} else {
  console.log('• REEM_CRON_SECRET not set here: call POST /internal/cron/boot-seeds after this deploy.');
}

console.log(`\nDeployed: ${supabaseUrl}/functions/v1/api/health`);
