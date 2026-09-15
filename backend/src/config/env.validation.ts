import { plainToInstance } from 'class-transformer';
import {
  MAX_TEST_ACCOUNT_DAYS,
  parseOtpTestAccounts,
  testAccountsActive,
} from '../modules/auth/otp/otp-test-accounts';
import {
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  MinLength,
  validateSync,
} from 'class-validator';

/**
 * Fail-fast validation of the environment at boot. Misconfigured secrets are
 * the #1 source of silent auth bugs, so we refuse to start without them.
 */
class EnvironmentVariables {
  /**
   * Required, not optional. Two of the worst defects in this codebase were
   * `NODE_ENV !== 'production'` branches that opened a hole whenever the
   * variable was simply absent — and absent was the default: it was unset in
   * `start:prod` and marked optional here. A deployment that forgets to set it
   * must now fail to boot rather than silently select the permissive path.
   */
  @IsIn(['development', 'test', 'production'])
  NODE_ENV!: string;

  @IsOptional()
  @IsString()
  HOST?: string;

  @IsNotEmpty()
  @IsString()
  DATABASE_URL!: string;

  @IsString()
  @MinLength(32)
  JWT_ACCESS_SECRET!: string;

  @IsString()
  @MinLength(32)
  JWT_REFRESH_SECRET!: string;

  /** Peppers the stored one-time-code digests. */
  @IsString()
  @MinLength(32)
  OTP_PEPPER!: string;

  /** Peppers stored guest-session tokens. Separate from the JWT keys. */
  @IsString()
  @MinLength(32)
  GUEST_TOKEN_PEPPER!: string;

  /**
   * Seals the plaintext code in the delivery outbox. Reversible, unlike every
   * other secret here, which is exactly why it is its own key.
   */
  @IsString()
  @MinLength(32)
  OTP_DELIVERY_KEY!: string;

  /** Encrypts TOTP shared secrets. */
  @IsString()
  @MinLength(32)
  TOTP_ENC_KEY!: string;

  /**
   * Uploads. All optional — the defaults in `configuration.ts` store bytes
   * under `storage/media` and derive public URLs from the request's own
   * origin, which is what a developer wants without configuring anything.
   */
  @IsOptional()
  @IsIn(['local', 'supabase'])
  MEDIA_DRIVER?: string;

  /** `https://<project-ref>.supabase.co`. Required by `MEDIA_DRIVER=supabase`. */
  @IsOptional()
  @IsString()
  SUPABASE_URL?: string;

  /** The project's secret key. Server-only; see the checks below. */
  @IsOptional()
  @IsString()
  SUPABASE_SECRET_KEY?: string;

  @IsOptional()
  @IsIn(['true', 'false'])
  SCHEDULER_ENABLED?: string;

  /** Enables the job trigger route; long enough not to be guessed. */
  @IsOptional()
  @IsString()
  @MinLength(32)
  JOBS_TRIGGER_SECRET?: string;

  @IsOptional()
  @IsString()
  MEDIA_LOCAL_ROOT?: string;

  @IsOptional()
  @IsString()
  MEDIA_PUBLIC_BASE_URL?: string;

  @IsOptional()
  @IsString()
  MEDIA_PUBLIC_ORIGIN?: string;

  /**
   * Transitional deadline for the retired `?token=` on the chat socket. An ISO
   * instant; see the checks below for why it is bounded and not a boolean.
   */
  @IsOptional()
  @IsString()
  WS_QUERY_TOKEN_UNTIL?: string;
}

/**
 * The longest transition this fallback may be granted.
 *
 * A staged client rollout is days, not quarters. The cap is the difference
 * between a deadline and a permanent exemption written in date form: without
 * it, the value someone reaches for under pressure is next year's, and the
 * access token goes on being written into proxy logs for all of it.
 */
const MAX_WS_QUERY_TOKEN_DAYS = 30;

/** Distinct secrets, so compromising or rotating one never moves the others. */
const KEYRING = [
  'JWT_ACCESS_SECRET',
  'JWT_REFRESH_SECRET',
  'OTP_PEPPER',
  'GUEST_TOKEN_PEPPER',
  'OTP_DELIVERY_KEY',
  'TOTP_ENC_KEY',
] as const;

