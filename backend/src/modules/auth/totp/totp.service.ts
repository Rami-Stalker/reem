import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { RiskLevel, SecurityEventType, UserRole } from '@prisma/client';
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  createHmac,
  randomBytes,
  timingSafeEqual,
} from 'crypto';
import { PrismaService } from '../../../prisma/prisma.service';

/** RFC 6238 defaults. */
const PERIOD_SECONDS = 30;
const DIGITS = 6;
/** ±1 step, so a code entered as it rolls over still works. */
const WINDOW = 1;

const BASE32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/** The roles that must carry an authenticator. */
export const PRIVILEGED_ROLES: UserRole[] = [
  UserRole.SUPER_ADMIN,
  UserRole.OPERATIONS_ADMIN,
  UserRole.SUPPORT_ADMIN,
  UserRole.FINANCE_ADMIN,
  UserRole.CONTENT_MODERATOR,
  UserRole.ADMIN,
  UserRole.SUPPORT,
];

/**
 * Time-based one-time passwords.
 *
 * Implemented directly rather than pulled in, because it is forty lines of
 * HMAC and the alternative is another dependency in an auth path — and because
 * the interesting parts are the two things libraries leave to the caller: the
 * replay guard, and where the secret lives.
 *
 * Unlike every other factor in this system, TOTP has no network anywhere in
 * its path. That is the whole argument for making it mandatory on privileged
 * accounts: a total messaging outage in Syria must not also be an outage of
 * the people who would fix it.
 */
@Injectable()
export class TotpService {
  private readonly key: Buffer;
  private readonly issuer = 'Ohara';

  constructor(
    private readonly prisma: PrismaService,
    config: ConfigService,
  ) {
    const secret = config.get<string>('security.totpEncKey') as string;
    this.key = createHash('sha256').update(secret).digest();
  }

  /**
   * Starts enrolment and returns the provisioning URI once.
   *
   * The credential is stored unconfirmed: a secret nobody has proved they can
   * compute from is worse than none, because it would let an account claim MFA
   * it cannot actually perform.
   */
  async enroll(userId: string, accountLabel: string) {
    const existing = await this.prisma.totpCredential.findUnique({
      where: { userId },
    });
    if (existing?.confirmedAt) {
      throw new ConflictException({
        code: 'TOTP_ALREADY_ENROLLED',
        message: 'An authenticator is already set up for this account',
      });
    }

    const secret = this.generateSecret();
    await this.prisma.totpCredential.upsert({
      where: { userId },
      create: { userId, secretEnc: this.seal(secret) },
      update: { secretEnc: this.seal(secret), confirmedAt: null, lastUsedCounter: null },
    });

    const label = encodeURIComponent(`${this.issuer}:${accountLabel}`);
    return {
      secret,
      otpauth_uri:
        `otpauth://totp/${label}?secret=${secret}&issuer=${this.issuer}` +
        `&algorithm=SHA1&digits=${DIGITS}&period=${PERIOD_SECONDS}`,
      digits: DIGITS,
      period_seconds: PERIOD_SECONDS,
    };
  }

  /** Confirms enrolment by proving the authenticator produces the right code. */
  async confirm(userId: string, code: string) {
    const credential = await this.prisma.totpCredential.findUnique({
      where: { userId },
    });
    if (!credential) {
      throw new NotFoundException({
        code: 'TOTP_NOT_ENROLLED',
        message: 'Start authenticator setup first',
      });
    }

    const counter = this.match(this.open(credential.secretEnc), code, null);
    if (counter === null) {
      throw new BadRequestException({
        code: 'INVALID_TOTP',
        message: 'That code is not right',
      });
    }

    await this.prisma.totpCredential.update({
      where: { userId },
      data: { confirmedAt: new Date(), lastUsedCounter: BigInt(counter) },
    });
    await this.prisma.user.update({
      where: { id: userId },
      data: { mfaEnabled: true },
    });
    await this.prisma.securityEvent.create({
      data: {
        actorId: userId,
        type: SecurityEventType.DEVICE_TRUSTED,
        riskLevel: RiskLevel.LOW,
        resource: 'totp',
        metadata: { action: 'totp_confirmed' },
      },
    });

    return { confirmed: true };
  }

