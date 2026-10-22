import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  AuditSeverity,
  NotificationType,
  OtpPurpose,
  PhoneChangeStatus,
  Prisma,
  RiskLevel,
  SecurityEventType,
  SessionStatus,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { OtpService } from '../otp.service';
import { maskDestination } from '../otp/otp-transport';
import { RequestContext } from '../interfaces/request-context.interface';
import { AuditService } from '../audit.service';

/** A change has half an hour to complete both halves before it lapses. */
const REQUEST_TTL_MS = 30 * 60_000;

/**
 * Money stands still for a week after the account moves numbers.
 *
 * Not because the change is presumed fraudulent — the overwhelming majority
 * are a woman who genuinely changed SIM. It is because the one thing a
 * successful takeover wants is a payout to an account it controls, and the one
 * thing the real owner will do within days is notice she cannot sign in. Seven
 * days is longer than "notice", shorter than "abandon the platform".
 */
const PAYOUT_FREEZE_MS = 7 * 24 * 60 * 60_000;

/**
 * Moving the account to a different number, proved on both ends.
 *
 * The number IS the identity here: it is the login, the recovery channel and
 * the second factor all at once. So a change to it is not an account edit, it
 * is a transfer of the account — and the previous implementation asked for
 * exactly one proof, on the *incoming* number. Read that as an attacker and it
 * is a gift: possession of the SIM you are moving to is the one thing a SIM
 * swapper trivially has.
 *
 * Two challenges, in order. The outgoing number first, because that is the one
 * an attacker cannot answer, and asking it first means a stolen session is
 * stopped before any code is ever sent to the number they control.
 *
 * A woman whose old SIM is genuinely dead is not stuck here: that is what
 * `AccountRecoveryService` is for, and it is slower on purpose.
 */
@Injectable()
export class PhoneChangeService {
  private readonly logger = new Logger(PhoneChangeService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly otp: OtpService,
    private readonly audit: AuditService,
  ) {}

  /** Sends a code to the number currently on the account. */
  async start(
    userId: string,
    newPhone: string,
    context: RequestContext,
    sessionId?: string,
    deviceKeyId?: string,
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.phone) {
      throw new BadRequestException({
        code: 'NO_CURRENT_PHONE',
        message: 'This account has no number to move',
      });
    }
    if (user.phone === newPhone) {
      throw new BadRequestException({
        code: 'PHONE_UNCHANGED',
        message: 'That is already the number on this account',
      });
    }

    const taken = await this.prisma.user.findUnique({
      where: { phone: newPhone },
    });
    if (taken) {
      throw new ConflictException({
        code: 'PHONE_ALREADY_REGISTERED',
        message: 'Phone number is already registered',
      });
    }

    // One in flight at a time. Two concurrent changes are never a legitimate
    // journey, and are an obvious way to try to get the halves confused.
    await this.prisma.phoneChangeRequest.updateMany({
      where: {
        userId,
        status: {
          in: [
            PhoneChangeStatus.AWAITING_CURRENT,
            PhoneChangeStatus.AWAITING_NEW,
          ],
        },
      },
      data: {
        status: PhoneChangeStatus.CANCELLED,
        cancelledAt: new Date(),
        cancelledReason: 'superseded',
      },
    });

    const challenge = await this.otp.request({
      phone: user.phone,
      purpose: OtpPurpose.PHONE_CHANGE,
      userId,
      context,
    });

    const request = await this.prisma.phoneChangeRequest.create({
      data: {
        userId,
        currentPhone: user.phone,
        newPhone,
        sessionId,
        deviceKeyId,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
        expiresAt: new Date(Date.now() + REQUEST_TTL_MS),
      },
    });

    await this.audit.record({
      actorId: userId,
      action: 'phone_change_started',
      category: 'account',
      outcome: 'success',
      severity: AuditSeverity.WARNING,
      context,
      metadata: { request_id: request.id },
    });

