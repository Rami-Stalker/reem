import { ForbiddenException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { AuthUser } from './decorators/current-user.decorator';

/**
 * Ownership gate for seller-managed content. Admins may manage anything
 * (moderation); otherwise the actor must own the resource. Centralising this
 * keeps the seller-vs-customer business rule consistent and server-enforced.
 */
export function assertCanManage(ownerId: string, user: AuthUser): void {
  const managerRoles: UserRole[] = [
    UserRole.SUPER_ADMIN,
    UserRole.OPERATIONS_ADMIN,
    UserRole.CONTENT_MODERATOR,
    UserRole.ADMIN,
  ];
  if (managerRoles.includes(user.role)) {
    return;
  }
  if (user.id !== ownerId) {
    throw new ForbiddenException('You can only manage your own content');
  }
}
