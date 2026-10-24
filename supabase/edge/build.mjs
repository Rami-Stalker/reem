// Builds the Supabase Edge Function `api` from the Ohara backend.
//
//   node build.mjs              production bundle  → supabase/functions/api/reem-api.mjs
//   node build.mjs --sourcemap  same, plus a linked source map (local debugging)
//
// Three steps, none of which writes inside `backend/`:
//
//   1. tsc compiles backend/src and this host's src/ together into .build/out.
//      tsc, not esbuild, because Nest's dependency injection reads the
//      constructor parameter types TypeScript emits as `design:paramtypes`
//      metadata, and esbuild does not emit it.
//   2. Prisma generates a second client from the *same* schema.prisma, with
//      the WASM query compiler and the node-postgres driver adapter instead of
//      the native engine the backend uses — a native library cannot load in an
//      edge isolate. The schema file is copied, never edited.
//   3. esbuild bundles the compiled output into one ESM file, swapping the
//      three native modules (`@prisma/client`, `argon2`, `sharp`) for the
//      runtime adapters in src/runtime.
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';
import * as esbuild from 'esbuild';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../..');
const backend = path.join(repo, 'backend');
const build = path.join(here, '.build');
const out = path.join(build, 'out');
const prismaOut = path.join(build, 'prisma');
const functionDir = path.join(repo, 'supabase', 'functions', 'api');
const bundleFile = path.join(functionDir, 'reem-api.mjs');
const withSourcemap = process.argv.includes('--sourcemap');

function run(label, command, args, options = {}) {
  const started = Date.now();
  process.stdout.write(`• ${label} … `);
  const result = spawnSync(command, args, { stdio: 'pipe', encoding: 'utf8', shell: false, ...options });
  if (result.status !== 0) {
    process.stdout.write('failed\n');
    process.stderr.write(result.stdout ?? '');
    process.stderr.write(result.stderr ?? '');
    process.exit(result.status ?? 1);
  }
  process.stdout.write(`${((Date.now() - started) / 1000).toFixed(1)}s\n`);
}

if (!existsSync(path.join(backend, 'node_modules', '@nestjs', 'core'))) {
  console.error('backend/node_modules is missing — run `npm install` in backend/ first.');
  process.exit(1);
}

// 1 ── compile ──────────────────────────────────────────────────────────────
rmSync(out, { recursive: true, force: true });
run('Compiling backend + edge host (tsc)', process.execPath, [
  path.join(backend, 'node_modules', 'typescript', 'bin', 'tsc'),
  '-p',
  path.join(here, 'tsconfig.json'),
]);

// 2 ── edge Prisma client ───────────────────────────────────────────────────
const schemaSource = readFileSync(path.join(backend, 'prisma', 'schema.prisma'), 'utf8');
const generatorBlock = /generator\s+client\s*\{[^}]*\}/;
if (!generatorBlock.test(schemaSource)) {
  console.error('Could not find `generator client { … }` in backend/prisma/schema.prisma');
  process.exit(1);
}
const edgeSchema = schemaSource.replace(
  generatorBlock,
  [
    'generator client {',
    '  provider            = "prisma-client"',
    '  output              = "./client"',
    '  runtime             = "deno"',
    '  moduleFormat        = "esm"',
    '  engineType          = "client"',
    '  importFileExtension = "ts"',
    '}',
  ].join('\n'),
);
mkdirSync(prismaOut, { recursive: true });
const schemaFile = path.join(prismaOut, 'schema.prisma');
const previous = existsSync(schemaFile) ? readFileSync(schemaFile, 'utf8') : null;
if (previous !== edgeSchema || !existsSync(path.join(prismaOut, 'client', 'client.ts'))) {
  writeFileSync(schemaFile, edgeSchema);
  run('Generating edge Prisma client', process.execPath, [
    path.join(here, 'node_modules', 'prisma', 'build', 'index.js'),
    'generate',
    '--schema',
    schemaFile,
  ], { env: { ...process.env, DATABASE_URL: process.env.DATABASE_URL ?? 'postgresql://build@localhost/build' } });
} else {
  console.log('• Edge Prisma client is current');
}

