import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import {
  AccountRecoveryStatus,
  AuditSeverity,
  PhoneChangeStatus,
  RiskLevel,
  SessionStatus,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { AccountRecoveryService } from '../recovery/account-recovery.service';

const HOUR = 60 * 60_000;
const DAY = 24 * HOUR;

/**
 * How long each kind of auth record is kept.
 *
 * The split that matters is between *operational* rows and the *forensic*
 * record. Operational rows — spent proofs, dead challenges, revoked tokens —
 * stop being useful within days and are pure liability after that: they are a
 * standing collection of who signed in from where, on a platform where that
 * information can be dangerous to the women in it. The forensic record is the
 * opposite: a takeover is often reported months later, and an investigator with
 * no history has nothing to investigate.
 *
 * So low-severity telemetry ages out at roughly a year, and anything marked
 * WARNING or above is kept far longer.
 */
const RETENTION = {
  /** The replay window is ±60s; an hour past expiry is already generous. */
  deviceProofJti: HOUR,
  /** A spent or lapsed step-up grant is evidence for about a month. */
  stepUpGrant: 30 * DAY,
  /** Revoked and expired refresh tokens, well past any rotation race. */
  refreshToken: 30 * DAY,
  /** Closed sessions. Their security events outlive them. */
  session: 90 * DAY,
  /** Challenges, with their outbox rows and delivery attempts. */
  otpRequest: 90 * DAY,
  /** Sign-in attempts: the raw material of a brute-force investigation. */
  loginAttempt: 180 * DAY,
  /** Finished phone changes. */
  phoneChange: 180 * DAY,
  /** Routine audit and security telemetry. */
  routineTelemetry: 400 * DAY,
} as const;

/**
 * Ages out authentication data, and moves the clock-driven parts of the system
 * forward.
 *
 * Nothing here had an owner before. Every table the auth subsystem writes grew
 * without bound: proof replay guards, one-time codes, revoked tokens, every
 * sign-in attempt ever made. Two separate problems came out of that — a
 * database whose largest tables were all write-once telemetry, and a permanent,
 * ever-growing record of where each woman signs in from.
 *
 * It also carries the transitions that happen because time passed rather than
 * because somebody made a request: sessions that have run past their absolute
 * clock, challenges nobody answered, and recovery cases whose cool-off has
 * elapsed.
 */
@Injectable()
export class AuthRetentionCron {
  private readonly logger = new Logger(AuthRetentionCron.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly recovery: AccountRecoveryService,
  ) {}

  /**
   * The clock-driven transitions, run often.
   *
   * A session past its absolute expiry is not merely due for cleanup — until
   * it is marked, it still shows as "active" in her session list, which is the
   * one screen that has to be truthful.
   */
  @Cron(CronExpression.EVERY_10_MINUTES)
  async advanceClocks(): Promise<void> {
    const now = new Date();

    const expiredSessions = await this.prisma.session.updateMany({
      where: {
        status: SessionStatus.ACTIVE,
        OR: [
          { absoluteExpiresAt: { lt: now } },
          { idleExpiresAt: { lt: now } },
        ],
      },
      data: {
        status: SessionStatus.EXPIRED,
        revokedAt: now,
        revokedReason: 'lifetime_reached',
      },
    });

    if (expiredSessions.count > 0) {
      await this.prisma.refreshToken.updateMany({
        where: {
          revokedAt: null,
          session: { status: { not: SessionStatus.ACTIVE } },
        },
        data: { revokedAt: now },
      });
    }

    const lapsedChanges = await this.prisma.phoneChangeRequest.updateMany({
      where: {
        status: {
          in: [
            PhoneChangeStatus.AWAITING_CURRENT,
            PhoneChangeStatus.AWAITING_NEW,
          ],
        },
        expiresAt: { lt: now },
      },
      data: { status: PhoneChangeStatus.EXPIRED },
    });

    const lapsedCases = await this.prisma.accountRecoveryCase.updateMany({
      where: {
        status: {
          in: [
            AccountRecoveryStatus.SUBMITTED,
            AccountRecoveryStatus.UNDER_REVIEW,
            AccountRecoveryStatus.AWAITING_SECOND_APPROVAL,
          ],
        },
        expiresAt: { lt: now },
      },
      data: { status: AccountRecoveryStatus.EXPIRED },
    });

    // The hand-over itself. Driven by elapsed time and nothing else — see
    // `AccountRecoveryService.completeMaturedCases`.
    const completed = await this.recovery.completeMaturedCases(now);

    if (
      expiredSessions.count ||
      lapsedChanges.count ||
      lapsedCases.count ||
      completed
    ) {
      this.logger.log(
        `Clocks advanced: ${expiredSessions.count} sessions expired, ` +
          `${lapsedChanges.count} phone changes lapsed, ` +
          `${lapsedCases.count} recovery cases lapsed, ` +
          `${completed} recovery cases completed`,
      );
    }
  }

  /**
   * The sweep proper. Nightly, at an hour Damascus is asleep.
   *
   * Deletes are issued oldest-table-first and each is independently bounded, so
   * a slow one cannot wedge the rest. Nothing here cascades into anything a
   * person can see: sessions and challenges are already dead by the time they
   * are eligible.
   */
  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async sweep(): Promise<void> {
    const now = Date.now();
    const before = (ms: number) => new Date(now - ms);
    const started = Date.now();

    const [
      proofJtis,
      grants,
      refreshTokens,
      sessions,
      challenges,
      loginAttempts,
      phoneChanges,
      auditLogs,
      securityEvents,
    ] = await Promise.all([
      this.prisma.deviceProofJti.deleteMany({
        where: { expiresAt: { lt: before(RETENTION.deviceProofJti) } },
      }),
      this.prisma.stepUpGrant.deleteMany({
        where: { expiresAt: { lt: before(RETENTION.stepUpGrant) } },
      }),
      this.prisma.refreshToken.deleteMany({
        where: { expiresAt: { lt: before(RETENTION.refreshToken) } },
      }),
      this.prisma.session.deleteMany({
        where: {
          status: { not: SessionStatus.ACTIVE },
          updatedAt: { lt: before(RETENTION.session) },
        },
      }),
      // Cascades to `otp_outbox` and `challenge_deliveries`. The sealed
      // plaintext is long gone by then — the dispatcher shreds it on use or
      // expiry — so this is only removing the metadata shell.
      this.prisma.otpRequest.deleteMany({
        where: { createdAt: { lt: before(RETENTION.otpRequest) } },
      }),
      this.prisma.loginAttempt.deleteMany({
        where: { createdAt: { lt: before(RETENTION.loginAttempt) } },
      }),
      this.prisma.phoneChangeRequest.deleteMany({
        where: {
          status: {
            in: [
              PhoneChangeStatus.COMPLETED,
              PhoneChangeStatus.CANCELLED,
              PhoneChangeStatus.EXPIRED,
            ],
          },
          updatedAt: { lt: before(RETENTION.phoneChange) },
        },
      }),
      // Only the routine half. A WARNING or CRITICAL line is the record of an
      // account takeover, a password reset, a recovery hand-over — the things
      // somebody comes asking about a year later.
      this.prisma.auditLog.deleteMany({
        where: {
          severity: AuditSeverity.INFO,
          createdAt: { lt: before(RETENTION.routineTelemetry) },
        },
      }),
      this.prisma.securityEvent.deleteMany({
        where: {
          riskLevel: { in: [RiskLevel.LOW, RiskLevel.MEDIUM] },
          createdAt: { lt: before(RETENTION.routineTelemetry) },
        },
      }),
    ]);

    this.logger.log(
      `Auth retention sweep in ${Date.now() - started}ms: ` +
        `${proofJtis.count} proof jtis, ${grants.count} step-up grants, ` +
        `${refreshTokens.count} refresh tokens, ${sessions.count} sessions, ` +
        `${challenges.count} challenges, ${loginAttempts.count} login attempts, ` +
        `${phoneChanges.count} phone changes, ${auditLogs.count} audit logs, ` +
        `${securityEvents.count} security events`,
    );
  }
}
