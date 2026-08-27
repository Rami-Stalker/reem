import { plainToInstance } from 'class-transformer';
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
  @IsIn(['local'])
  MEDIA_DRIVER?: string;

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
  if (config.NODE_ENV === 'production' && !config.MEDIA_PUBLIC_ORIGIN) {
    throw new Error(
      [
        'Invalid environment configuration:',
        '  - MEDIA_PUBLIC_ORIGIN must be set in production; without it media',
        '    URLs are built from the origin each request happened to arrive on.',
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
