import { Injectable, Logger } from '@nestjs/common';
import { DeviceKey } from '@prisma/client';
import { createHash } from 'crypto';
import { PrismaService } from '../../../prisma/prisma.service';
import {
  parseCompactJws,
  safeEqual,
  verifyEd25519,
} from '../../../common/crypto/ed25519';

/** How far a proof's `iat` may drift from server time, in seconds. */
const CLOCK_SKEW_SECONDS = 60;

export type ProofFailure =
  | 'malformed'
  | 'unknown_key'
  | 'revoked_key'
  | 'bad_signature'
  | 'stale'
  | 'wrong_request'
  | 'wrong_token'
  | 'replayed';

export type ProofResult =
  | { ok: true; deviceKey: DeviceKey }
  | { ok: false; reason: ProofFailure };

export interface ProofContext {
  /** HTTP method of the request being proven. */
  method: string;
  /** Absolute URL of the request being proven. */
  url: string;
  /** The access token presented alongside, if any. */
  accessToken?: string;
}

/**
 * Verifies that the caller holds the private key of a registered device.
 *
 * The proof is a compact JWS over `{jti, iat, htm, htu, ath}`, and each claim
 * closes a specific hole:
 *
 * - `htm`/`htu` bind it to *this* method and URL, so a proof captured on a
 *   harmless endpoint cannot be replayed against the payout endpoint;
 * - `ath` binds it to the access token presented with it, so a stolen proof is
 *   useless without the matching token and vice versa;
 * - `iat` bounds the window to ±60 seconds;
 * - `jti` closes that window entirely, because the unique insert means the
 *   second use of a proof loses.
 */
@Injectable()
export class DeviceProofService {
  private readonly logger = new Logger(DeviceProofService.name);

  constructor(private readonly prisma: PrismaService) {}

  async verify(proof: string, context: ProofContext): Promise<ProofResult> {
    const parsed = parseCompactJws(proof);
    if (!parsed) return { ok: false, reason: 'malformed' };

    const { header, payload, signingInput, signature } = parsed;
    const kid = typeof header.kid === 'string' ? header.kid : null;
    const jti = typeof payload.jti === 'string' ? payload.jti : null;
    const iat = typeof payload.iat === 'number' ? payload.iat : null;
    if (!kid || !jti || iat === null) return { ok: false, reason: 'malformed' };

    const deviceKey = await this.prisma.deviceKey.findUnique({
      where: { id: kid },
    });
    if (!deviceKey) return { ok: false, reason: 'unknown_key' };
    if (deviceKey.revokedAt) return { ok: false, reason: 'revoked_key' };

    // Signature first: everything below trusts the claims, so nothing below
    // may run until we know the claims came from the key.
    if (!verifyEd25519(signingInput, signature, deviceKey.publicKey)) {
      return { ok: false, reason: 'bad_signature' };
    }

    const now = Math.floor(Date.now() / 1000);
    if (Math.abs(now - iat) > CLOCK_SKEW_SECONDS) {
      return { ok: false, reason: 'stale' };
    }

    if (
      payload.htm !== context.method.toUpperCase() ||
      typeof payload.htu !== 'string' ||
      !this.sameUrl(payload.htu, context.url)
    ) {
      return { ok: false, reason: 'wrong_request' };
    }

    if (context.accessToken) {
      const expected = createHash('sha256')
        .update(context.accessToken)
        .digest('base64url');
      if (typeof payload.ath !== 'string' || !safeEqual(payload.ath, expected)) {
        return { ok: false, reason: 'wrong_token' };
      }
    }

    // The unique constraint is the replay check. Catching the conflict is the
    // check — a "does it exist" query first would race two concurrent replays.
    try {
      await this.prisma.deviceProofJti.create({
        data: {
          deviceKeyId: deviceKey.id,
          jti,
          expiresAt: new Date((iat + CLOCK_SKEW_SECONDS * 2) * 1000),
        },
      });
    } catch {
      return { ok: false, reason: 'replayed' };
    }

    await this.prisma.deviceKey.update({
      where: { id: deviceKey.id },
      data: { lastSeenAt: new Date() },
    });

    return { ok: true, deviceKey };
  }

  /** Compares origin + path, ignoring query and trailing-slash noise. */
  private sameUrl(claimed: string, actual: string): boolean {
    try {
      const a = new URL(claimed);
      const b = new URL(actual);
      return (
        a.origin === b.origin &&
        a.pathname.replace(/\/$/, '') === b.pathname.replace(/\/$/, '')
      );
    } catch {
      return false;
    }
  }
}
