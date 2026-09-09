import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { RiskLevel, SecurityEventType, UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../decorators/current-user.decorator';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import { AUTHORIZATION_POLICIES_KEY } from '../decorators/authorize.decorator';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { SELF_SCOPED_KEY } from '../decorators/self-scoped.decorator';
import { AuthorizationPolicy } from './authorization.types';
import { AuthorizationService } from './authorization.service';
import { GuestService } from '../../modules/auth/guest.service';
import { requestContextFrom } from '../../modules/auth/interfaces/request-context.interface';

@Injectable()
export class AuthorizationGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly authz: AuthorizationService,
    private readonly prisma: PrismaService,
    private readonly guests: GuestService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request & { user?: AuthUser }>();
    const policies = this.policiesFor(context);

    if (policies.length === 0) {
      // `@Public()` is the opposite of an undeclared route: it is somebody
      // stating, in one word, that this needs no session at all. The sign-in
      // routes, the OTP exchange, the carrier webhooks and the public
      // catalogue all live behind it, and failing closed on them would take
      // the platform off the air.
      if (
        this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
          context.getHandler(),
          context.getClass(),
        ])
      ) {
        return true;
      }

      // **Fail closed.** This used to `return true`, which meant a route that
      // declared nothing was open to any authenticated account. In practice
      // almost every such route was protected by an ownership check inside its
      // service — but the guarantee could not be read from the declaration,
      // only from opening 171 services, and a new route added to one of those
      // controllers inherited "allowed" in silence.
      //
      // A controller that genuinely enforces ownership one layer down says so
      // with `@SelfScoped('...')`, and the reason it gives is the thing a
      // reviewer reads instead of the service.
      const selfScoped = this.reflector.getAllAndOverride<string>(
        SELF_SCOPED_KEY,
        [context.getHandler(), context.getClass()],
      );
      if (selfScoped) return true;

      await this.recordDenied(request, policies);
      throw new ForbiddenException(
        'This route declares no authorization policy',
      );
    }

    if (!request.user && policies.some((policy) => policy.allowGuest)) {
      const requestContext = requestContextFrom(request);
      (request as Request & { guest?: unknown }).guest =
        await this.guests.requireActiveGuest(
        requestContext.guestToken,
        requestContext,
      );
    }

    for (const policy of policies) {
      if (await this.authz.can(request.user, policy, request)) {
        return true;
      }
    }

    await this.recordDenied(request, policies);
    throw new ForbiddenException('You do not have permission to perform this action');
  }

  /**
   * The policies this route is actually judged by.
   *
   * The subtle part is the merge. `@Authorize(...)` used to *replace* the
   * surrounding `@Roles(...)` rather than narrow it, so on the 34 handlers that
   * carry both — the whole admin surface and the security console — the role
   * restriction written at the top of the controller was decorative. Nothing
   * was exploitable today, because the permissions those routes demand are not
   * held by shoppers or sellers; but the guarantee a reader would take from
   * `@Roles(SUPER_ADMIN, ADMIN, SUPPORT)` was simply not being enforced, and a
   * permission granted to a new role later would have quietly opened them.
   *
   * A policy that names its own roles still wins — that is a deliberate
   * narrowing by the author. A policy that is silent inherits the contextual
   * restriction, which is what the declaration reads as.
   */
  private policiesFor(context: ExecutionContext): AuthorizationPolicy[] {
    const roles = this.reflector.getAllAndOverride<UserRole[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    const declared = this.reflector.getAllAndOverride<AuthorizationPolicy[]>(
      AUTHORIZATION_POLICIES_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (declared?.length) {
      if (!roles?.length) return declared;
      return declared.map((policy) => ({
        ...policy,
        roles: policy.roles?.length ? policy.roles : roles,
      }));
    }

    const permissions = this.reflector.getAllAndOverride<string[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!roles?.length && !permissions?.length) return [];
    return [
      {
        action: 'access',
        resource: 'admin',
        roles,
        permissions,
      },
    ];
  }

  private async recordDenied(
    request: Request & { user?: AuthUser },
    policies: AuthorizationPolicy[],
  ) {
    try {
      await this.prisma.securityEvent.create({
        data: {
          actorId: request.user?.id,
          sessionId: request.user?.sessionId,
          type: SecurityEventType.AUTHZ_DENIED,
          riskLevel: RiskLevel.MEDIUM,
          ipAddress: request.ip,
          userAgent: request.headers['user-agent'],
          resource: request.path,
          metadata: {
            method: request.method,
            policies: policies.map((policy) => ({
              action: policy.action,
              resource: policy.resource,
              roles: policy.roles,
              permissions: policy.permissions,
              allow_guest: policy.allowGuest,
            })),
          },
        },
      });
    } catch {
      // Authorization must not depend on telemetry persistence.
    }
  }
}
