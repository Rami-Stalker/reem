import { ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { AUTHORIZATION_POLICIES_KEY } from '../decorators/authorize.decorator';
import { AuthorizationPolicy } from '../authorization/authorization.types';
import { attachPrincipalToContext } from '../observability/request-context.middleware';

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

  /**
   * Names the account on the request's logging context.
   *
   * Passport calls this once the token has been validated, which is the first
   * moment anything knows who is asking — the middleware that minted the
   * request id runs before the guards and cannot. Every log line written from
   * here on carries the account, so "she says her order failed" becomes a
   * query rather than a search.
   */
  handleRequest<TUser = unknown>(
    err: unknown,
    user: TUser,
    info: unknown,
    context: ExecutionContext,
    status?: unknown,
  ): TUser {
    const resolved = super.handleRequest(
      err,
      user,
      info,
      context,
      status as never,
    ) as TUser;
    const request = context.switchToHttp().getRequest();
    request.user = resolved ?? request.user;
    attachPrincipalToContext(request);
    return resolved;
  }
}
