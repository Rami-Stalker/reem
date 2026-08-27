import { UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { defaultPermissionsForRole } from '../role-permissions';

/**
 * The single place a principal's permissions are worked out.
 *
 * There were three copies of this — one in `TokenService` to mint the claim,
 * one in `AuthorizationService` to decide, one in a guard nothing ran — and
 * they had already drifted: only one of them honoured a `'*'` wildcard, so the
 * set that *decided* a request and the set that was *shown* to the client
 * could disagree. A permission model that answers a question differently
 * depending on who asks is not a permission model.
 *
 * Deliberately a function rather than a Nest provider: it is needed from a
 * module-scoped service and an app-scoped one, and making it injectable in
 * both places would mean a global module for four lines of query.
 */
export async function resolvePermissions(
  prisma: PrismaService,
  userId: string,
  role: UserRole,
): Promise<Set<string>> {
  const [rolePermissions, assignedRolePermissions] = await Promise.all([
    prisma.role.findUnique({
      where: { name: role },
      select: { permissions: { select: { permission: { select: { key: true } } } } },
    }),
    prisma.userRoleAssignment.findMany({
      where: {
        userId,
        // An assignment that has lapsed grants nothing. This is the clause the
        // token cache used to defeat: a permission could expire in the database
        // and still admit requests until the access token ran out.
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
      select: {
        role: {
          select: {
            permissions: { select: { permission: { select: { key: true } } } },
          },
        },
      },
    }),
  ]);

  const permissions = new Set<string>();
  rolePermissions?.permissions.forEach((entry) =>
    permissions.add(entry.permission.key),
  );
  assignedRolePermissions.forEach((assignment) =>
    assignment.role.permissions.forEach((entry) =>
      permissions.add(entry.permission.key),
    ),
  );

  // An unseeded RBAC table must not lock the platform out of itself, so the
  // code-level defaults stand in. They are a floor for an empty database, not
  // a supplement: if the table has rows for this role, the table wins.
  if (permissions.size === 0) {
    defaultPermissionsForRole(role).forEach((permission) =>
      permissions.add(permission),
    );
  }

  return permissions;
}