// 3 ── bundle ───────────────────────────────────────────────────────────────
const edgeRequire = createRequire(path.join(here, 'package.json'));
const runtime = (file) => path.join(out, 'supabase', 'edge', 'src', 'runtime', file);

// Prisma's query compiler leaves the bundle (see src/runtime/prisma-wasm.ts):
// its bytes go to .build/assets under a content-addressed name that
// scripts/deploy.mjs uploads to Storage, and the bundle carries only the name
// and the digest it will verify.
const wasmModuleUrl = pathToFileURL(
  edgeRequire.resolve('@prisma/client/runtime/query_compiler_bg.postgresql.wasm-base64.mjs'),
).href;
const wasmBytes = Buffer.from((await import(wasmModuleUrl)).wasm, 'base64');
const wasmSha256 = createHash('sha256').update(wasmBytes).digest('hex');
const wasmObject = `prisma/query_compiler_bg.postgresql.${wasmSha256.slice(0, 16)}.wasm`;
const assetsDir = path.join(build, 'assets');
rmSync(assetsDir, { recursive: true, force: true });
mkdirSync(path.dirname(path.join(assetsDir, wasmObject)), { recursive: true });
writeFileSync(path.join(assetsDir, wasmObject), wasmBytes);
writeFileSync(
  path.join(assetsDir, 'manifest.json'),
  JSON.stringify({ bucket: 'reem-runtime', objects: [wasmObject] }, null, 2),
);
const wasmLoader = /getQueryCompilerWasmModule: async \(\) => \{[\s\S]*?\n  \}/;

