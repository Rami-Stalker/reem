/**
 * Translates the Supabase Edge environment into the one the Ohara backend reads.
 *
 * The backend is configured entirely through `process.env` (see
 * `backend/src/config/configuration.ts`). Supabase injects its own variables
 * into every function — `SUPABASE_URL`, `SUPABASE_DB_URL`, the service key —
 * and project secrets set with `supabase secrets set` arrive the same way.
 * This module runs before `AppModule` is imported, derives what the backend
 * needs from what Supabase provides, and refuses to continue when a value the
 * backend cannot run without is absent — a clear message at cold start beats a
 * class-validator dump.
 *
 * Nothing here holds a secret. Every secret is read from the environment.
 */

export const MEDIA_PUBLIC_BUCKET = 'reem-media-public';
export const MEDIA_PRIVATE_BUCKET = 'reem-media-private';

type Env = Record<string, string | undefined>;

function readSupabaseSecretKey(env: Env): string | undefined {
  // New projects expose `sb_secret_…` keys as a JSON map; older ones the JWT
  // service-role key. Either authenticates server-to-server calls to Storage,
  // Realtime and the Auth admin API.
  const map = env.SUPABASE_SECRET_KEYS;
  if (map) {
    try {
      const parsed = JSON.parse(map) as Record<string, string>;
      const key = parsed.default ?? Object.values(parsed)[0];
      if (key) return key;
    } catch {
      // Fall through to the legacy key.
    }
  }
  return env.REEM_SUPABASE_SECRET_KEY ?? env.SUPABASE_SERVICE_ROLE_KEY;
}

function readPublishableKey(env: Env): string | undefined {
  const map = env.SUPABASE_PUBLISHABLE_KEYS;
  if (map) {
    try {
      const parsed = JSON.parse(map) as Record<string, string>;
      const key = parsed.default ?? Object.values(parsed)[0];
      if (key) return key;
    } catch {
      // Fall through to the legacy key.
    }
  }
  return env.SUPABASE_ANON_KEY;
}

export interface SupabaseRuntime {
  url: string;
  secretKey: string;
  publishableKey: string;
  cronSecret: string | undefined;
  sendSmsHookSecret: string | undefined;
  functionName: string;
}

let runtime: SupabaseRuntime | null = null;

/** The Supabase side of the configuration. Available after `prepareEnvironment()`. */
export function supabaseRuntime(): SupabaseRuntime {
  if (!runtime) throw new Error('prepareEnvironment() has not run');
  return runtime;
}

let writableCopy = false;

/**
 * Supabase's runtime refuses writes to the environment ("The operation is not
 * supported"). The backend only ever *reads* `process.env`, so on the first
 * write the whole environment is copied into a plain object that replaces it.
 */
function setEnv(name: string, value: string) {
  if (!writableCopy) {
    try {
      process.env[name] = value;
      if (process.env[name] === value) return;
    } catch {
      // Read-only environment; fall through to the copy.
    }
    const copy: Env = { ...(process.env as Env) };
    try {
      Object.defineProperty(process, 'env', { value: copy, configurable: true, writable: true, enumerable: true });
    } catch {
      (process as unknown as { env: Env }).env = copy;
    }
    writableCopy = true;
  }
  (process.env as Env)[name] = value;
}

function setDefault(name: string, value: string) {
  if (!process.env[name]) setEnv(name, value);
}

export function prepareEnvironment(): SupabaseRuntime {
  const env = process.env as Env;
  const missing: string[] = [];

  const url = env.SUPABASE_URL?.replace(/\/+$/, '');
  if (!url) missing.push('SUPABASE_URL (provided by Supabase)');

  const secretKey = readSupabaseSecretKey(env);
  if (!secretKey) missing.push('SUPABASE_SECRET_KEYS or SUPABASE_SERVICE_ROLE_KEY (provided by Supabase)');

  const publishableKey = readPublishableKey(env) ?? '';

  // The database: an explicit override wins, then the connection Supabase
  // hands every function.
  const databaseUrl = env.REEM_DATABASE_URL ?? env.SUPABASE_DB_URL;
  if (!databaseUrl) missing.push('SUPABASE_DB_URL (provided by Supabase) or REEM_DATABASE_URL');

  for (const key of [
    'JWT_ACCESS_SECRET',
    'JWT_REFRESH_SECRET',
    'OTP_PEPPER',
    'GUEST_TOKEN_PEPPER',
    'OTP_DELIVERY_KEY',
    'TOTP_ENC_KEY',
  ]) {
    if (!env[key]) missing.push(`${key} (edge secret)`);
  }

  if (missing.length > 0) {
    throw new Error(
      'The Ohara API cannot start on Supabase — missing configuration:\n' +
        missing.map((m) => `  - ${m}`).join('\n') +
        '\nSee docs/SUPABASE.md, "Edge Function secrets".',
    );
  }

  setEnv('DATABASE_URL', databaseUrl!);
  setDefault('NODE_ENV', 'production');
  // Timestamps in this schema are `timestamp without time zone` holding UTC.
  // The driver adapter reads them in the process zone, so the zone must be UTC.
  setEnv('TZ', 'UTC');

  // Public media is served by Supabase Storage directly, never through the
  // function: `origin + publicBaseUrl + key` is the object's public URL.
  setDefault('MEDIA_PUBLIC_ORIGIN', url!);
  setDefault('MEDIA_PUBLIC_BASE_URL', `/storage/v1/object/public/${MEDIA_PUBLIC_BUCKET}`);

  // `*_SCHEDULER_ENABLED` flags pass through untouched: they decide whether a
  // scheduled job does its work, exactly as on a server. What changes on the
  // edge is only who pulls the trigger — pg_cron, through /internal/cron.

  // The chat WebSocket is replaced by Supabase Realtime; never accept the
  // legacy query-string token.
  setEnv('WS_QUERY_TOKEN_UNTIL', '');

  // Functions are served under their own name: /functions/v1/api/…
  const functionName = env.REEM_FUNCTION_NAME ?? 'api';

  runtime = {
    url: url!,
    secretKey: secretKey!,
    publishableKey,
    cronSecret: env.REEM_CRON_SECRET,
    sendSmsHookSecret: env.SEND_SMS_HOOK_SECRET,
    functionName,
  };
  return runtime;
}
