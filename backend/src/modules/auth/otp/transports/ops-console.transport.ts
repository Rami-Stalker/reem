import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OtpTransportKind } from '@prisma/client';
import { OtpDispatch, OtpSendOutcome, OtpTransport } from '../otp-transport';

/**
 * A schedule hedge, not a channel.
 *
 * The closed beta must be able to start before a carrier contract lands. This
 * "transport" sends nothing: it marks the challenge as reachable through the
 * admin console, where a team member reads the code to a hand-picked tester
 * over the phone.
 *
 * It is a deliberate, bounded compromise and every property of it says so:
 * - it must be switched on explicitly via `AUTH_OPS_TRANSPORT_ENABLED`, and
 *   the environment validator refuses that flag when `NODE_ENV=production`;
 * - it exposes plaintext codes to staff, so every reveal writes a CRITICAL
 *   security event naming the admin who looked;
 * - it does not scale past a few dozen users and is not a product feature.
 *
 * It exists because the alternative — a beta that cannot start, or a beta
 * started by putting codes back in API responses — is worse.
 */
@Injectable()
export class OpsConsoleTransport implements OtpTransport {
  readonly kind = OtpTransportKind.OPS_CONSOLE;

  private readonly logger = new Logger(OpsConsoleTransport.name);
  private readonly enabled: boolean;

  constructor(config: ConfigService) {
    this.enabled =
      config.get<boolean>('otpDelivery.opsConsoleEnabled') === true &&
      config.get<string>('nodeEnv') !== 'production';
  }

  isConfigured(): boolean {
    return this.enabled;
  }

  reportsReceipts(): boolean {
    return false;
  }

  send(dispatch: OtpDispatch): Promise<OtpSendOutcome> {
    if (!this.enabled) {
      return Promise.resolve({
        status: 'unavailable',
        reason: 'Ops-console transport is disabled',
      });
    }

    this.logger.warn(
      `Challenge for ${dispatch.phone} is awaiting manual read-out in the ops console`,
    );

    // Accepted, terminal, free — the "delivery" is a human, and the code is
    // read from the pending-challenges endpoint rather than pushed anywhere.
    return Promise.resolve({
      status: 'accepted',
      costMicros: 0,
      terminal: true,
      // The code stays sealed-but-readable until she uses it or it expires:
      // the "delivery" has not happened until a human reads it out.
      retainCode: true,
      metadata: { manual: true },
    });
  }
}
