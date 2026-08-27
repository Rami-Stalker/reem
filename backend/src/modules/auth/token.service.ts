import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  RefreshToken,
  RiskLevel,
  SecurityEventType,
  Session,
  SessionStatus,
  User,
  UserRole,
} from '@prisma/client';
import { createHash, createHmac, randomBytes, randomUUID } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { resolvePermissions } from '../../common/authorization/permission-resolver';
import { JwtPayload } from './interfaces/jwt-payload.interface';
import { StepUpService } from './step-up/step-up.service';
import { RequestContext } from './interfaces/request-context.interface';

export interface TokenPair {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  refresh_expires_at: string;
}

type TokenSubject = Pick<User, 'id' | 'phone' | 'role'>;

interface IssueTokenOptions {
  sessionId?: string;
  deviceId?: string;
  deviceKeyId?: string;
  tokenFamily?: string;
  prevTokenId?: string;
  context?: RequestContext;
}

/**
 * Absolute session lifetimes. Rotation never extends these.
 *
 * 90 days for shoppers and sellers is the owner's call, and it sets two things
 * at once: roughly four re-authentications a year per device (so a bounded
 * messaging bill), and a cap of one quarter on how long a stolen unlocked
 * handset stays signed in. Privileged roles get 12 hours, because the blast
 * radius of an admin session is the platform.
 */
const CONSUMER_ABSOLUTE_MS = 90 * 24 * 60 * 60_000;
const PRIVILEGED_ABSOLUTE_MS = 12 * 60 * 60_000;

const PRIVILEGED_ROLES: UserRole[] = [
  UserRole.SUPER_ADMIN,
  UserRole.OPERATIONS_ADMIN,
  UserRole.SUPPORT_ADMIN,
  UserRole.FINANCE_ADMIN,
  UserRole.CONTENT_MODERATOR,
  UserRole.ADMIN,
  UserRole.SUPPORT,
];

/**
 * Owns access tokens and one-time refresh-token rotation.
 *
 * Refresh tokens are opaque random secrets. Only HMAC hashes are stored, and a
 * used or revoked token cannot be replayed without revoking the whole session.
 */
