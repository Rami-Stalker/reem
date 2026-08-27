import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuthUser } from '../../../common/decorators/current-user.decorator';
import { JwtPayload } from '../interfaces/jwt-payload.interface';
import { SessionStatus } from '@prisma/client';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('jwt.accessSecret') as string,
    });
  }

  /** Runs on every authenticated request; the return value becomes req.user. */
  async validate(payload: JwtPayload): Promise<AuthUser> {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: { id: true, phone: true, role: true, disabledAt: true },
    });
    if (!user || user.disabledAt) {
      throw new UnauthorizedException('User account no longer exists');
    }
    if (payload.sid) {
      const session = await this.prisma.session.findFirst({
        where: {
          id: payload.sid,
          userId: payload.sub,
          status: SessionStatus.ACTIVE,
          // Both clocks, every request: a session past its absolute lifetime
          // must stop working even while its idle clock is still sliding.
          idleExpiresAt: { gt: new Date() },
          absoluteExpiresAt: { gt: new Date() },
        },
        select: { id: true },
      });
      if (!session) {
        throw new UnauthorizedException('Session has expired');
      }
    }
    return {
      id: user.id,
      phone: user.phone,
      role: user.role,
      sessionId: payload.sid,
      permissions: payload.permissions ?? [],
    };
  }
}
