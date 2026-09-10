/**
 * A `DATABASE_URL` that libpq will actually accept.
 *
 * Prisma's connection string is not a PostgreSQL one. It carries parameters
 * that only its own driver understands — `schema`, `connection_limit`,
 * `pool_timeout`, `pgbouncer` — and `psql` refuses the whole URI on the first
 * one it does not recognise:
 *
 *     psql: error: invalid URI query parameter: "schema"
 *
 * Which is how a backup script written against `process.env.DATABASE_URL`
 * fails on every real deployment while working perfectly in whatever
 * environment its author tested it in. `?schema=public` is in the default
 * `.env.example`, so this is not an edge case; it is the normal case.
 *
 * The schema is not discarded. libpq has no `schema` parameter, but it does
 * honour `PGOPTIONS`, so it comes back as a `search_path` for the child
 * process — which is the same instruction by a different name.
 */

/** Query parameters libpq understands. Everything else is Prisma's. */
const LIBPQ_PARAMS = new Set([
  'application_name',
  'channel_binding',
  'client_encoding',
  'connect_timeout',
  'fallback_application_name',
  'gssencmode',
  'host',
  'hostaddr',
  'keepalives',
  'keepalives_count',
  'keepalives_idle',
  'keepalives_interval',
  'options',
  'passfile',
  'port',
  'replication',
  'require_auth',
  'requiressl',
  'service',
  'sslcert',
  'sslcompression',
  'sslcrl',
  'sslcrldir',
  'sslkey',
  'sslmode',
  'sslpassword',
  'sslrootcert',
  'sslsni',
  'target_session_attrs',
  'tcp_user_timeout',
]);

/**
 * Splits a Prisma connection string into the URL to pass to `psql`/`pg_dump`
 * and the environment those tools need.
 *
 * @param {string} raw
 * @returns {{ url: string, env: Record<string, string> }}
 */
export function toLibpq(raw) {
  let parsed;
  try {
    parsed = new URL(raw);
  } catch {
    // Not a URL at all — a `service=` name or a key/value DSN. Both are things
    // libpq accepts and Prisma does not produce, so pass it through untouched
    // rather than mangling something that already works.
    return { url: raw, env: {} };
  }

  const env = {};
  const schema = parsed.searchParams.get('schema');
  if (schema) {
    // Quoted, because a schema name is an identifier and `search_path` will
    // otherwise fold or split one that needs quoting.
    env.PGOPTIONS = `-c search_path="${schema}"`;
  }

  for (const key of [...parsed.searchParams.keys()]) {
    if (!LIBPQ_PARAMS.has(key)) parsed.searchParams.delete(key);
  }

  return { url: parsed.toString(), env };
}
