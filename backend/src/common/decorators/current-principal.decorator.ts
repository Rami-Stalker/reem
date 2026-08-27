import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { GuestSession } from '@prisma/client';
import { AuthUser } from './current-user.decorator';

export type RequestPrincipal =
  | { kind: 'user'; user: AuthUser }
  | { kind: 'guest'; guest: GuestSession };

export const CurrentPrincipal = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): RequestPrincipal | undefined => {
    const request = ctx.switchToHttp().getRequest();
    if (request.user) {
      return { kind: 'user', user: request.user as AuthUser };
    }
    if (request.guest) {
      return { kind: 'guest', guest: request.guest as GuestSession };
    }
    return undefined;
  },
);
