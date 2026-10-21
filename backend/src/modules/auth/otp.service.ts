import {
  BadRequestException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  Optional,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EventEmitter2 } from '@nestjs/event-emitter';
import {
  OtpChannel,
  OtpOutboxStatus,
  OtpPurpose,
  OtpStatus,
} from '@prisma/client';
import { createHash, createHmac, randomInt, timingSafeEqual } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { RequestContext } from './interfaces/request-context.interface';
import { OtpDispatcherService, OTP_ENQUEUED } from './otp/otp-dispatcher.service';
import {
  OtpTestAccounts,
  parseOtpTestAccounts,
  testAccountsActive,
} from './otp/otp-test-accounts';
import { maskDestination } from './otp/otp-transport';

interface RequestOtpInput {
  phone: string;
  purpose: OtpPurpose;
  channel?: OtpChannel;
  userId?: string;
  /** Binds the challenge to the app instance that asked for it. */
  clientNonce?: string;
  context?: RequestContext;
}

/**
 * One-time codes.
 *
 * Three things changed here and each of them was a live hole:
 *
 * 1. Codes came from `Math.random()`, a non-cryptographic PRNG whose internal
 *    state is recoverable from a handful of outputs. Anyone who could request
 *    a few codes for their own number could predict the next one issued for
 *    somebody else's. They now come from `crypto.randomInt`.
 *
 * 2. The plaintext code was returned to the caller as `debug_code` whenever
 *    `NODE_ENV !== 'production'` — the effective default. Combined with the
 *    public forgot-password route that is a complete account-takeover chain:
 *    request a code for any number, read it out of the response, reset the
 *    password. The field is gone from the response shape entirely; a code can
 *    now only reach a log, only behind an explicit `OTP_DEV_ECHO` opt-in that
 *    the environment validator refuses to accept in production.
 *
 * 3. Codes were hashed with argon2id, a password KDF. A six-digit secret has
 *    a million-element keyspace, so the KDF buys nothing an attacker who has
 *    the database cannot brute-force in seconds anyway — while costing 64 MiB
 *    of memory per verification on the hot path of every login. A peppered
 *    HMAC is the right primitive: the pepper lives outside the database, so a
 *    dump alone does not reveal codes, and verification is constant time.
 *
 * Delivery is handled by `otp/` — an outbox drained by cron through a priority
 * chain of transports. This service's job ends at writing the challenge and
 * queuing it; it never talks to a provider, so a provider outage delays a
 * message instead of failing the request she made.
 */