  /** True when `code` is valid now and has not already been spent. */
  async verify(userId: string, code: string): Promise<boolean> {
    const credential = await this.prisma.totpCredential.findUnique({
      where: { userId },
    });
    if (!credential?.confirmedAt) return false;

    const counter = this.match(
      this.open(credential.secretEnc),
      code,
      credential.lastUsedCounter,
    );
    if (counter === null) return false;

    await this.prisma.totpCredential.update({
      where: { userId },
      data: { lastUsedCounter: BigInt(counter) },
    });
    return true;
  }

  async isConfirmed(userId: string): Promise<boolean> {
    const credential = await this.prisma.totpCredential.findUnique({
      where: { userId },
      select: { confirmedAt: true },
    });
    return credential?.confirmedAt != null;
  }

  /**
   * Compares `code` against every step in the window and returns the step it
   * matched, or null. Steps at or below `lastUsedCounter` are refused — that
   * is the replay guard.
   */
  private match(
    secret: string,
    code: string,
    lastUsedCounter: bigint | null,
  ): number | null {
    const normalized = code.replace(/\s+/g, '');
    if (!/^\d{6}$/.test(normalized)) return null;

    const current = Math.floor(Date.now() / 1000 / PERIOD_SECONDS);
    for (let offset = -WINDOW; offset <= WINDOW; offset += 1) {
      const counter = current + offset;
      if (lastUsedCounter !== null && BigInt(counter) <= lastUsedCounter) {
        continue;
      }
      const expected = this.codeFor(secret, counter);
      const a = Buffer.from(expected);
      const b = Buffer.from(normalized);
      if (a.length === b.length && timingSafeEqual(a, b)) return counter;
    }
    return null;
  }

  /** The RFC 6238 / RFC 4226 truncation. */
  codeFor(secret: string, counter: number): string {
    const buffer = Buffer.alloc(8);
    buffer.writeBigUInt64BE(BigInt(counter));
    const digest = createHmac('sha1', this.base32Decode(secret))
      .update(buffer)
      .digest();
    const offset = digest[digest.length - 1] & 0x0f;
    const binary =
      ((digest[offset] & 0x7f) << 24) |
      ((digest[offset + 1] & 0xff) << 16) |
      ((digest[offset + 2] & 0xff) << 8) |
      (digest[offset + 3] & 0xff);
    return String(binary % 10 ** DIGITS).padStart(DIGITS, '0');
  }

  /** 160 bits, the RFC's recommendation for SHA-1. */
  private generateSecret(): string {
    return this.base32Encode(randomBytes(20));
  }

  private seal(secret: string): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    const sealed = Buffer.concat([cipher.update(secret, 'utf8'), cipher.final()]);
    return [
      iv.toString('base64url'),
      sealed.toString('base64url'),
      cipher.getAuthTag().toString('base64url'),
    ].join('.');
  }

  private open(sealed: string): string {
    const [iv, body, tag] = sealed.split('.');
    const decipher = createDecipheriv(
      'aes-256-gcm',
      this.key,
      Buffer.from(iv, 'base64url'),
    );
    decipher.setAuthTag(Buffer.from(tag, 'base64url'));
    return Buffer.concat([
      decipher.update(Buffer.from(body, 'base64url')),
      decipher.final(),
    ]).toString('utf8');
  }

  base32Encode(buffer: Buffer): string {
    let bits = 0;
    let value = 0;
    let output = '';
    for (const byte of buffer) {
      value = (value << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        output += BASE32_ALPHABET[(value >>> (bits - 5)) & 31];
        bits -= 5;
      }
    }
    if (bits > 0) output += BASE32_ALPHABET[(value << (5 - bits)) & 31];
    return output;
  }

  base32Decode(input: string): Buffer {
    let bits = 0;
    let value = 0;
    const output: number[] = [];
    for (const character of input.replace(/=+$/, '').toUpperCase()) {
      const index = BASE32_ALPHABET.indexOf(character);
      if (index === -1) throw new Error('Invalid base32 in TOTP secret');
      value = (value << 5) | index;
      bits += 5;
      if (bits >= 8) {
        output.push((value >>> (bits - 8)) & 0xff);
        bits -= 8;
      }
    }
    return Buffer.from(output);
  }
}