    return this.envelope(request, challenge);
  }

  /** Consumes the code on the outgoing number, then challenges the incoming one. */
  async verifyCurrent(
    userId: string,
    requestId: string,
    code: string | undefined,
    context: RequestContext,
  ) {
    const request = await this.requireLive(
      userId,
      requestId,
      PhoneChangeStatus.AWAITING_CURRENT,
    );

    // `consumeAny`, not `verify`: proving control of the number she is
    // *leaving* must not stamp it verified all over again, and the challenge
    // on it may have been opened on either rail.
    await this.otp.consumeAny(
      request.currentPhone,
      OtpPurpose.PHONE_CHANGE,
      code,
    );

    // Re-checked here as well as at start: half an hour is plenty of time for
    // somebody else to have registered the number in between.
    const taken = await this.prisma.user.findUnique({
      where: { phone: request.newPhone },
    });
    if (taken) {
      await this.cancelInternal(request.id, 'new_phone_taken');
      throw new ConflictException({
        code: 'PHONE_ALREADY_REGISTERED',
        message: 'Phone number is already registered',
      });
    }

    const challenge = await this.otp.request({
      phone: request.newPhone,
      purpose: OtpPurpose.PHONE_VERIFICATION,
      userId,
      context,
    });

    const updated = await this.prisma.phoneChangeRequest.update({
      where: { id: request.id },
      data: {
        status: PhoneChangeStatus.AWAITING_NEW,
        currentVerifiedAt: new Date(),
      },
    });

    return this.envelope(updated, challenge);
  }

  /** Consumes the code on the incoming number and performs the move. */
  async confirm(
    userId: string,
    requestId: string,
    code: string | undefined,
    context: RequestContext,
    keepSessionId?: string,
  ) {
    const request = await this.requireLive(
      userId,
      requestId,
      PhoneChangeStatus.AWAITING_NEW,
    );

    await this.otp.consumeAny(
      request.newPhone,
      OtpPurpose.PHONE_VERIFICATION,
      code,
    );

    const now = new Date();
    const payoutFrozenUntil = new Date(now.getTime() + PAYOUT_FREEZE_MS);

    // One transaction: the account must never be observable half-moved, and a
    // unique violation on the number has to roll the whole thing back rather
    // than leave a COMPLETED request pointing at a change that did not happen.
    const user = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.user.update({
        where: { id: userId },
        data: {
          phone: request.newPhone,
          phoneVerifiedAt: now,
          isVerified: true,
          payoutFrozenUntil,
          payoutFreezeReason: 'phone_change',
        },
      });

      await tx.phoneChangeRequest.update({
        where: { id: request.id },
        data: {
          status: PhoneChangeStatus.COMPLETED,
          newVerifiedAt: now,
          completedAt: now,
        },
      });

      // Every other session dies. If this change was a takeover the attacker
      // keeps nothing; if it was not, she signs back in with a code on the new
      // number, which she is holding.
      await tx.session.updateMany({
        where: {
          userId,
          status: SessionStatus.ACTIVE,
          ...(keepSessionId && { id: { not: keepSessionId } }),
        },
        data: {
          status: SessionStatus.REVOKED,
          revokedAt: now,
          revokedReason: 'phone_changed',
        },
      });
      await tx.refreshToken.updateMany({
        where: {
          userId,
          revokedAt: null,
          ...(keepSessionId && { sessionId: { not: keepSessionId } }),
        },
        data: { revokedAt: now },
      });

      return updated;
    });

    await this.prisma.securityEvent.createMany({
      data: [
        {
          actorId: userId,
          sessionId: keepSessionId,
          type: SecurityEventType.PHONE_CHANGED,
          riskLevel: RiskLevel.CRITICAL,
          ipAddress: context.ipAddress,
          userAgent: context.userAgent,
          resource: `phone_change:${request.id}`,
          metadata: {
            from: maskDestination(request.currentPhone),
            to: maskDestination(request.newPhone),
            payout_frozen_until: payoutFrozenUntil.toISOString(),
          },
        },
        {
          actorId: userId,
          type: SecurityEventType.PAYOUT_FROZEN,
          riskLevel: RiskLevel.HIGH,
          metadata: {
            reason: 'phone_change',
            until: payoutFrozenUntil.toISOString(),
          },
        },
      ],
    });

    await this.audit.record({
      actorId: userId,
      action: 'phone_change_completed',
      category: 'account',
      outcome: 'success',
      severity: AuditSeverity.CRITICAL,
      context,
      metadata: { request_id: request.id },
    });

    await this.prisma.notification.create({
      data: {
        userId,
        title: 'تم تغيير رقم الحساب',
        body: `أصبح رقم حسابكِ ${maskDestination(request.newPhone)}. تم إنهاء بقية الجلسات، وتم تجميد التحويلات المالية سبعة أيام كإجراء احترازي.`,
        type: NotificationType.system,
        data: {
          action: 'phone_changed',
          payout_frozen_until: payoutFrozenUntil.toISOString(),
        } as Prisma.InputJsonValue,
      },
    });

    return {
      id: request.id,
      status: PhoneChangeStatus.COMPLETED.toLowerCase(),
      phone: user.phone,
      payout_frozen_until: payoutFrozenUntil.toISOString(),
      other_sessions_revoked: true,
    };
  }

  async cancel(userId: string, requestId: string) {
    const request = await this.prisma.phoneChangeRequest.findFirst({
      where: { id: requestId, userId },
    });
    if (!request) throw new NotFoundException('No such phone change');
    if (
      request.status !== PhoneChangeStatus.AWAITING_CURRENT &&
      request.status !== PhoneChangeStatus.AWAITING_NEW
    ) {
      throw new BadRequestException({
        code: 'PHONE_CHANGE_NOT_PENDING',
        message: 'That phone change is no longer in progress',
      });
    }
    await this.cancelInternal(request.id, 'user_cancelled');
    return { id: request.id, status: PhoneChangeStatus.CANCELLED.toLowerCase() };
  }

  /** The change in flight, if any, so the app can resume mid-journey. */
  async pending(userId: string) {
    const request = await this.prisma.phoneChangeRequest.findFirst({
      where: {
        userId,
        status: {
          in: [
            PhoneChangeStatus.AWAITING_CURRENT,
            PhoneChangeStatus.AWAITING_NEW,
          ],
        },
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });
    // Wrapped rather than returned bare: a handler that returns `null` sends an
    // empty body, which the Flutter client cannot tell apart from a broken
    // response. An object with a null field is unambiguous.
    return { pending: request ? this.envelope(request) : null };
  }

  private async cancelInternal(id: string, reason: string) {
    await this.prisma.phoneChangeRequest.updateMany({
      where: {
        id,
        status: {
          in: [
            PhoneChangeStatus.AWAITING_CURRENT,
            PhoneChangeStatus.AWAITING_NEW,
          ],
        },
      },
      data: {
        status: PhoneChangeStatus.CANCELLED,
        cancelledAt: new Date(),
        cancelledReason: reason,
      },
    });
  }

  private async requireLive(
    userId: string,
    requestId: string,
    expected: PhoneChangeStatus,
  ) {
    const request = await this.prisma.phoneChangeRequest.findFirst({
      where: { id: requestId, userId },
    });
    if (!request) throw new NotFoundException('No such phone change');

    if (request.expiresAt < new Date()) {
      await this.prisma.phoneChangeRequest.updateMany({
        where: { id: request.id, status: { not: PhoneChangeStatus.COMPLETED } },
        data: { status: PhoneChangeStatus.EXPIRED },
      });
      throw new ForbiddenException({
        code: 'PHONE_CHANGE_EXPIRED',
        message: 'That phone change has expired. Start again.',
      });
    }

    if (request.status !== expected) {
      throw new BadRequestException({
        code: 'PHONE_CHANGE_WRONG_STEP',
        message: 'That step has already been completed',
        current_status: request.status.toLowerCase(),
      });
    }

    return request;
  }

  private envelope(
    request: {
      id: string;
      status: PhoneChangeStatus;
      currentPhone: string;
      newPhone: string;
      expiresAt: Date;
    },
    challenge?: {
      /** Null on the reverse rail, where no code is sent to her at all. */
      match_code: string | null;
      channel: string;
      expires_at: string;
      /** Present only on the reverse rail, and then both are present. */
      send_to?: string;
      sms_body?: string;
    },
  ) {
    return {
      id: request.id,
      status: request.status.toLowerCase(),
      // Masked on the way out, always. The point of the outgoing-number
      // challenge is that whoever holds the session does not get to read the
      // number it is going to off the response.
      masked_current: maskDestination(request.currentPhone),
      masked_new: maskDestination(request.newPhone),
      expires_at: request.expiresAt.toISOString(),
      ...(challenge && {
        challenge: {
          match_code: challenge.match_code,
          channel: challenge.channel,
          expires_at: challenge.expires_at,
          // The reverse rail asks her to send a message rather than read one,
          // so the client needs the address and the exact body. Absent on the
          // classic rail, where there is nothing for her to send.
          ...(challenge.send_to && challenge.sms_body
            ? { send_to: challenge.send_to, sms_body: challenge.sms_body }
            : {}),
          sent_to:
            request.status === PhoneChangeStatus.AWAITING_CURRENT
              ? 'current'
              : 'new',
        },
      }),
    };
  }
}
