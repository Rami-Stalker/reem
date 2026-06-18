import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  RefreshToken,
  Session,
  SessionStatus,
  User,
  UserRole,
} from '@prisma/client';
import { createHmac, randomBytes, randomUUID } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from './interfaces/jwt-payload.interface';
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
  tokenFamily?: string;
  context?: RequestContext;
}

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
    const session = await this.resolveSession(user.id, refreshExpiresAt, options);
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
    const tokenHash = this.hashRefreshToken(refresh_token);
    const token = await this.prisma.refreshToken.create({
      data: {
        tokenHash,
        tokenFamily: options.tokenFamily ?? randomUUID(),
        userId: user.id,
        sessionId: session.id,
        deviceId: options.deviceId ?? session.deviceId,
        expiresAt: refreshExpiresAt,
      },
    });

    await this.prisma.session.update({
      where: { id: session.id },
      data: {
        currentRefreshTokenHash: token.tokenHash,
        lastSeenAt: new Date(),
        expiresAt: refreshExpiresAt,
      },
    });

    return {
      access_token,
      refresh_token,
      expires_in: Math.floor(this.accessExpiresMs / 1000),
      refresh_expires_at: refreshExpiresAt.toISOString(),
    };
  }

  async rotate(
    refreshToken: string,
    context: RequestContext = {},
  ): Promise<{ user: User; tokens: TokenPair }> {
    const stored = await this.findStoredToken(refreshToken);
    const now = new Date();

    if (!stored || stored.expiresAt < now) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    if (stored.revokedAt || stored.usedAt) {
      await this.revokeSession(stored.userId, stored.sessionId ?? undefined);
      throw new UnauthorizedException('Refresh token reuse detected');
    }

    if (!stored.session || stored.session.status !== SessionStatus.ACTIVE) {
      throw new UnauthorizedException('Session has expired');
    }

    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { usedAt: now, revokedAt: now },
    });

    const tokens = await this.issueTokens(stored.user, {
      sessionId: stored.session.id,
      deviceId: stored.deviceId ?? stored.session.deviceId ?? undefined,
      tokenFamily: stored.tokenFamily,
      context,
    });

    await this.prisma.refreshToken.updateMany({
      where: { id: stored.id },
      data: { replacedByTokenId: await this.latestTokenId(tokens.refresh_token) },
    });

    return { user: stored.user, tokens };
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
        data: { status: SessionStatus.REVOKED, revokedAt: now },
      }),
    ]);
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
  }

  async listSessions(userId: string) {
    const sessions = await this.prisma.session.findMany({
      where: { userId },
      include: { device: true },
      orderBy: { lastSeenAt: 'desc' },
      take: 100,
    });

    return sessions.map((session) => ({
      id: session.id,
      status: session.status.toLowerCase(),
      device_id: session.deviceId,
      device_name: session.device?.name ?? 'Unknown device',
      platform: session.device?.platform ?? null,
      ip_address: session.ipAddress,
      user_agent: session.userAgent,
      last_seen_at: session.lastSeenAt.toISOString(),
      expires_at: session.expiresAt.toISOString(),
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

  private async latestTokenId(refreshToken: string): Promise<string | null> {
    const token = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: this.hashRefreshToken(refreshToken) },
      select: { id: true },
    });
    return token?.id ?? null;
  }

  private async resolveSession(
    userId: string,
    expiresAt: Date,
    options: IssueTokenOptions,
  ): Promise<Session> {
    if (options.sessionId) {
      const session = await this.prisma.session.findFirst({
        where: {
          id: options.sessionId,
          userId,
          status: SessionStatus.ACTIVE,
          expiresAt: { gt: new Date() },
        },
      });
      if (!session) throw new UnauthorizedException('Session has expired');
      return this.prisma.session.update({
        where: { id: session.id },
        data: {
          lastSeenAt: new Date(),
          ipAddress: options.context?.ipAddress ?? session.ipAddress,
          userAgent: options.context?.userAgent ?? session.userAgent,
          expiresAt,
        },
      });
    }

    return this.prisma.session.create({
      data: {
        userId,
        deviceId: options.deviceId,
        ipAddress: options.context?.ipAddress,
        userAgent: options.context?.userAgent,
        expiresAt,
      },
    });
  }

  async permissionsFor(userId: string, role: UserRole): Promise<string[]> {
    const [rolePermissions, assignedRolePermissions] = await Promise.all([
      this.prisma.role.findUnique({
        where: { name: role },
        select: {
          permissions: {
            select: { permission: { select: { key: true } } },
          },
        },
      }),
      this.prisma.userRoleAssignment.findMany({
        where: {
          userId,
          OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
        },
        select: {
          role: {
            select: {
              permissions: {
                select: { permission: { select: { key: true } } },
              },
            },
          },
        },
      }),
    ]);

    const permissions = new Set<string>();
    rolePermissions?.permissions.forEach((entry) =>
      permissions.add(entry.permission.key),
    );
    assignedRolePermissions.forEach((assignment) =>
      assignment.role.permissions.forEach((entry) =>
        permissions.add(entry.permission.key),
      ),
    );
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
