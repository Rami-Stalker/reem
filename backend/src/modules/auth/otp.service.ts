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
  OtpDeliveryMode,
  OtpOutboxStatus,
  OtpPurpose,
  OtpStatus,
  ReverseCeremony,
} from '@prisma/client';
import {
  createHash,
  createHmac,
  randomBytes,
  randomInt,
  timingSafeEqual,
} from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { RequestContext } from './interfaces/request-context.interface';
import { OtpDispatcherService, OTP_ENQUEUED } from './otp/otp-dispatcher.service';
import {
  OtpTestAccounts,
  parseOtpTestAccounts,
  testAccountsActive,
} from './otp/otp-test-accounts';
import { maskDestination } from './otp/otp-transport';
import {
  ReverseChallenge,
  ReverseSmsService,
} from './otp/syrotp/reverse-sms.service';

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
 *
 * There are now two directions a challenge can face, and reverse SMS is tried
 * first wherever it is configured (`otp/syrotp/`). On that rail the platform
 * mints nothing deliverable: she sends a code from her own handset to a
 * receiver the deployment owns, and the provider's sender check is the proof.
 * It exists because the outbound leg is the part that fails in this market —
 * an aggregator answers "accepted" and nothing arrives — and because a code
 * travelling away from her phone cannot be talked out of her. The classic
 * chain stays wired underneath: if the reverse provider cannot be reached,
 * `request` falls through to it rather than failing her sign-in.
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
    /**
     * Optional for the same reason `events` is: several specs construct this
     * service directly with the three collaborators they care about. Absent,
     * every challenge takes the classic rail — which is also what a deployment
     * with `SYROTP_ENABLED` unset gets.
     */
    @Optional() private readonly reverse?: ReverseSmsService,
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

    // Reverse SMS first. Not for a named test account: a fixed code exists
    // precisely so a tester can sign in with no provider in the loop, and
    // routing her through a ceremony that needs one would defeat it.
    if (!fixedCode && this.reverse?.isPrimary()) {
      const challenge = await this.reverse.start({
        phone: input.phone,
        purpose: input.purpose,
      });
      if (challenge) {
        return this.openReverseChallenge(input, user?.id, challenge);
      }

      // The provider could not be reached. Where this rail is the only one,
      // that is an outage to surface, not a cue to mint a code on a rail the
      // deployment has decided not to rely on: a sign-in that quietly takes
      // the old path is an outage nobody sees and nobody fixes.
      if (this.reverse.isExclusive()) {
        this.logger.error(
          'Reverse SMS is unavailable and is the only configured rail; ' +
            'refusing the challenge rather than falling back',
        );
        throw new HttpException(
          {
            code: 'OTP_UNAVAILABLE',
            message: 'خدمة التحقق غير متاحة حالياً. حاولي بعد قليل.',
          },
          HttpStatus.SERVICE_UNAVAILABLE,
        );
      }

      this.logger.warn(
        'Reverse SMS unavailable; falling back to the transport chain',
      );
    }

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
      delivery_mode: 'code_to_handset' as const,
      match_code: matchCode,
      masked_destination: maskDestination(input.phone),
      expires_at: expiresAt.toISOString(),
      resend_after: new Date(Date.now() + 60_000).toISOString(),
      channel: (input.channel ?? OtpChannel.WHATSAPP).toLowerCase(),
    };
  }

  /**
   * Records a challenge she settles by sending a message, not by typing one.
   *
   * Three details carry the security of this row:
   *
   *  - `codeHash` is a digest of 256 random bits that are discarded on the
   *    next line. No code exists that can satisfy it, so the code-entry path
   *    cannot settle a reverse row even if a caller reaches it with a lucky
   *    guess; the only thing that can is the provider's own answer.
   *  - `reverseRef` is unique in the database, so one provider ceremony can
   *    never be pointed at a second challenge.
   *  - the expiry is the provider's, not ours. It owns the ceremony's clock,
   *    and a row that outlived the ceremony would accept a `pending` answer
   *    forever.
   *
   * No `matchCode`: it is answered by the direction of travel here, and
   * printing two digits that appear in no message would only puzzle her.
   */
  private async openReverseChallenge(
    input: RequestOtpInput,
    userId: string | undefined,
    challenge: ReverseChallenge,
  ) {
    const request = await this.prisma.otpRequest.create({
      data: {
        userId: input.userId ?? userId,
        destination: input.phone,
        channel: OtpChannel.SMS,
        purpose: input.purpose,
        codeHash: this.digest(randomBytes(32).toString('hex')),
        deliveryMode: OtpDeliveryMode.REVERSE_SMS,
        reverseCeremony: challenge.ceremony,
        reverseRef: challenge.ref,
        reverseSendTo: challenge.sendTo,
        clientNonceHash: input.clientNonce
          ? createHash('sha256').update(input.clientNonce).digest('hex')
          : null,
        expiresAt: challenge.expiresAt,
        ipAddress: input.context?.ipAddress,
        userAgent: input.context?.userAgent,
      },
    });

    return {
      otp_request_id: request.id,
      delivery_mode: 'reverse_sms' as const,
      /** `binding` the first time this number is seen, `verification` after. */
      ceremony: challenge.ceremony.toLowerCase(),
      /** The receiver number she addresses the message to. */
      send_to: challenge.sendTo,
      /** The exact body. Matching is trimmed and case-insensitive. */
      sms_body: challenge.smsBody,
      match_code: null,
      masked_destination: maskDestination(input.phone),
      expires_at: challenge.expiresAt.toISOString(),
      resend_after: new Date(Date.now() + 60_000).toISOString(),
      channel: OtpChannel.SMS.toLowerCase(),
    };
  }

  /**
   * Where a reverse challenge stands, without spending an attempt.
   *
   * The client polls this while she is in her messaging app, so it must be
   * cheap and must not be able to lock her out: a wrong nonce answers
   * `pending` rather than counting against `maxAttempts`, because unlike
   * `verify` this is not a guess at a secret and there is nothing here to
   * brute-force.
   */
  async reverseStatus(
    phone: string,
    purpose: OtpPurpose,
    clientNonce?: string,
  ): Promise<{ status: 'pending' | 'verified' | 'expired' }> {
    const request = await this.pendingReverseChallenge(phone, purpose);
    if (!request) return { status: 'expired' };
    if (request.expiresAt < new Date()) return { status: 'expired' };
    if (!this.nonceMatches(request.clientNonceHash, clientNonce)) {
      return { status: 'pending' };
    }

    const status = await this.reverse?.status(
      request.reverseCeremony as ReverseCeremony,
      request.reverseRef as string,
    );
    if (status === 'verified') return { status: 'verified' };
    return { status: status === 'unusable' ? 'expired' : 'pending' };
  }

  /**
   * Settles a reverse challenge and consumes it, with no side effect of its
   * own — the counterpart of `consume` for a rail that has no code to take.
   */
  async consumeReverse(
    phone: string,
    purpose: OtpPurpose,
    clientNonce?: string,
  ) {
    const request = await this.pendingReverseChallenge(phone, purpose);
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

    // Same ordering as `verify`, and counted the same way: a caller that
    // cannot produce the nonce is not the app instance that asked, whatever
    // ceremony the provider has marked verified.
    if (!this.nonceMatches(request.clientNonceHash, clientNonce)) {
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

    const status = await this.reverse?.status(
      request.reverseCeremony as ReverseCeremony,
      request.reverseRef as string,
    );

    if (status !== 'verified') {
      if (status === 'unusable') {
        await this.prisma.otpRequest.update({
          where: { id: request.id },
          data: { status: OtpStatus.EXPIRED },
        });
        throw new BadRequestException({
          code: 'OTP_EXPIRED',
          message: 'OTP expired',
        });
      }
      // She has not sent the message yet, or it has not been forwarded. This
      // is the ordinary state of a ceremony in flight and is not an attempt at
      // anything, so it does not count against her.
      throw new BadRequestException({
        code: 'OTP_PENDING',
        message: 'Waiting for your message',
      });
    }

    // Claimed exactly once. `updateMany` with the status in the filter makes
    // the claim the condition of the write, so two requests racing on one
    // verified ceremony cannot both come away with a session.
    const claimed = await this.prisma.otpRequest.updateMany({
      where: { id: request.id, status: OtpStatus.PENDING },
      data: { status: OtpStatus.VERIFIED, verifiedAt: now },
    });
    if (claimed.count === 0) {
      throw new BadRequestException({
        code: 'INVALID_OTP',
        message: 'Invalid OTP',
      });
    }

    return { verified: true };
  }

  /**
   * Consumes whichever challenge is outstanding for this number.
   *
   * A flow that asks for a challenge and consumes it later cannot know which
   * rail it got: `request` picks reverse where it is configured and falls
   * through to the chain where it is not, and a fallback can happen between
   * the two calls. Rather than make every such flow branch, they ask for the
   * challenge to be consumed and this decides — from the row, which is the
   * only thing that actually knows.
   */
  async consumeAny(
    phone: string,
    purpose: OtpPurpose,
    code?: string,
    clientNonce?: string,
  ) {
    const reverse = await this.pendingReverseChallenge(phone, purpose);
    if (reverse) return this.consumeReverse(phone, purpose, clientNonce);

    // No reverse row and no code is simply a caller with nothing to present.
    if (!code) {
      throw new BadRequestException({
        code: 'INVALID_OTP',
        message: 'Invalid OTP',
      });
    }
    return this.consume(phone, purpose, code, clientNonce);
  }

  /**
   * `verify` on whichever rail is outstanding — the counterpart of
   * `consumeAny` for the flows whose purpose carries a side effect.
   */
  async verifyAny(
    phone: string,
    purpose: OtpPurpose,
    code?: string,
    clientNonce?: string,
  ) {
    const reverse = await this.pendingReverseChallenge(phone, purpose);
    if (reverse) {
      const result = await this.consumeReverse(phone, purpose, clientNonce);
      await this.applyPurposeSideEffect(phone, purpose, new Date());
      return result;
    }

    if (!code) {
      throw new BadRequestException({
        code: 'INVALID_OTP',
        message: 'Invalid OTP',
      });
    }
    return this.verify(phone, purpose, code, clientNonce);
  }

  /** The newest pending reverse challenge for a number, if there is one. */
  private pendingReverseChallenge(phone: string, purpose: OtpPurpose) {
    return this.prisma.otpRequest.findFirst({
      where: {
        destination: phone,
        purpose,
        status: OtpStatus.PENDING,
        deliveryMode: OtpDeliveryMode.REVERSE_SMS,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  private nonceMatches(stored: string | null, presented?: string): boolean {
    if (!stored) return true;
    return (
      stored ===
      createHash('sha256')
        .update(presented ?? '')
        .digest('hex')
    );
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
        // A reverse challenge is settled by `consumeReverse`, never here. Its
        // `codeHash` is a digest of bits nobody holds, so this path could not
        // match it anyway — but excluding the row means a pending reverse
        // ceremony does not shadow a classic challenge she asked for after a
        // fallback, which would otherwise read as "invalid code" for a code
        // that was perfectly good.
        deliveryMode: OtpDeliveryMode.CODE_TO_HANDSET,
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

    await this.applyPurposeSideEffect(phone, purpose, now);

    return { verified: true };
  }

  /**
   * What verifying a challenge *means* for the account, as opposed to for the
   * challenge.
   *
   * Extracted because the reverse rail has to apply the identical effect, and
   * two copies of "and also stamp the number verified" is how the copies drift.
   */
  private async applyPurposeSideEffect(
    phone: string,
    purpose: OtpPurpose,
    at: Date,
  ): Promise<void> {
    if (purpose !== OtpPurpose.PHONE_VERIFICATION) return;
    await this.prisma.user.updateMany({
      where: { phone },
      // The number only: `isVerified` is the public badge, granted by
      // `AccountVerificationService`, never by receiving a code.
      data: { phoneVerifiedAt: at },
    });
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