export function validateEnv(config: Record<string, unknown>) {
  const validated = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });
  const errors = validateSync(validated, { skipMissingProperties: false });
  if (errors.length > 0) {
    throw new Error(
      `Invalid environment configuration:\n${errors
        .map(
          (e) =>
            `  - ${e.property}: ${Object.values(e.constraints ?? {}).join(', ')}`,
        )
        .join('\n')}`,
    );
  }

  const values = KEYRING.map((key) => String(config[key]));
  if (new Set(values).size !== values.length) {
    throw new Error(
      'Invalid environment configuration:\n  - the auth keyring must use four distinct secrets ' +
        `(${KEYRING.join(', ')}); reusing one makes key rotation an outage.`,
    );
  }

  /**
   * In production the client-visible origin is the reverse proxy's, and the
   * request-derived fallback would hand every client a URL pointing at the
   * app's internal address. Every image on the platform would 404, and it
   * would 404 only for real users — never on the machine that deployed it.
   */
  if (
    config.NODE_ENV === 'production' &&
    !config.MEDIA_PUBLIC_ORIGIN &&
    !config.RENDER_EXTERNAL_URL
  ) {
    throw new Error(
      [
        'Invalid environment configuration:',
        '  - MEDIA_PUBLIC_ORIGIN must be set in production (Render provides',
        '    RENDER_EXTERNAL_URL, which is used when it is not); without it media',
        '    URLs are built from the origin each request happened to arrive on.',
      ].join('\n'),
    );
  }

  const hostingProblems = [
    ...supabaseDatabaseUrlProblems(String(config.DATABASE_URL)),
    ...(config.MEDIA_DRIVER === 'supabase' ? supabaseStorageProblems(config) : []),
  ];
  if (hostingProblems.length > 0) {
    throw new Error(
      [
        'Invalid environment configuration:',
        ...hostingProblems.map((problem) => `  - ${problem}`),
      ].join('\n'),
    );
  }

  /**
   * Sign-in is a one-time code, so a production API with no way to deliver
   * one cannot let anybody in — not a customer, not the first administrator.
   * The development stand-ins (the dev inbox, log echo, the ops console) are
   * each refused in production already; this refuses the state they left
   * behind: nothing real configured at all. Boot fails loudly instead of the
   * app answering "code sent" to every woman and delivering nothing.
   */
  /**
   * Fixed test codes: malformed, undated or open-ended configuration is
   * refused outright, in every environment.
   */
  let otpTestAccountsActive = false;
  try {
    const accounts = parseOtpTestAccounts(
      config.OTP_TEST_ACCOUNTS as string | undefined,
      config.OTP_TEST_ACCOUNTS_UNTIL as string | undefined,
    );
    if (
      accounts.until &&
      accounts.until.getTime() > Date.now() + MAX_TEST_ACCOUNT_DAYS * 24 * 60 * 60 * 1000
    ) {
      throw new Error(
        `OTP_TEST_ACCOUNTS_UNTIL is more than ${MAX_TEST_ACCOUNT_DAYS} days out; fixed codes are a test window, not a configuration`,
      );
    }
    otpTestAccountsActive = testAccountsActive(accounts);
  } catch (error) {
    throw new Error(
      ['Invalid environment configuration:', `  - ${(error as Error).message}`].join('\n'),
    );
  }

  // While a dated test window is open, the named accounts can sign in without
  // a provider; everyone else still cannot. Once it closes, this refusal is
  // back in force at the next start.
  if (
    config.NODE_ENV === 'production' &&
    !hasRealOtpTransport(config) &&
    !otpTestAccountsActive
  ) {
    throw new Error(
      [
        'Invalid environment configuration:',
        '  - no OTP delivery provider is configured, so nobody could sign in.',
        '    Set one of: SMS_GATEWAY_URL + SMS_GATEWAY_KEY, WHATSAPP_PHONE_NUMBER_ID +',
        '    WHATSAPP_ACCESS_TOKEN, or VOICE_OTP_URL + VOICE_OTP_KEY.',
      ].join('\n'),
    );
  }

  /**
   * A container's filesystem is not storage: it is wiped on every deploy and
   * every restart on every managed host this API would run on. With the local
   * driver in production each upload would 404 after the next deploy, and the
   * rows pointing at it would outlive it. Opt back in only for a server with a
   * persistent volume mounted at MEDIA_LOCAL_ROOT.
   */
  if (
    config.NODE_ENV === 'production' &&
    (config.MEDIA_DRIVER ?? 'local') === 'local' &&
    config.MEDIA_LOCAL_PERSISTENT !== 'true'
  ) {
    throw new Error(
      [
        'Invalid environment configuration:',
        '  - MEDIA_DRIVER is local in production. Uploads written to a container',
        '    disk are lost on the next deploy. Use MEDIA_DRIVER=supabase, or set',
        '    MEDIA_LOCAL_PERSISTENT=true if MEDIA_LOCAL_ROOT is a persistent volume.',
      ].join('\n'),
    );
  }

  if (config.NODE_ENV === 'production' && config.OTP_DEV_ECHO === 'true') {
    throw new Error(
      'Invalid environment configuration:\n  - OTP_DEV_ECHO cannot be enabled in production; it writes one-time codes to the log.',
    );
  }

  if (
    config.NODE_ENV === 'production' &&
    config.OTP_DEV_INBOX_ENABLED === 'true'
  ) {
    throw new Error(
      'Invalid environment configuration:\n  - OTP_DEV_INBOX_ENABLED cannot be enabled in production; it serves one-time codes to anyone who can reach the port.',
    );
  }

  if (
    config.NODE_ENV === 'production' &&
    config.PAYMENTS_SANDBOX_CONFIRMATION === 'true'
  ) {
    throw new Error(
      [
        'Invalid environment configuration:',
        '  - PAYMENTS_SANDBOX_CONFIRMATION cannot be enabled in production; it',
        '    lets a customer confirm her own payment on a rail no provider can',
        '    attest, marking the order paid and shipping the goods for free.',
      ].join('\n'),
    );
  }

  /**
   * `origin: true` reflects whatever `Origin` the caller sent, and the API
   * pairs it with `credentials: true`. There are no cookies today, so this is
   * defence in depth rather than a live hole — but it is the one production
   * knob with no guard, and the day someone adds a cookie is not the day to
   * discover that.
   */
  if (config.NODE_ENV === 'production') {
    const origins = String(config.CORS_ORIGINS ?? '').trim();
    if (!origins || origins === '*') {
      throw new Error(
        [
          'Invalid environment configuration:',
          '  - CORS_ORIGINS must name the allowed origins in production.',
          '    "*" reflects any caller back with credentials enabled.',
        ].join('\n'),
      );
    }
  }

  /**
   * The placeholders in `.env.example` are 32+ characters and distinct, so
   * they satisfy every rule above. `cp .env.example .env` would otherwise boot
   * production with signing keys published in the repository.
   */
  const placeholders = KEYRING.filter((key) =>
    String(config[key] ?? '')
      .toLowerCase()
      .includes('change-me'),
  );
  if (config.NODE_ENV === 'production' && placeholders.length > 0) {
    throw new Error(
      [
        'Invalid environment configuration:',
        `  - these secrets are still the published placeholders: ${placeholders.join(', ')}.`,
        '    Generate real values; the ones in .env.example are public.',
      ].join('\n'),
    );
  }

  const wsQueryTokenUntil = config.WS_QUERY_TOKEN_UNTIL;
  if (typeof wsQueryTokenUntil === 'string' && wsQueryTokenUntil.trim()) {
    const deadline = new Date(wsQueryTokenUntil.trim());
    if (Number.isNaN(deadline.getTime())) {
      throw new Error(
        [
          'Invalid environment configuration:',
          `  - WS_QUERY_TOKEN_UNTIL is not a date: ${wsQueryTokenUntil}`,
          '    Expected an ISO instant, e.g. 2026-09-15T00:00:00Z. An',
          '    unparseable value must not read as "off" — that is the reading',
          '    that silently strands every client still on the old handshake.',
        ].join('\n'),
      );
    }

    const ceiling = new Date(
      Date.now() + MAX_WS_QUERY_TOKEN_DAYS * 24 * 60 * 60 * 1000,
    );
    if (deadline > ceiling) {
      throw new Error(
        [
          'Invalid environment configuration:',
          `  - WS_QUERY_TOKEN_UNTIL is more than ${MAX_WS_QUERY_TOKEN_DAYS} days out.`,
          '    It accepts the whole access token in a query string, which every',
          '    proxy on the way writes into its access log. That is a rollout',
          '    window, not a configuration.',
        ].join('\n'),
      );
    }
  }

  return config;
}