@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly ttlMs = 10 * 60_000;
  private readonly maxPerMinute = 1;
  private readonly maxPerHour = 5;
  private readonly pepper: string;
  private readonly devEcho: boolean;
  private readonly testAccounts: OtpTestAccounts;

  constructor(
    private readonly prisma: PrismaService,
    private readonly dispatcher: OtpDispatcherService,
    config: ConfigService,
    @Optional() private readonly events?: EventEmitter2,
  ) {
    this.pepper = config.get<string>('security.otpPepper') as string;
    this.devEcho = config.get<boolean>('security.otpDevEcho') === true;
    this.testAccounts = parseOtpTestAccounts(
      config.get<string>('otpDelivery.testAccounts'),
      config.get<string>('otpDelivery.testAccountsUntil'),
    );
  }

  async request(input: RequestOtpInput) {
    await this.assertRateLimit(input.phone, input.purpose);

    const matchCode = OtpDispatcherService.generateMatchCode();
    const expiresAt = new Date(Date.now() + this.ttlMs);
    const user =
      input.userId || !input.phone
        ? null
        : await this.prisma.user.findUnique({ where: { phone: input.phone } });
    const fixedCode = this.fixedTestCode(input, Boolean(input.userId ?? user?.id));
    const code = fixedCode ?? this.generateCode();

    // The challenge and its outbox row are written together: a code that
    // exists but was never queued is an account nobody can get into, and that
    // is precisely the state the platform was in before the outbox existed.
    const request = await this.prisma.$transaction(async (tx) => {
      const created = await tx.otpRequest.create({
        data: {
          userId: input.userId ?? user?.id,
          destination: input.phone,
          // Q47/Q48 P1 — the requested channel is a hint; the transport chain
          // in `otp_transport_routes` decides what actually carries it.
          channel: input.channel ?? OtpChannel.WHATSAPP,
          purpose: input.purpose,
          codeHash: this.digest(code),
          matchCode,
          clientNonceHash: input.clientNonce
            ? createHash('sha256').update(input.clientNonce).digest('hex')
            : null,
          expiresAt,
          ipAddress: input.context?.ipAddress,
          userAgent: input.context?.userAgent,
        },
      });
      // A fixed test code has nobody to be sent to: it is never queued.
      if (!fixedCode) await this.dispatcher.enqueue(created.id, code, tx);
      return created;
    });

    if (fixedCode) {
      this.logger.warn(
        `Fixed test code issued for ${maskDestination(input.phone)}; nothing sent`,
      );
    } else {
      // Delivered now, not at the outbox's next poll: the row is committed, so
      // the drain can claim it. The poll stays as the net for a send this
      // misses (a crash between commit and here, a transport to retry).
      this.events?.emit(OTP_ENQUEUED, { challengeId: request.id });
    }

    if (this.devEcho) {
      this.logger.warn(
        `[dev-echo] ${input.purpose} code for ${input.phone}: ${code} (match ${matchCode})`,
      );
    }

    // Deliberately no code in the response, in any environment. `match_code`
    // is safe to return and is the point: she compares it to the one in the
    // message, so a code recited to her over the phone does not match.
    return {
      otp_request_id: request.id,
      match_code: matchCode,
      masked_destination: maskDestination(input.phone),
      expires_at: expiresAt.toISOString(),
      resend_after: new Date(Date.now() + 60_000).toISOString(),
      channel: (input.channel ?? OtpChannel.WHATSAPP).toLowerCase(),
    };
  }

  /**
   * Verifies a code and applies the side effect the purpose implies.
   *
   * `clientNonce` closes the second half of the anti-relay defence. The
   * challenge already stores a hash of the nonce the requesting app instance
   * generated; until now nothing ever compared it, so the column was decorative
   * and the relay attack it was written for — attacker requests a code for the
   * victim's number, talks the victim into reading it out, types it into their
   * own app — still worked end to end. Where a challenge carries a nonce, the
   * caller must present the same one.
   */
  async verify(
    phone: string,
    purpose: OtpPurpose,
    code: string,
    clientNonce?: string,
  ) {
    const request = await this.prisma.otpRequest.findFirst({
      where: {
        destination: phone,
        purpose,
        status: OtpStatus.PENDING,
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!request) {
      throw new BadRequestException({
        code: 'INVALID_OTP',
        message: 'Invalid OTP',
      });
    }

    const now = new Date();
    if (request.expiresAt < now) {
      await this.prisma.otpRequest.update({
        where: { id: request.id },
        data: { status: OtpStatus.EXPIRED },
      });
      throw new BadRequestException({
        code: 'OTP_EXPIRED',
        message: 'OTP expired',
      });
    }

    // Checked before the code itself, and counted as an attempt: a caller who
    // cannot produce the nonce is not the app instance that asked, whatever
    // code they are holding.
    if (
      request.clientNonceHash &&
      request.clientNonceHash !==
        createHash('sha256')
          .update(clientNonce ?? '')
          .digest('hex')
    ) {
      await this.prisma.otpRequest.update({
        where: { id: request.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException({
        code: 'INVALID_OTP',
        message: 'Invalid OTP',
      });
    }

    if (request.attempts >= request.maxAttempts) {
      await this.prisma.otpRequest.update({
        where: { id: request.id },
        data: { status: OtpStatus.LOCKED },
      });
      throw new BadRequestException({
        code: 'TOO_MANY_ATTEMPTS',
        message: 'Too many attempts',
      });
    }

    if (!this.matches(code, request.codeHash)) {
      await this.prisma.otpRequest.update({
        where: { id: request.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException({
        code: 'INVALID_OTP',
        message: 'Invalid OTP',
      });
    }

    await this.prisma.otpRequest.update({
      where: { id: request.id },
      data: { status: OtpStatus.VERIFIED, verifiedAt: now },
    });
    // Consumed: the outbox has nothing left to resend, so the plaintext goes.
    await this.dispatcher.shred(request.id, OtpOutboxStatus.DELIVERED);

    if (purpose === OtpPurpose.PHONE_VERIFICATION) {
      // The number, and only the number. This used to set `isVerified` in the
      // same breath, which is how every account that ever received a code came
      // to wear the «موثّقة» badge — see `AccountVerificationService`.
      await this.prisma.user.updateMany({
        where: { phone },
        data: { phoneVerifiedAt: now },
      });
    }

    return { verified: true };
  }

  /**
   * Consumes a code without applying any side effect of its own. Used by flows
   * that need proof of control over a number they are about to attach to an
   * account — a phone change must not mark the *old* number verified, which is
   * what `verify()` would do.
   */
  async consume(
    phone: string,
    purpose: OtpPurpose,
    code: string,
    clientNonce?: string,
  ) {
    const result = await this.verify(phone, purpose, code, clientNonce);
    return result;
  }

  private async assertRateLimit(phone: string, purpose: OtpPurpose) {
    const now = Date.now();
    const [minuteCount, hourCount] = await Promise.all([
      this.prisma.otpRequest.count({
        where: {
          destination: phone,
          purpose,
          createdAt: { gt: new Date(now - 60_000) },
        },
      }),
      this.prisma.otpRequest.count({
        where: {
          destination: phone,
          purpose,
          createdAt: { gt: new Date(now - 60 * 60_000) },
        },
      }),
    ]);

    if (minuteCount >= this.maxPerMinute || hourCount >= this.maxPerHour) {
      throw new HttpException(
        {
          code: 'TOO_MANY_ATTEMPTS',
          message: 'Too many attempts',
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  /**
   * The configured code for a named test account signing in, or null.
   *
   * Only LOGIN, only an account that already exists (a listed number that was
   * never registered gets a real code, and cannot be used to create one), and
   * only inside the dated window. See `otp/otp-test-accounts.ts`.
   */
  private fixedTestCode(input: RequestOtpInput, accountExists: boolean): string | null {
    if (input.purpose !== OtpPurpose.LOGIN || !accountExists) return null;
    if (!testAccountsActive(this.testAccounts)) return null;
    return this.testAccounts.codes.get(input.phone) ?? null;
  }

  /** Uniform over 000000-999999, from the CSPRNG. */
  private generateCode(): string {
    return String(randomInt(0, 1_000_000)).padStart(6, '0');
  }

  private digest(code: string): string {
    return createHmac('sha256', this.pepper).update(code).digest('hex');
  }

  /** Constant time, so verification cannot be turned into an oracle. */
  private matches(code: string, storedHash: string): boolean {
    const expected = Buffer.from(storedHash, 'utf8');
    const actual = Buffer.from(this.digest(code), 'utf8');
    if (expected.length !== actual.length) return false;
    return timingSafeEqual(expected, actual);
  }
}
