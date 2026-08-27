import { ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { AUTHORIZATION_POLICIES_KEY } from '../decorators/authorize.decorator';
import { AuthorizationPolicy } from '../authorization/authorization.types';

/**
 * Global authentication guard. Requires a valid access token unless the route
 * is annotated with @Public().
 */
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private readonly reflector: Reflector) {
    super();
  }

  canActivate(context: ExecutionContext) {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;
    const policies = this.reflector.getAllAndOverride<AuthorizationPolicy[]>(
      AUTHORIZATION_POLICIES_KEY,
      [context.getHandler(), context.getClass()],
    );
    const allowsGuest = policies?.some((policy) => policy.allowGuest);
    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers?.authorization;
    if (allowsGuest && !authHeader) return true;
    return super.canActivate(context);
  }
}