/**
 * `MEDIA_DRIVER=supabase` needs the project URL and the *secret* key: Storage
 * writes to a bucket with no client policy are refused to anything less. The
 * publishable key is the one mistake worth naming, because it looks like it
 * works — until the first upload answers 403 in front of a seller.
 */
function supabaseStorageProblems(config: Record<string, unknown>): string[] {
  const problems: string[] = [];
  const url = String(config.SUPABASE_URL ?? '').trim();
  const key = String(config.SUPABASE_SECRET_KEY ?? '').trim();

  if (!url) {
    problems.push('SUPABASE_URL must be set when MEDIA_DRIVER=supabase.');
  } else if (!/^https:\/\/[^/]+$/i.test(url.replace(/\/+$/, ''))) {
    problems.push(
      `SUPABASE_URL must be the project's https:// origin, e.g. https://<ref>.supabase.co (got "${url}").`,
    );
  }

  if (!key) {
    problems.push('SUPABASE_SECRET_KEY must be set when MEDIA_DRIVER=supabase.');
  } else if (key.startsWith('sb_publishable_') || jwtRole(key) === 'anon') {
    problems.push(
      'SUPABASE_SECRET_KEY holds the publishable (anon) key; Storage needs the secret key.',
    );
  }
  return problems;
}

/** The `role` claim of a legacy Supabase API key, or null for anything else. */
function jwtRole(value: string): string | null {
  const parts = value.split('.');
  if (parts.length !== 3) return null;
  try {
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    return typeof payload.role === 'string' ? payload.role : null;
  } catch {
    return null;
  }
}

