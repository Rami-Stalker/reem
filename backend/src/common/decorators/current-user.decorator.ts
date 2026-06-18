import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { UserRole } from '@prisma/client';

/** The authenticated principal attached to the request by the JWT strategy. */
export interface AuthUser {
  id: string;
  phone: string | null;
  role: UserRole;
  sessionId?: string;
  permissions?: string[];
}

/**
 * Inject the authenticated user (or one of its properties) into a handler.
 *   @CurrentUser() user: AuthUser
 *   @CurrentUser('id') userId: string
 */
export const CurrentUser = createParamDecorator(
  (data: keyof AuthUser | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user: AuthUser | undefined = request.user;
    return data ? user?.[data] : user;
  },
);
