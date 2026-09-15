/**
 * Type-level stand-ins for modules that only exist at bundle time.
 *
 * `reem-edge-prisma` is the client `build.mjs` generates into
 * `.build/prisma/client`. Its runtime surface is the backend's `@prisma/client`
 * — generated from the same schema — so for type-checking it *is* that module.
 */
declare module 'reem-edge-prisma' {
  export * from '@prisma/client';
}

/** Present in Supabase's edge runtime; absent under plain Deno and Node. */
declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void } | undefined;