/**
 * A Supabase-hosted `DATABASE_URL` has two ways to look right and fail later.
 *
 *  - The transaction pooler (port 6543) hands each transaction to whichever
 *    server connection is free, so Prisma's named prepared statements collide
 *    ("prepared statement \"s0\" already exists") on the second request, not
 *    the first. `pgbouncer=true` tells Prisma not to prepare them.
 *  - Without TLS the database password crosses the internet in the clear.
 *    Supabase refuses plaintext anyway; saying so here beats a timeout.
 */
function supabaseDatabaseUrlProblems(databaseUrl: string): string[] {
  let url: URL;
  try {
    url = new URL(databaseUrl);
  } catch {
    return [];
  }
  const host = url.hostname.toLowerCase();
  if (!host.endsWith('.supabase.co') && !host.endsWith('.supabase.com')) {
    return [];
  }

  const problems: string[] = [];
  if (url.port === '6543' && url.searchParams.get('pgbouncer') !== 'true') {
    problems.push(
      'DATABASE_URL uses the Supabase transaction pooler (port 6543) without pgbouncer=true; Prisma prepared statements would collide.',
    );
  }
  // Prisma's engine knows disable | prefer | require; verification is `sslaccept=strict`.
  const sslmode = url.searchParams.get('sslmode');
  if (sslmode !== 'require') {
    problems.push(
      'DATABASE_URL points at Supabase without sslmode=require; add sslmode=require&sslcert=./certs/supabase-root-2021.crt&sslaccept=strict.',
    );
  }
  return problems;
}

/** A transport that reaches a handset, as each transport's `isConfigured` defines it. */
function hasRealOtpTransport(config: Record<string, unknown>): boolean {
  const set = (key: string) => String(config[key] ?? '').trim().length > 0;
  return (
    (set('SMS_GATEWAY_URL') && set('SMS_GATEWAY_KEY')) ||
    (set('WHATSAPP_PHONE_NUMBER_ID') && set('WHATSAPP_ACCESS_TOKEN')) ||
    (set('VOICE_OTP_URL') && set('VOICE_OTP_KEY'))
  );
}
