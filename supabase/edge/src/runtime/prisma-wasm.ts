import { createHash } from 'node:crypto';

/**
 * Prisma's WASM query compiler, loaded from Storage instead of the bundle.
 *
 * Supabase deploys a function without Docker only while its source is under
 * 5 MB, and the query compiler alone is 2.5 MB of base64 inside the bundle.
 * `build.mjs` therefore writes the module to `.build/assets` and the deploy
 * script uploads it to the public `reem-runtime` bucket — it is Prisma's
 * open-source compiler, nothing secret, and public objects are served from
 * Storage's CDN, which matters because Supabase starts a new isolate for most
 * requests. The name carries its SHA-256; this loader fetches it, checks the
 * digest against the one compiled into the bundle, and compiles it.
 *
 * A mismatch — a stale upload, a tampered object — refuses to start rather
 * than run a query engine that is not the one this bundle was built with.
 */
declare const __REEM_PRISMA_WASM_OBJECT__: string;
declare const __REEM_PRISMA_WASM_SHA256__: string;

export const RUNTIME_BUCKET = 'reem-runtime';

let compiled: Promise<WebAssembly.Module> | null = null;

export function loadQueryCompilerWasm(): Promise<WebAssembly.Module> {
  compiled ??= fetchAndCompile().catch((error) => {
    compiled = null;
    throw error;
  });
  return compiled;
}

async function fetchAndCompile(): Promise<WebAssembly.Module> {
  const url = process.env.SUPABASE_URL?.replace(/\/+$/, '');
  if (!url) throw new Error('Cannot load the Prisma query compiler: SUPABASE_URL missing');

  const response = await fetch(
    `${url}/storage/v1/object/public/${RUNTIME_BUCKET}/${__REEM_PRISMA_WASM_OBJECT__}`,
  );
  if (!response.ok) {
    throw new Error(
      `Cannot load the Prisma query compiler (${response.status}). Upload it with: npm run deploy (supabase/edge).`,
    );
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  const digest = createHash('sha256').update(bytes).digest('hex');
  if (digest !== __REEM_PRISMA_WASM_SHA256__) {
    throw new Error('The Prisma query compiler in Storage does not match this build');
  }
  return WebAssembly.compile(bytes);
}

