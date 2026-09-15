/**
 * `@prisma/client`, as the backend sees it on the edge.
 *
 * The build resolves every `import … from '@prisma/client'` in the backend to
 * this file. It re-exports the edge client generated from the backend's own
 * `schema.prisma` — same models, same enums, same `Prisma` namespace — and
 * replaces one thing: `PrismaClient` connects through the node-postgres driver
 * adapter instead of the native query engine, which cannot load in an isolate.
 *
 * `PrismaService extends PrismaClient` and calls `super({ log })`, so the
 * adapter is attached here, in the constructor, without that class changing.
 */
import { PrismaPg } from '@prisma/adapter-pg';
import * as generated from 'reem-edge-prisma';
import { SUPABASE_ROOT_CA_2021 } from './supabase-ca';

export * from 'reem-edge-prisma';

/**
 * Supabase starts an isolate for almost every request, so a busy minute means
 * hundreds of isolates, each with its own pool. Measured on the live project:
 * with a pool of four on the direct connection, thirty phones exhausted
 * Postgres's 60 connections within seconds ("remaining connection slots are
 * reserved"). One connection per isolate, through the transaction pooler
 * (`REEM_DATABASE_URL`, port 6543), which multiplexes them onto a small set of
 * server connections.
 */
const POOL_SIZE = Number(process.env.REEM_DB_POOL_SIZE ?? '1');

/** TLS verified against Supabase's CA for pooler hosts; `sslmode` in the URL is left to `pg` otherwise. */
function connectionOptions(url: string | undefined) {
  if (!url) return { connectionString: url };
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return { connectionString: url };
  }
  if (!parsed.hostname.endsWith('.pooler.supabase.com') || parsed.searchParams.get('sslmode') === 'disable') {
    return { connectionString: url };
  }
  parsed.searchParams.delete('sslmode');
  return {
    connectionString: parsed.toString(),
    ssl: { ca: SUPABASE_ROOT_CA_2021, rejectUnauthorized: true, servername: parsed.hostname },
  };
}

export class PrismaClient extends generated.PrismaClient {
  constructor(options: Record<string, unknown> = {}) {
    const adapter = new PrismaPg({
      ...connectionOptions(process.env.DATABASE_URL),
      max: POOL_SIZE,
      // An isolate that has answered should not hold a pooler slot.
      idleTimeoutMillis: 2_000,
      connectionTimeoutMillis: 15_000,
    });
    super({ ...options, adapter } as never);
  }
}
