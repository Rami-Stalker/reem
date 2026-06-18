import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { UserRole } from '@prisma/client';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import { AuthUser } from '../decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Authorises a request against the roles declared with @Roles(). Must run after
 * the JwtAuthGuard so that `request.user` is populated.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const required = this.reflector.getAllAndOverride<UserRole[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (
      (!required || required.length === 0) &&
      (!requiredPermissions || requiredPermissions.length === 0)
    ) {
      return true;
    }

    const user: AuthUser | undefined = context.switchToHttp().getRequest().user;
    if (!user) {
      throw new ForbiddenException('You do not have permission to perform this action');
    }

    if (user.role === UserRole.SUPER_ADMIN) return true;

    if (required?.length && !required.includes(user.role)) {
      throw new ForbiddenException('You do not have permission to perform this action');
    }

    if (requiredPermissions?.length) {
      const actual = await this.permissionsFor(user);
      const allowed = requiredPermissions.every((permission) =>
        actual.has(permission),
      );
      if (!allowed) {
        throw new ForbiddenException('You do not have permission to perform this action');
      }
    }

    return true;
  }

  private async permissionsFor(user: AuthUser): Promise<Set<string>> {
    const permissions = new Set(user.permissions ?? []);
    if (permissions.size > 0) return permissions;

    const [rolePermissions, assignedRolePermissions] = await Promise.all([
      this.prisma.role.findUnique({
        where: { name: user.role },
        select: {
          permissions: {
            select: { permission: { select: { key: true } } },
          },
        },
      }),
      this.prisma.userRoleAssignment.findMany({
        where: {
          userId: user.id,
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

    rolePermissions?.permissions.forEach((entry) =>
      permissions.add(entry.permission.key),
    );
    assignedRolePermissions.forEach((assignment) =>
      assignment.role.permissions.forEach((entry) =>
        permissions.add(entry.permission.key),
      ),
    );

    return permissions;
  }
}