@Injectable()
export class TokenService {
  private readonly accessSecret: string;
  private readonly refreshPepper: string;
  private readonly refreshKeyId: string;
  private readonly accessExpiresIn: string;
  private readonly refreshExpiresIn: string;
  private readonly accessExpiresMs: number;
  private readonly refreshExpiresMs: number;

  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    config: ConfigService,
  ) {
    this.accessSecret = config.get<string>('jwt.accessSecret') as string;
    this.refreshPepper = config.get<string>('jwt.refreshSecret') as string;
    // A short, non-secret fingerprint of the pepper, stored beside each hash.
    // Without it, rotating the pepper invalidates every live token at once;
    // with it, both peppers can be accepted during a rollover.
    this.refreshKeyId = createHash('sha256')
      .update(this.refreshPepper)
      .digest('hex')
      .slice(0, 8);
    this.accessExpiresIn = config.get<string>('jwt.accessExpiresIn') as string;
    this.refreshExpiresIn = config.get<string>('jwt.refreshExpiresIn') as string;
    this.accessExpiresMs = parseDurationMs(this.accessExpiresIn, 15 * 60_000);
    this.refreshExpiresMs = parseDurationMs(
      this.refreshExpiresIn,
      7 * 24 * 60 * 60_000,
    );
  }

  async issueTokens(
    user: TokenSubject,
    options: IssueTokenOptions = {},
  ): Promise<TokenPair> {
    const refreshExpiresAt = new Date(Date.now() + this.refreshExpiresMs);
    const session = await this.resolveSession(
      user.id,
      refreshExpiresAt,
      options,
      user.role as UserRole,
    );
    const permissions = await this.permissionsFor(user.id, user.role);

    const payload: JwtPayload = {
      sub: user.id,
      phone: user.phone,
      role: user.role as UserRole,
      sid: session.id,
      permissions,
    };

    const access_token = await this.jwt.signAsync(payload, {
      secret: this.accessSecret,
      expiresIn: this.accessExpiresIn,
    });

    const refresh_token = randomBytes(64).toString('base64url');
    await this.prisma.refreshToken.create({
      data: {
        tokenHash: this.hashRefreshToken(refresh_token),
        tokenFamily: options.tokenFamily ?? randomUUID(),
        userId: user.id,
        sessionId: session.id,
        deviceId: options.deviceId ?? session.deviceId,
        deviceKeyId: options.deviceKeyId ?? session.deviceKeyId,
        keyId: this.refreshKeyId,
        prevTokenId: options.prevTokenId,
        expiresAt: refreshExpiresAt,
      },
    });

    // The idle clock slides; the absolute one set at creation does not.
    await this.prisma.session.update({
      where: { id: session.id },
      data: {
        lastSeenAt: new Date(),
        idleExpiresAt: refreshExpiresAt,
      },
    });

    return {
      access_token,
      refresh_token,
      expires_in: Math.floor(this.accessExpiresMs / 1000),
      refresh_expires_at: refreshExpiresAt.toISOString(),
    };
  }

  /**
   * Exchanges a refresh token for a new pair.
   *
   * The consumption is a single compare-and-set — `updateMany` filtered on
   * `usedAt: null, revokedAt: null`, with `count === 0` meaning somebody got
   * there first. The previous read-then-write let two concurrent presentations
   * of one token both pass the reuse check and both mint a chain, which
   * silently disabled the one detection control the whole design rests on.
   *
   * `deviceKeyId` is the second half: a token bound to a device may only be
   * rotated by a caller that proved possession of that device's key, so an
   * exfiltrated token on its own is inert.
   */
  async rotate(
    refreshToken: string,
    context: RequestContext = {},
    provenDeviceKeyId?: string,
  ): Promise<{ user: User; tokens: TokenPair }> {
    const stored = await this.findStoredToken(refreshToken);
    const now = new Date();

    if (!stored || stored.expiresAt < now) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    if (stored.revokedAt || stored.usedAt) {
      await this.prisma.securityEvent.create({
        data: {
          actorId: stored.userId,
          sessionId: stored.sessionId,
          deviceId: stored.deviceId,
          type: SecurityEventType.REFRESH_TOKEN_REUSE,
          riskLevel: RiskLevel.CRITICAL,
          ipAddress: context.ipAddress,
          userAgent: context.userAgent,
          metadata: { token_family: stored.tokenFamily },
        },
      });
      await this.revokeSession(stored.userId, stored.sessionId ?? undefined);
      throw new UnauthorizedException('Refresh token reuse detected');
    }

    if (!stored.session || stored.session.status !== SessionStatus.ACTIVE) {
      throw new UnauthorizedException('Session has expired');
    }

    // The hard ceiling. An active chain slides its idle clock forever; this is
    // the checkpoint that eventually forces a real re-authentication.
    if (stored.session.absoluteExpiresAt < now) {
      await this.expireSession(stored.session.id, 'absolute_lifetime_reached');
      throw new UnauthorizedException('Session has expired');
    }

    // Device binding: a bound token needs a proof from the same key.
    if (stored.deviceKeyId && stored.deviceKeyId !== provenDeviceKeyId) {
      await this.prisma.securityEvent.create({
        data: {
          actorId: stored.userId,
          sessionId: stored.sessionId,
          type: SecurityEventType.SUSPICIOUS_LOGIN,
          riskLevel: RiskLevel.HIGH,
          ipAddress: context.ipAddress,
          userAgent: context.userAgent,
          metadata: {
            reason: 'refresh_without_device_proof',
            expected_device_key: stored.deviceKeyId,
          },
        },
      });
      throw new UnauthorizedException('Device proof required');
    }

    // Rotation is the natural re-authorisation checkpoint: a user disabled or
    // demoted mid-session used to renew indefinitely, because nothing here
    // looked at her again after the first login.
    if (stored.user.disabledAt) {
      await this.revokeAll(stored.userId);
      throw new UnauthorizedException('Account suspended');
    }

    // Compare-and-set. Losing this race means the token was already spent —
    // which is reuse, not a retry.
    const consumed = await this.prisma.refreshToken.updateMany({
      where: { id: stored.id, usedAt: null, revokedAt: null },
      data: { usedAt: now, revokedAt: now },
    });

    if (consumed.count === 0) {
      await this.prisma.securityEvent.create({
        data: {
          actorId: stored.userId,
          sessionId: stored.sessionId,
          deviceId: stored.deviceId,
          type: SecurityEventType.REFRESH_TOKEN_REUSE,
          riskLevel: RiskLevel.CRITICAL,
          ipAddress: context.ipAddress,
          userAgent: context.userAgent,
          metadata: { token_family: stored.tokenFamily, concurrent: true },
        },
      });
      await this.revokeSession(stored.userId, stored.sessionId ?? undefined);
      throw new UnauthorizedException('Refresh token reuse detected');
    }

    const tokens = await this.issueTokens(stored.user, {
      sessionId: stored.session.id,
      deviceId: stored.deviceId ?? stored.session.deviceId ?? undefined,
      deviceKeyId: stored.deviceKeyId ?? stored.session.deviceKeyId ?? undefined,
      tokenFamily: stored.tokenFamily,
      prevTokenId: stored.id,
      context,
    });

    return { user: stored.user, tokens };
  }

  private async expireSession(sessionId: string, reason: string) {
    await this.prisma.session.updateMany({
      where: { id: sessionId },
      data: {
        status: SessionStatus.EXPIRED,
        revokedAt: new Date(),
        revokedReason: reason,
      },
    });
    await this.prisma.refreshToken.updateMany({
      where: { sessionId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async revoke(refreshToken: string): Promise<void> {
    const stored = await this.findStoredToken(refreshToken);
    if (!stored) return;
    const now = new Date();
    await this.prisma.$transaction([
      this.prisma.refreshToken.update({
        where: { id: stored.id },
        data: { revokedAt: now },
      }),
      ...(stored.sessionId
        ? [
            this.prisma.session.update({
              where: { id: stored.sessionId },
              data: { status: SessionStatus.REVOKED, revokedAt: now },
            }),
          ]
        : []),
    ]);
  }

  async revokeAll(userId: string, keepSessionId?: string): Promise<void> {
    const now = new Date();
    await this.prisma.$transaction([
      this.prisma.refreshToken.updateMany({
        where: {
          userId,
          revokedAt: null,
          ...(keepSessionId && { sessionId: { not: keepSessionId } }),
        },
        data: { revokedAt: now },
      }),
      this.prisma.session.updateMany({
        where: {
          userId,
          status: SessionStatus.ACTIVE,
          ...(keepSessionId && { id: { not: keepSessionId } }),
        },
        data: {
          status: SessionStatus.REVOKED,
          revokedAt: now,
          revokedReason: 'revoke_all',
        },
      }),
    ]);

    // "Sign out everywhere" is the single most security-relevant thing a user
    // can do, and it wrote no telemetry at all — so an investigator could not
    // see that she had reacted to a compromise.
    await this.prisma.securityEvent.create({
      data: {
        actorId: userId,
        type: SecurityEventType.SESSION_REVOKED,
        riskLevel: RiskLevel.MEDIUM,
        metadata: { scope: keepSessionId ? 'others' : 'all' },
      },
    });
  }

  async revokeSession(userId: string, sessionId?: string): Promise<void> {
    if (!sessionId) return;
    const now = new Date();
    await this.prisma.$transaction([
      this.prisma.refreshToken.updateMany({
        where: { userId, sessionId, revokedAt: null },
        data: { revokedAt: now },
      }),
      this.prisma.session.updateMany({
        where: { id: sessionId, userId },
        data: { status: SessionStatus.REVOKED, revokedAt: now },
      }),
    ]);
    await this.prisma.securityEvent.create({
      data: {
        actorId: userId,
        sessionId,
        type: SecurityEventType.SESSION_REVOKED,
        riskLevel: RiskLevel.MEDIUM,
      },
    });
  }

  async listSessions(userId: string) {
    const sessions = await this.prisma.session.findMany({
      where: { userId },
      include: { device: true, deviceKey: true },
      orderBy: { lastSeenAt: 'desc' },
      take: 100,
    });

    return sessions.map((session) => ({
      id: session.id,
      status: session.status.toLowerCase(),
      device_id: session.deviceId,
      device_key_id: session.deviceKeyId,
      device_name:
        session.deviceKey?.label ?? session.device?.name ?? 'Unknown device',
      platform: session.deviceKey?.platform ?? session.device?.platform ?? null,
      ip_address: session.ipAddress,
      user_agent: session.userAgent,
      last_seen_at: session.lastSeenAt.toISOString(),
      idle_expires_at: session.idleExpiresAt.toISOString(),
      absolute_expires_at: session.absoluteExpiresAt.toISOString(),
      revoked_at: session.revokedAt?.toISOString() ?? null,
      created_at: session.createdAt.toISOString(),
    }));
  }

  hashRefreshToken(token: string): string {
    return createHmac('sha256', this.refreshPepper).update(token).digest('hex');
  }

  private async findStoredToken(refreshToken: string) {
    return this.prisma.refreshToken.findUnique({
      where: { tokenHash: this.hashRefreshToken(refreshToken) },
      include: { user: true, session: true },
    });
  }

  private async resolveSession(
    userId: string,
    idleExpiresAt: Date,
    options: IssueTokenOptions,
    role: UserRole,
  ): Promise<Session> {
    if (options.sessionId) {
      const session = await this.prisma.session.findFirst({
        where: {
          id: options.sessionId,
          userId,
          status: SessionStatus.ACTIVE,
          idleExpiresAt: { gt: new Date() },
          absoluteExpiresAt: { gt: new Date() },
        },
      });
      if (!session) throw new UnauthorizedException('Session has expired');
      return this.prisma.session.update({
        where: { id: session.id },
        data: {
          lastSeenAt: new Date(),
          ipAddress: options.context?.ipAddress ?? session.ipAddress,
          userAgent: options.context?.userAgent ?? session.userAgent,
          // Only the idle clock moves. `absoluteExpiresAt` is deliberately
          // absent from this update.
          idleExpiresAt,
        },
      });
    }

    const absoluteMs = PRIVILEGED_ROLES.includes(role)
      ? PRIVILEGED_ABSOLUTE_MS
      : CONSUMER_ABSOLUTE_MS;

    // A session opened on a device the platform has only just met inherits
    // that device's cooldown, during which the sensitive actions are refused
    // outright. See `StepUpService` for why this is a delay rather than
    // another challenge.
    let newDeviceCooldownUntil: Date | null = null;
    if (options.deviceKeyId) {
      const key = await this.prisma.deviceKey.findUnique({
        where: { id: options.deviceKeyId },
        select: { firstSeenAt: true },
      });
      if (key) newDeviceCooldownUntil = StepUpService.cooldownFor(key.firstSeenAt);
    }

    return this.prisma.session.create({
      data: {
        userId,
        deviceId: options.deviceId,
        deviceKeyId: options.deviceKeyId,
        ipAddress: options.context?.ipAddress,
        userAgent: options.context?.userAgent,
        idleExpiresAt,
        absoluteExpiresAt: new Date(Date.now() + absoluteMs),
        newDeviceCooldownUntil,
      },
    });
  }

  /**
   * The permission list embedded in the access token.
   *
   * A **hint for the client**, so the app can hide a button it would be
   * refused for — not an authority. Every decision resolves from the database
   * through the same resolver; see `AuthorizationService.permissionsFor` for
   * why trusting this claim was a real hole.
   */
  async permissionsFor(userId: string, role: UserRole): Promise<string[]> {
    const permissions = await resolvePermissions(this.prisma, userId, role);
    return [...permissions].sort();
  }
}

function parseDurationMs(input: string | undefined, fallback: number): number {
  if (!input) return fallback;
  const match = /^(\d+)(ms|s|m|h|d)?$/.exec(input.trim());
  if (!match) return fallback;

  const value = Number(match[1]);
  const unit = match[2] ?? 'ms';
  const multipliers: Record<string, number> = {
    ms: 1,
    s: 1000,
    m: 60_000,
    h: 60 * 60_000,
    d: 24 * 60 * 60_000,
  };

  return value * multipliers[unit];
}
