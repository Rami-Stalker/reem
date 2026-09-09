import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DeliveryProviderAccount } from '@prisma/client';

/**
 * A carrier's secrets, fetched from the environment by name.
 *
 * The database says *which* variable holds a credential; the value only ever
 * exists in the process. That split is the whole point: a database dump, a
 * replica, a support query or an admin screen can carry a carrier's whole
 * configuration and still carry no key — and rotating one is a deployment
 * secret change, not a write to a table somebody could read.
 *
 * The Flutter app is never in this path at all. It has no carrier credential,
 * no carrier base URL and no way to call one: it reads status and a tracking
 * number off Reem's own API.
 */
export interface ProviderCredentials {
  apiKey?: string;
  apiSecret?: string;
  webhookSecret?: string;
  /** Anything else the adapter's config asks for by name. */
  extra: Record<string, string>;
}

@Injectable()
export class ProviderCredentialsService {
  private readonly logger = new Logger(ProviderCredentialsService.name);

  constructor(private readonly config: ConfigService) {}

  /**
   * Reads the variables this account names.
   *
   * A missing variable is not an exception here — the caller decides whether
   * it can proceed (a carrier without a webhook secret can still be dispatched
   * to; one without an API key cannot). Names, never values, reach the log.
   */
  resolve(account: DeliveryProviderAccount): ProviderCredentials {
    const map = (account.credentialEnvKeys ?? {}) as Record<string, unknown>;
    const extra: Record<string, string> = {};
    const missing: string[] = [];

    for (const [field, envKey] of Object.entries(map)) {
      if (typeof envKey !== 'string' || envKey.length === 0) continue;
      const value = process.env[envKey] ?? this.config.get<string>(envKey);
      if (!value) {
        missing.push(envKey);
        continue;
      }
      extra[field] = value;
    }

    if (missing.length > 0) {
      this.logger.warn(
        `Carrier ${account.code} names ${missing.length} credential variable(s) that are not set: ${missing.join(', ')}`,
      );
    }

    return {
      apiKey: extra.apiKey,
      apiSecret: extra.apiSecret,
      webhookSecret: extra.webhookSecret,
      extra,
    };
  }
}
