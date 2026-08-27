import { Injectable, NotFoundException } from '@nestjs/common';
import {
  AuditSeverity,
  Prisma,
  RiskLevel,
  SecurityEventType,
  SessionStatus,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../audit.service';
import { TokenService } from '../token.service';
import { maskDestination } from '../otp/otp-transport';
import { RequestContext } from '../interfaces/request-context.interface';
import {
  SecurityEventQueryDto,
  UserTimelineQueryDto,
} from '../dto/security-forensics.dto';

/** One entry in the merged story of an account. */
export interface TimelineEntry {
  at: string;
  kind: 'security_event' | 'login_attempt' | 'audit' | 'challenge';
  label: string;
  risk: string | null;
  ip_address: string | null;
  user_agent: string | null;
  detail: Record<string, unknown>;
}

/**
 * Read access to the authentication record, for the people who answer the
 * support call.
 *
 * The subsystem wrote plenty of evidence and offered no way to read it: audit
 * lines, security events, login attempts and delivery receipts all went into
 * tables nothing queried. In practice that meant "someone is in my account"
 * had no investigable answer, which is the failure that matters — the logging
 * was never the point, being able to *look* was.
 *
 * The deliberate limit: this returns how the account was accessed, never what
 * was in it. No orders, no messages, no addresses. A support tool that can read
 * a woman's private life is a breach waiting for one phished staff login.
 */
@Injectable()
export class SecurityForensicsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly tokens: TokenService,
  ) {}

  async events(query: SecurityEventQueryDto) {
    const where: Prisma.SecurityEventWhereInput = {
      ...(query.user_id && { actorId: query.user_id }),
      ...(query.type && { type: query.type }),
      ...(query.risk_level && { riskLevel: query.risk_level }),
      ...(this.window(query.since, query.until) && {
        createdAt: this.window(query.since, query.until),
      }),
    };

    const take = Math.min(query.take ?? 50, 200);
    const [items, total] = await Promise.all([
      this.prisma.securityEvent.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take,
        skip: query.skip ?? 0,
      }),
      this.prisma.securityEvent.count({ where }),
    ]);

    return {
      items: items.map((event) => ({
        id: event.id,
        type: event.type.toLowerCase(),
        risk_level: event.riskLevel.toLowerCase(),
        user_id: event.actorId,
        guest_session_id: event.guestSessionId,
        session_id: event.sessionId,
        device_id: event.deviceId,
        ip_address: event.ipAddress,
        user_agent: event.userAgent,
        resource: event.resource,
        metadata: event.metadata,
        at: event.createdAt.toISOString(),
      })),
      total,
    };
  }

  async loginAttempts(query: SecurityEventQueryDto) {
    const where: Prisma.LoginAttemptWhereInput = {
      ...(query.user_id && { userId: query.user_id }),
      ...(this.window(query.since, query.until) && {
        createdAt: this.window(query.since, query.until),
      }),
    };

    const take = Math.min(query.take ?? 50, 200);
    const [items, total] = await Promise.all([
      this.prisma.loginAttempt.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take,
        skip: query.skip ?? 0,
      }),
      this.prisma.loginAttempt.count({ where }),
    ]);

    return {
      items: items.map((attempt) => ({
        id: attempt.id,
        user_id: attempt.userId,
        // Masked: the failure rows carry numbers that are not necessarily
        // anyone's account, and this endpoint must not become a way to read
        // them back out in bulk.
        phone: attempt.phone ? maskDestination(attempt.phone) : null,
        success: attempt.success,
        reason: attempt.reason,
        ip_address: attempt.ipAddress,
        user_agent: attempt.userAgent,
        severity: attempt.severity.toLowerCase(),
        at: attempt.createdAt.toISOString(),
      })),
      total,
    };
  }

  /**
   * Everything, in order, for one account.
   *
   * Four sources merged and sorted newest-first: security events, sign-in
   * attempts, audit lines, and the challenges the platform sent her. The last
   * one is what closes the most common support question — "I never got the
   * code" — because the delivery attempts sit in the same story as the sign-in
   * that did or did not follow.
   */
  async timeline(userId: string, query: UserTimelineQueryDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        username: true,
        phone: true,
        role: true,
        disabledAt: true,
        lockedUntil: true,
        passwordSetAt: true,
        totpRequired: true,
        payoutFrozenUntil: true,
        createdAt: true,
        lastLoginAt: true,
      },
    });
    if (!user) throw new NotFoundException('User not found');

    const take = Math.min(query.take ?? 100, 500);
    const since = query.since ? new Date(query.since) : undefined;
    const createdAt = since ? { gte: since } : undefined;

    const [events, attempts, auditLogs, challenges] = await Promise.all([
      this.prisma.securityEvent.findMany({
        where: { actorId: userId, ...(createdAt && { createdAt }) },
        orderBy: { createdAt: 'desc' },
        take,
      }),
      this.prisma.loginAttempt.findMany({
        where: { userId, ...(createdAt && { createdAt }) },
        orderBy: { createdAt: 'desc' },
        take,
      }),
      this.prisma.auditLog.findMany({
        where: { actorId: userId, ...(createdAt && { createdAt }) },
        orderBy: { createdAt: 'desc' },
        take,
      }),
      this.prisma.otpRequest.findMany({
        where: { userId, ...(createdAt && { createdAt }) },
        orderBy: { createdAt: 'desc' },
        take,
        include: {
          deliveries: {
            orderBy: { createdAt: 'asc' },
            select: {
              transport: true,
              status: true,
              failureReason: true,
              sentAt: true,
              deliveredAt: true,
            },
          },
        },
      }),
    ]);

    const entries: TimelineEntry[] = [
      ...events.map((event) => ({
        at: event.createdAt.toISOString(),
        kind: 'security_event' as const,
        label: event.type.toLowerCase(),
        risk: event.riskLevel.toLowerCase(),
        ip_address: event.ipAddress,
        user_agent: event.userAgent,
        detail: {
          resource: event.resource,
          session_id: event.sessionId,
          metadata: event.metadata,
        },
      })),
      ...attempts.map((attempt) => ({
        at: attempt.createdAt.toISOString(),
        kind: 'login_attempt' as const,
        label: attempt.success ? 'login_success' : 'login_failure',
        risk: attempt.severity === AuditSeverity.INFO ? 'low' : 'medium',
        ip_address: attempt.ipAddress,
        user_agent: attempt.userAgent,
        detail: { reason: attempt.reason },
      })),
      ...auditLogs.map((log) => ({
        at: log.createdAt.toISOString(),
        kind: 'audit' as const,
        label: `${log.category}.${log.action}`,
        risk: log.severity.toLowerCase(),
        ip_address: log.ipAddress,
        user_agent: log.userAgent,
        detail: { outcome: log.outcome, metadata: log.metadata },
      })),
      ...challenges.map((challenge) => ({
        at: challenge.createdAt.toISOString(),
        kind: 'challenge' as const,
        label: `otp.${challenge.purpose.toLowerCase()}`,
        risk: null,
        ip_address: challenge.ipAddress,
        user_agent: challenge.userAgent,
        detail: {
          status: challenge.status.toLowerCase(),
          destination: maskDestination(challenge.destination),
          attempts: challenge.attempts,
          verified_at: challenge.verifiedAt?.toISOString() ?? null,
          deliveries: challenge.deliveries.map((delivery) => ({
            transport: delivery.transport.toLowerCase(),
            status: delivery.status.toLowerCase(),
            failure_reason: delivery.failureReason,
            sent_at: delivery.sentAt?.toISOString() ?? null,
            delivered_at: delivery.deliveredAt?.toISOString() ?? null,
          })),
        },
      })),
    ].sort((a, b) => b.at.localeCompare(a.at));

    return {
      account: {
        id: user.id,
        name: user.name,
        username: user.username,
        phone: user.phone ? maskDestination(user.phone) : null,
        role: user.role.toLowerCase(),
        disabled: user.disabledAt !== null,
        locked_until: user.lockedUntil?.toISOString() ?? null,
        password_enabled: user.passwordSetAt !== null,
        totp_required: user.totpRequired,
        payout_frozen_until: user.payoutFrozenUntil?.toISOString() ?? null,
        registered_at: user.createdAt.toISOString(),
        last_login_at: user.lastLoginAt?.toISOString() ?? null,
      },
      entries: entries.slice(0, take),
    };
  }

  /** Live sessions and known devices, the two lists a support call asks about. */
  async sessionsAndDevices(userId: string) {
    const [sessions, deviceKeys] = await Promise.all([
      this.tokens.listSessions(userId),
      this.prisma.deviceKey.findMany({
        where: { userId },
        orderBy: { lastSeenAt: 'desc' },
        take: 100,
      }),
    ]);

    return {
      sessions,
      devices: deviceKeys.map((key) => ({
        id: key.id,
        label: key.label ?? key.model ?? key.platform,
        platform: key.platform,
        os_version: key.osVersion,
        model: key.model,
        app_version: key.appVersion,
        trust_level: key.trustLevel.toLowerCase(),
        hardware_backed: key.hardwareBacked,
        first_seen_at: key.firstSeenAt.toISOString(),
        last_seen_at: key.lastSeenAt.toISOString(),
        verified_at: key.verifiedAt?.toISOString() ?? null,
        revoked_at: key.revokedAt?.toISOString() ?? null,
        revoked_reason: key.revokedReason,
      })),
    };
  }

  /**
   * Cuts every session on an account. Removes access, never grants it.
   */
  async revokeAllSessions(
    userId: string,
    actorId: string,
    reason: string,
    context: RequestContext,
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });
    if (!user) throw new NotFoundException('User not found');

    const now = new Date();
    const [, sessions] = await this.prisma.$transaction([
      this.prisma.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: now },
      }),
      this.prisma.session.updateMany({
        where: { userId, status: SessionStatus.ACTIVE },
        data: {
          status: SessionStatus.REVOKED,
          revokedAt: now,
          revokedReason: `admin:${reason}`,
        },
      }),
    ]);

    await this.prisma.securityEvent.create({
      data: {
        actorId: userId,
        type: SecurityEventType.SESSION_REVOKED,
        riskLevel: RiskLevel.HIGH,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
        resource: `user:${userId}`,
        // The staff member who did it is named in the event, not just in the
        // audit log: "who cut my sessions" is the first question afterwards.
        metadata: { by_admin: actorId, reason },
      },
    });
    await this.audit.record({
      actorId,
      action: 'admin_revoke_sessions',
      category: 'auth',
      outcome: 'success',
      severity: AuditSeverity.CRITICAL,
      context,
      metadata: { subject_id: userId, reason },
    });

    return { user_id: userId, sessions_revoked: sessions.count };
  }

  private window(since?: string, until?: string) {
    if (!since && !until) return undefined;
    return {
      ...(since && { gte: new Date(since) }),
      ...(until && { lte: new Date(until) }),
    };
  }
}
