import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * Authenticates the request when a valid token is present, but never rejects
 * anonymous callers. Used for public-yet-personalised endpoints (e.g. product
 * lists that show `is_liked` when the viewer is signed in).
 */
@Injectable()
export class OptionalJwtAuthGuard extends AuthGuard('jwt') {
  canActivate(context: ExecutionContext) {
    return super.canActivate(context);
  }

  handleRequest<TUser = unknown>(_err: unknown, user: TUser): TUser {
    // Swallow auth errors — anonymous access is allowed.
    return (user || undefined) as TUser;
  }
}
