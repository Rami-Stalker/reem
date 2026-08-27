import assert from 'node:assert/strict';
import test from 'node:test';
import { UserRole } from '@prisma/client';
import { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { AppPermission } from '../permissions';
import { AuthUser } from '../decorators/current-user.decorator';
import { Roles, ROLES_KEY } from '../decorators/roles.decorator';
import { Authorize } from '../decorators/authorize.decorator';
import { AuthorizationService } from './authorization.service';
import { AuthorizationGuard } from './authorization.guard';

/**
 * The five properties the authorization layer was found not to have.
 *
 * Each test here corresponds to something that was actually wrong, and would
 * pass vacuously against the old code only in the sense that the old code
 * never asked the question. They are written against behaviour, not
 * implementation, so a future refactor is free to change how — not whether.
 */

function principal(role: UserRole, permissions: string[] = []): AuthUser {
  return { id: 'user-1', phone: '+963900000001', role, permissions };
}

/** A Prisma double whose RBAC tables answer with whatever the test needs. */
function prismaWith(options: {
  rolePermissions?: string[];
  assignments?: string[][];
  owner?: string | null;
  onQuery?: () => void;
}) {
  const { rolePermissions, assignments = [], owner = null, onQuery } = options;
  const rows = (keys: string[]) =>
    keys.map((key) => ({ permission: { key } }));

  return {
    role: {
      findUnique: async () => {
        onQuery?.();
        return rolePermissions
          ? { permissions: rows(rolePermissions) }
          : null;
      },
    },
    userRoleAssignment: {
      findMany: async () =>
        assignments.map((keys) => ({ role: { permissions: rows(keys) } })),
    },
    wishlistCollection: {
      findUnique: async () => (owner === null ? null : { userId: owner }),
    },
    order: {
      findUnique: async () => (owner === null ? null : { userId: owner }),
    },
    post: {
      findUnique: async () => (owner === null ? null : { authorId: owner }),
    },
  } as never;
}

const request = (params: Record<string, string> = {}) =>
  ({ params }) as unknown as Request;

// ── 1. Permissions are resolved live, never read off the token ────────────

test('a permission that is not in the database is refused, however good the token looks', async () => {
  // The claim says she may review recoveries. The database says her role holds
  // nothing of the sort — which is what a revocation looks like a moment after
  // it happens, and what a forged-but-unverified claim would look like too.
  const service = new AuthorizationService(
    prismaWith({ rolePermissions: [AppPermission.accountRead] }),
  );

  const allowed = await service.can(
    principal(UserRole.SUPPORT, [AppPermission.accountRecoveryReview]),
    {
      action: 'update',
      resource: 'account',
      permissions: [AppPermission.accountRecoveryReview],
    },
    request(),
  );

  assert.equal(allowed, false);
});

test('a permission granted only by a role assignment is honoured', async () => {
  const service = new AuthorizationService(
    prismaWith({
      rolePermissions: [AppPermission.accountRead],
      assignments: [[AppPermission.securityForensicsRead]],
    }),
  );

  assert.equal(
    await service.can(
      principal(UserRole.SUPPORT),
      {
        action: 'read',
        resource: 'audit',
        permissions: [AppPermission.securityForensicsRead],
      },
      request(),
    ),
    true,
  );
});

test('the resolved set is looked up once per request, not once per policy', async () => {
  let queries = 0;
  const service = new AuthorizationService(
    prismaWith({
      rolePermissions: [AppPermission.accountRead],
      onQuery: () => (queries += 1),
    }),
  );

  const req = request();
  const policy = {
    action: 'read',
    resource: 'account' as const,
    permissions: [AppPermission.accountRead],
  };
  await service.can(principal(UserRole.CUSTOMER), policy, req);
  await service.can(principal(UserRole.CUSTOMER), policy, req);

  assert.equal(queries, 1, 'the second policy should reuse the request memo');
});

// ── 2. Ownership bypass is per resource, not per staff badge ──────────────

test('a content moderator may take down a post she did not write', async () => {
  const service = new AuthorizationService(prismaWith({ owner: 'someone-else' }));

  assert.equal(
    await service.can(
      principal(UserRole.CONTENT_MODERATOR),
      {
        action: 'delete',
        resource: 'post',
        ownership: { resource: 'post' },
      },
      request({ id: 'post-1' }),
    ),
    true,
  );
});

test('a content moderator may NOT read a customer order', async () => {
  // Moderation is posts and stories. An order is somebody's home address and
  // what she bought; there is no moderation reason to open it.
  const service = new AuthorizationService(prismaWith({ owner: 'someone-else' }));

  assert.equal(
    await service.can(
      principal(UserRole.CONTENT_MODERATOR),
      {
        action: 'read',
        resource: 'order',
        ownership: { resource: 'order' },
      },
      request({ id: 'order-1' }),
    ),
    false,
  );
});

test('no staff role reaches another woman’s wishlist', async () => {
  const service = new AuthorizationService(prismaWith({ owner: 'someone-else' }));
  const policy = {
    action: 'read',
    resource: 'wishlist' as const,
    ownership: { resource: 'wishlistCollection' as const },
  };

  for (const role of [
    UserRole.OPERATIONS_ADMIN,
    UserRole.SUPPORT_ADMIN,
    UserRole.SUPPORT,
    UserRole.FINANCE_ADMIN,
    UserRole.CONTENT_MODERATOR,
    UserRole.ADMIN,
  ]) {
    assert.equal(
      await service.can(principal(role), policy, request({ id: 'list-1' })),
      false,
      `${role} should not read a wishlist it does not own`,
    );
  }
});

test('the owner still reaches her own wishlist', async () => {
  const service = new AuthorizationService(prismaWith({ owner: 'user-1' }));

  assert.equal(
    await service.can(
      principal(UserRole.CUSTOMER),
      {
        action: 'read',
        resource: 'wishlist',
        ownership: { resource: 'wishlistCollection' },
      },
      request({ id: 'list-1' }),
    ),
    true,
  );
});

// ── 3. @Authorize narrows @Roles; it does not replace it ─────────────────

@Roles(UserRole.ADMIN, UserRole.SUPPORT)
class GuardedController {
  @Authorize({
    action: 'read',
    resource: 'audit',
    permissions: [AppPermission.securityForensicsRead],
  })
  read(): void {}

  @Authorize({
    action: 'read',
    resource: 'audit',
    roles: [UserRole.FINANCE_ADMIN],
    permissions: [AppPermission.financeRead],
  })
  narrowed(): void {}
}

function contextFor(method: 'read' | 'narrowed'): ExecutionContext {
  return {
    getHandler: () => GuardedController.prototype[method],
    getClass: () => GuardedController,
  } as unknown as ExecutionContext;
}

/** Reaches the private method under test without loosening its visibility. */
function policiesOf(method: 'read' | 'narrowed') {
  const guard = new AuthorizationGuard(
    new Reflector(),
    undefined as never,
    undefined as never,
    undefined as never,
  );
  return (
    guard as unknown as {
      policiesFor: (context: ExecutionContext) => { roles?: UserRole[] }[];
    }
  ).policiesFor(contextFor(method));
}

test('a policy that names no roles inherits the controller’s restriction', () => {
  const [policy] = policiesOf('read');
  assert.deepEqual(policy.roles, [UserRole.ADMIN, UserRole.SUPPORT]);
});

test('a policy that names its own roles keeps them — narrowing is deliberate', () => {
  const [policy] = policiesOf('narrowed');
  assert.deepEqual(policy.roles, [UserRole.FINANCE_ADMIN]);
});

test('the roles decorator still records what it always did', () => {
  const recorded = Reflect.getMetadata(ROLES_KEY, GuardedController);
  assert.deepEqual(recorded, [UserRole.ADMIN, UserRole.SUPPORT]);
});

// ── 4. A role outside the inherited restriction is refused ───────────────

test('a seller holding the right permission is still refused a staff route', async () => {
  // The belt-and-braces case the merge exists for: if a permission were ever
  // granted to a non-staff role by mistake, the declared role list still holds.
  const service = new AuthorizationService(
    prismaWith({ rolePermissions: [AppPermission.securityForensicsRead] }),
  );

  assert.equal(
    await service.can(
      principal(UserRole.SELLER),
      {
        action: 'read',
        resource: 'audit',
        roles: [UserRole.ADMIN, UserRole.SUPPORT],
        permissions: [AppPermission.securityForensicsRead],
      },
      request(),
    ),
    false,
  );
});
