import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { StoreTeamStatus, UserRole } from '@prisma/client';
import { Request } from 'express';

import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { STORE_HEADER, mayActFor } from './store-access';

/** Who is really acting when a request runs as a shop. */
export interface StoreActor {
  memberId: string;
  storeId: string;
  role: string;
}

export type DelegatedRequest = Request & {
  user?: AuthUser;
  storeActor?: StoreActor;
};

/**
 * «إدارة الفريق» — lets a team member work a shop from her own account.
 *
 * A request carrying `x-ohara-store` from an active member, to a route her
 * role covers, runs *as the shop*: the principal becomes the owner's seller
 * account, so every seller route and every ownership check works unchanged,
 * and `storeActor` keeps who actually did it for the activity log.
 *
 * Runs after authentication and device proof (which bind to her own session)
 * and before authorization (which then sees the shop). Anything outside her
 * role is refused here with a sentence, never silently run as herself.
 */
@Injectable()
export class StoreDelegationGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (context.getType() !== 'http') return true;
    const request = context.switchToHttp().getRequest<DelegatedRequest>();
    const header = request.headers[STORE_HEADER];
    const storeId = Array.isArray(header) ? header[0] : header;
    if (!storeId || !request.user) return true;
    // Her own shop: nothing to delegate.
    if (storeId === request.user.id) return true;

    if (!/^[0-9a-f-]{36}$/i.test(storeId)) {
      throw new ForbiddenException('ما عندكِ صلاحية على هالمتجر');
    }

    const membership = await this.prisma.sellerTeamMember.findUnique({
      where: { storeId_memberId: { storeId, memberId: request.user.id } },
      select: {
        role: true,
        status: true,
        store: { select: { id: true, phone: true, role: true } },
      },
    });
    if (
      !membership ||
      membership.status !== StoreTeamStatus.ACTIVE ||
      membership.store.role !== UserRole.SELLER
    ) {
      throw new ForbiddenException('ما عندكِ صلاحية على هالمتجر');
    }
    if (!mayActFor(membership.role, request.path)) {
      throw new ForbiddenException('صلاحيتكِ بالفريق ما بتشمل هالقسم');
    }

    request.storeActor = {
      memberId: request.user.id,
      storeId,
      role: membership.role,
    };
    request.user = {
      id: membership.store.id,
      phone: membership.store.phone,
      role: UserRole.SELLER,
      // Her session, not the owner's: a sign-out or revocation of her device
      // still ends her access.
      sessionId: request.user.sessionId,
      permissions: undefined,
    };
    return true;
  }
}