const nativeSwaps = {
  name: 'reem-native-swaps',
  setup(b) {
    // Exactly `@prisma/client`: the runtime subpaths the generated client
    // imports must still resolve to the real package.
    b.onResolve({ filter: /^@prisma\/client$/ }, () => ({ path: runtime('prisma-client.js') }));
    b.onResolve({ filter: /^@prisma\/client\/runtime\// }, (args) => ({ path: edgeRequire.resolve(args.path) }));
    // The generated edge client, which tsc never sees (see src/runtime/prisma-client.ts).
    b.onResolve({ filter: /^reem-edge-prisma$/ }, () => ({ path: path.join(prismaOut, 'client', 'client.ts') }));
    b.onResolve({ filter: /^argon2$/ }, () => ({ path: runtime('argon2.js') }));
    b.onResolve({ filter: /^sharp$/ }, () => ({ path: runtime('sharp.js') }));
    // Size: libraries whose full weight the edge never uses (see each shim).
    b.onResolve({ filter: /^iconv-lite$/ }, () => ({ path: runtime('iconv.js') }));
    b.onResolve({ filter: /^cron$/ }, () => ({ path: runtime('cron.js') }));
    b.onResolve({ filter: /^mime-db$/ }, () => ({ path: runtime('mime-db.js') }));
    b.onResolve({ filter: /^libphonenumber-js\/max$/ }, () => ({ path: runtime('libphonenumber.js') }));
    // hash-wasm's per-algorithm build: argon2 (and the blake2b it needs) only.
    b.onResolve({ filter: /^hash-wasm$/ }, () => ({
      path: path.join(here, 'node_modules', 'hash-wasm', 'dist', 'argon2.umd.min.js'),
    }));
    // The generated client's WASM loader, pointed at Storage.
    b.onLoad({ filter: /[\\/]prisma[\\/]client[\\/]internal[\\/]class\.ts$/ }, (args) => {
      const source = readFileSync(args.path, 'utf8');
      if (!wasmLoader.test(source)) {
        throw new Error('Prisma client changed shape: getQueryCompilerWasmModule not found');
      }
      const target = JSON.stringify(runtime('prisma-wasm.js').split(path.sep).join('/'));
      return {
        contents: source.replace(
          wasmLoader,
          `getQueryCompilerWasmModule: async () => (await import(${target})).loadQueryCompilerWasm()`,
        ),
        loader: 'ts',
      };
    });
  },
};

mkdirSync(functionDir, { recursive: true });
const started = Date.now();
process.stdout.write('• Bundling (esbuild) … ');
const result = await esbuild.build({
  entryPoints: [path.join(out, 'supabase', 'edge', 'src', 'main.js')],
  outfile: bundleFile,
  bundle: true,
  format: 'esm',
  platform: 'node',
  target: 'es2022',
  minify: true,
  // Nest names providers, loggers and cron jobs after their classes; mangled
  // names would reach logs and the cron registry as `vJA`.
  keepNames: true,
  define: {
    __REEM_PRISMA_WASM_OBJECT__: JSON.stringify(wasmObject),
    __REEM_PRISMA_WASM_SHA256__: JSON.stringify(wasmSha256),
  },
  sourcemap: withSourcemap ? 'linked' : false,
  legalComments: 'none',
  metafile: true,
  logLevel: 'warning',
  plugins: [nativeSwaps],
  nodePaths: [path.join(backend, 'node_modules'), path.join(here, 'node_modules')],
  // Optional peers Nest and pg probe for with a guarded require().
  external: [
    '@nestjs/microservices',
    '@nestjs/microservices/*',
    '@nestjs/websockets',
    '@nestjs/websockets/*',
    '@fastify/*',
    'class-transformer/storage',
    'cache-manager',
    'pg-native',
  ],
  // CommonJS inside the bundle still calls require() for node built-ins, and
  // Node libraries expect Node's globals, which Supabase's edge runtime (unlike
  // the Deno CLI) does not predefine.
  banner: {
    js: [
      "import { createRequire as __oharaCreateRequire } from 'node:module';",
      "import { Buffer as __oharaBuffer } from 'node:buffer';",
      "import __oharaProcess from 'node:process';",
      "import { setImmediate as __oharaSetImmediate, clearImmediate as __oharaClearImmediate } from 'node:timers';",
      'const require = __oharaCreateRequire(import.meta.url);',
      'globalThis.Buffer ??= __oharaBuffer;',
      'globalThis.process ??= __oharaProcess;',
      'globalThis.global ??= globalThis;',
      'globalThis.setImmediate ??= __oharaSetImmediate;',
      'globalThis.clearImmediate ??= __oharaClearImmediate;',
      // Version probes (jsonwebtoken, semver-gated code) read these.
      "if (!globalThis.process.version) { try { Object.defineProperty(globalThis.process, 'version', { value: 'v22.0.0', configurable: true }); } catch {} }",
      "if (globalThis.process.versions && !globalThis.process.versions.node) { try { globalThis.process.versions.node = '22.0.0'; } catch {} }",
      // Properties Node libraries read at load time that the edge runtime leaves
      // undefined — Prisma's id generator calls process.pid.toString(36).
      "for (const [k, v] of Object.entries({ pid: 1, ppid: 0, platform: 'linux', arch: 'x64', title: 'reem-api', argv: ['edge', 'reem-api'], execArgv: [] })) { if (globalThis.process[k] === undefined) { try { Object.defineProperty(globalThis.process, k, { value: v, configurable: true, writable: true }); } catch {} } }",
    ].join('\n'),
  },
});
process.stdout.write(`${((Date.now() - started) / 1000).toFixed(1)}s\n`);

const bytes = statSync(bundleFile).size;
const megabytes = bytes / 1024 / 1024;
console.log(`\n  ${path.relative(repo, bundleFile)}  ${megabytes.toFixed(2)} MB`);
console.log(
  `  .build/assets/${wasmObject}  ${(wasmBytes.length / 1024 / 1024).toFixed(2)} MB (uploaded to Storage by scripts/deploy.mjs)`,
);
// Server-side bundling (`functions deploy --use-api`, no Docker) refuses sources
// over 5 MB; local bundling through Docker allows 20 MB.
if (megabytes > 4.8) {
  console.warn('  Over 4.8 MB: deploy with Docker bundling, or trim the bundle before using --use-api.');
}
writeFileSync(path.join(build, 'meta.json'), JSON.stringify(result.metafile));
