import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
} from '@nestjs/common';
import {
  AssuranceLevel,
  NotificationType,
  OtpPurpose,
  RiskLevel,
  SecurityEventType,
  SessionStatus,
  StepUpMethod,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { OtpService } from '../otp.service';
import { maskDestination } from '../otp/otp-transport';
import { RequestContext } from '../interfaces/request-context.interface';
import { TotpService } from '../totp/totp.service';
import { RecoveryService } from '../recovery/recovery.service';

/** How long an elevated session stays elevated. */
const ELEVATION_MS = 10 * 60_000;

/**
 * A never-before-seen device cannot perform the sensitive actions for 24 hours,
 * even with a valid second factor.
 *
 * **This is a hardcoded constant on purpose.** Every step-up channel available
 * to a consumer today — a WhatsApp code, an SMS — arrives on the SIM. So if an
 * attacker holds the SIM, they hold the second factor too, and every rung of
 * the ladder is transitively defeated by the one attack it exists to stop. A
 * delay is the only control that does not route back through the stolen SIM.
 *
 * It works because of an asymmetry in behaviour, not in cryptography: a SIM
 * swapper acts within minutes because the window closes when the victim
 * notices, while a genuine owner who just bought a phone can wait a day. Shorten
 * it to an hour and it stops working; make it configurable and it will be
 * shortened. Hence: not a config value.
 */
const NEW_DEVICE_COOLDOWN_MS = 24 * 60 * 60_000;

export interface StepUpState {
  level: AssuranceLevel;
  elevatedUntil: Date | null;
  cooldownUntil: Date | null;
}

/**
 * Issues and consumes step-up challenges, and answers "how strongly is this
 * session authenticated right now".
 */
@Injectable()
export class StepUpService {
  private readonly logger = new Logger(StepUpService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly otp: OtpService,
    private readonly totp: TotpService,
    private readonly recovery: RecoveryService,
  ) {}

  /** The cooldown a session inherits from its device, if any. */
  static cooldownFor(deviceFirstSeenAt: Date): Date | null {
    const until = new Date(deviceFirstSeenAt.getTime() + NEW_DEVICE_COOLDOWN_MS);
    return until > new Date() ? until : null;
  }

  /**
   * Sends a second factor for `scope`.
   *
   * Today the only channel is an OTP to her number; TOTP and recovery codes
   * land with the recovery track and slot in here without changing callers.
   * Until then the cooldown is what covers the SIM-possession case, and that
   * limitation is deliberate and documented rather than papered over.
   */
  async request(
    userId: string,
    sessionId: string | undefined,
    scope: string,
    context: RequestContext,
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.phone) {
      throw new BadRequestException({
        code: 'STEP_UP_UNAVAILABLE',
        message: 'This account has no number to send a code to',
      });
    }

    await this.assertNotInCooldown(sessionId, scope);

    const challenge = await this.otp.request({
      phone: user.phone,
      purpose: OtpPurpose.DEVICE_VERIFICATION,
      userId,
      context,
    });

    await this.prisma.stepUpGrant.create({
      data: {
        userId,
        sessionId,
        scope,
        method: StepUpMethod.OTP,
        challengeId: challenge.otp_request_id,
        expiresAt: new Date(Date.now() + ELEVATION_MS),
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
      },
    });

    return {
      scope,
      channel: challenge.channel,
      masked_destination: maskDestination(user.phone),
      match_code: challenge.match_code,
      expires_at: challenge.expires_at,
    };
  }

  /**
   * Consumes a factor and elevates the session for ten minutes.
   *
   * Three channels, and the choice is the point: a TOTP code or a recovery
   * code proves possession of something that is *not* the SIM. An assurance
   * ladder whose every rung is another message to the same number is defeated
   * entirely by the SIM swap it exists to stop.
   */
  async verify(
    userId: string,
    sessionId: string | undefined,
    scope: string,
    code: string | undefined,
    context: RequestContext,
    method: StepUpMethod = StepUpMethod.OTP,
  ) {
    await this.assertNotInCooldown(sessionId, scope);

    // TOTP and recovery codes need no prior request — the factor is already in
    // her hands — so only the OTP path requires an outstanding grant.
    const grant =
      method === StepUpMethod.OTP
        ? await this.prisma.stepUpGrant.findFirst({
            where: {
              userId,
              scope,
              consumedAt: null,
              expiresAt: { gt: new Date() },
            },
            orderBy: { issuedAt: 'desc' },
          })
        : null;

    if (method === StepUpMethod.OTP && !grant) {
      throw new BadRequestException({
        code: 'STEP_UP_NOT_REQUESTED',
        message: 'Request a verification code first',
      });
    }

    await this.consumeFactor(userId, method, code);

    const elevatedUntil = new Date(Date.now() + ELEVATION_MS);
    if (grant) {
      await this.prisma.stepUpGrant.update({
        where: { id: grant.id },
        data: { consumedAt: new Date() },
      });
    } else {
      await this.prisma.stepUpGrant.create({
        data: {
          userId,
          sessionId,
          scope,
          method,
          expiresAt: elevatedUntil,
          consumedAt: new Date(),
          ipAddress: context.ipAddress,
          userAgent: context.userAgent,
        },
      });
    }

    if (sessionId) {
      await this.prisma.session.updateMany({
        where: { id: sessionId, userId },
        data: {
          assuranceLevel: AssuranceLevel.AAL3,
          elevatedUntil,
        },
      });
    }

    await this.prisma.securityEvent.create({
      data: {
        actorId: userId,
        sessionId,
        type: SecurityEventType.DEVICE_TRUSTED,
        riskLevel: RiskLevel.MEDIUM,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
        resource: `step_up:${scope}`,
        metadata: { method, scope },
      },
    });

    return {
      scope,
      assurance_level: AssuranceLevel.AAL3.toLowerCase(),
      elevated_until: elevatedUntil.toISOString(),
    };
  }

  /** Current standing of a session, with elevation expiry applied. */
  async stateOf(sessionId: string): Promise<StepUpState | null> {
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
      select: {
        assuranceLevel: true,
        elevatedUntil: true,
        newDeviceCooldownUntil: true,
        status: true,
      },
    });
    if (!session || session.status !== SessionStatus.ACTIVE) return null;

    const elevated =
      session.elevatedUntil !== null && session.elevatedUntil > new Date();

    return {
      level: elevated ? AssuranceLevel.AAL3 : AssuranceLevel.AAL1,
      elevatedUntil: elevated ? session.elevatedUntil : null,
      cooldownUntil:
        session.newDeviceCooldownUntil &&
        session.newDeviceCooldownUntil > new Date()
          ? session.newDeviceCooldownUntil
          : null,
    };
  }

  /**
   * Tells every other live session that a new device just signed in, and gives
   * her the one action worth offering at that moment.
   */
  async announceNewDevice(
    userId: string,
    sessionId: string,
    deviceLabel: string,
  ): Promise<void> {
    await this.prisma.notification.create({
      data: {
        userId,
        title: 'تسجيل دخول من جهاز جديد',
        body: `تم تسجيل الدخول إلى حسابكِ من ${deviceLabel}. إن لم تكوني أنت، سجّلي الخروج من كل الأجهزة الآن.`,
        type: NotificationType.system,
        data: {
          action: 'logout_all',
          session_id: sessionId,
          device: deviceLabel,
        },
      },
    });

    await this.prisma.securityEvent.create({
      data: {
        actorId: userId,
        sessionId,
        type: SecurityEventType.SUSPICIOUS_LOGIN,
        riskLevel: RiskLevel.MEDIUM,
        metadata: { reason: 'new_device_sign_in', device: deviceLabel },
      },
    });
  }

  /** Verifies whichever factor was offered, or refuses. */
  private async consumeFactor(
    userId: string,
    method: StepUpMethod,
    code: string | undefined,
  ): Promise<void> {
    // Only the OTP factor can arrive without a code, and only on the reverse
    // rail, where the proof is an inbound message rather than something she
    // typed. An authenticator or recovery code is a secret she holds; absent,
    // there is nothing to check and nothing to be lenient about.
    if (method === StepUpMethod.TOTP || method === StepUpMethod.RECOVERY_CODE) {
      if (!code) {
        throw new BadRequestException({
          code: 'CODE_REQUIRED',
          message: 'That code is not right',
        });
      }

      if (method === StepUpMethod.TOTP) {
        if (!(await this.totp.verify(userId, code))) {
          throw new BadRequestException({
            code: 'INVALID_TOTP',
            message: 'That code is not right',
          });
        }
        return;
      }

      if (!(await this.recovery.redeem(userId, code))) {
        throw new BadRequestException({
          code: 'INVALID_RECOVERY_CODE',
          message: 'That recovery code is not valid',
        });
      }
      return;
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    // `consumeAny` rather than `verifyAny`: elevating a session must not have
    // the side effect of marking a phone number verified. `Any` because the
    // challenge may have been opened on either rail.
    await this.otp.consumeAny(
      user!.phone!,
      OtpPurpose.DEVICE_VERIFICATION,
      code,
    );
  }

  private async assertNotInCooldown(
    sessionId: string | undefined,
    scope: string,
  ): Promise<void> {
    if (!sessionId) return;
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
      select: { newDeviceCooldownUntil: true },
    });
    const until = session?.newDeviceCooldownUntil;
    if (until && until > new Date()) {
      throw new ForbiddenException({
        code: 'NEW_DEVICE_COOLDOWN',
        message:
          'هذا الجهاز جديد. هذا الإجراء متاح بعد مرور 24 ساعة على أول تسجيل دخول منه.',
        scope,
        available_at: until.toISOString(),
      });
    }
  }
}
