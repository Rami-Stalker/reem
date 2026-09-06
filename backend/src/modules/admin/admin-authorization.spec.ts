import assert from 'node:assert/strict';
import test from 'node:test';
import 'reflect-metadata';
import { UserRole } from '@prisma/client';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { AUTHORIZATION_POLICIES_KEY } from '../../common/decorators/authorize.decorator';
import { AuthorizationPolicy } from '../../common/authorization/authorization.types';
import { defaultPermissionsForRole } from '../../common/role-permissions';
import { AdminController } from './admin.controller';

/**
 * The console is guarded twice — a role list on the controller and a permission
 * on each route — and the guard requires *both*. That is a good design with one
 * failure mode: a staff role that holds the permission but is missing from the
 * role list is locked out of the whole console with no error anywhere except a
 * 403 the operator sees. That is exactly what had happened to four of the seven
 * staff roles, so these tests pin the invariant rather than the list.
 */

const staffRoles: UserRole[] = [
  UserRole.SUPER_ADMIN,
  UserRole.ADMIN,
  UserRole.OPERATIONS_ADMIN,
  UserRole.SUPPORT_ADMIN,
  UserRole.FINANCE_ADMIN,
  UserRole.CONTENT_MODERATOR,
  UserRole.SUPPORT,
];

function controllerRoles(): UserRole[] {
  return (Reflect.getMetadata(ROLES_KEY, AdminController) ?? []) as UserRole[];
}

function routePolicies(): { handler: string; policy: AuthorizationPolicy }[] {
  const prototype = AdminController.prototype as unknown as Record<
    string,
    unknown
  >;
  const handlers = Object.getOwnPropertyNames(prototype).filter(
    (name) => name !== 'constructor' && typeof prototype[name] === 'function',
  );

  return handlers.flatMap((handler) => {
    const policies = (Reflect.getMetadata(
      AUTHORIZATION_POLICIES_KEY,
      prototype[handler] as object,
    ) ?? []) as AuthorizationPolicy[];
    return policies.map((policy) => ({ handler, policy }));
  });
}

test('every staff role may reach the admin controller', () => {
  const roles = controllerRoles();

  for (const role of staffRoles) {
    assert.ok(
      roles.includes(role),
      `${role} is routed to the admin console by the client but the ` +
        'controller refuses it before any permission is consulted',
    );
  }
});

test('the admin controller admits no role that is not staff', () => {
  const roles = controllerRoles();

  assert.equal(roles.includes(UserRole.SELLER), false);
  assert.equal(roles.includes(UserRole.CUSTOMER), false);
});

test('every admin route names a permission some staff role holds', () => {
  const roles = controllerRoles();
  const held = new Set(
    roles.flatMap((role) => defaultPermissionsForRole(role)),
  );

  for (const { handler, policy } of routePolicies()) {
    assert.ok(
      policy.permissions?.length,
      `${handler} declares no permission, so the controller's role list is ` +
        'the only thing standing between it and every staff member',
    );
    for (const permission of policy.permissions ?? []) {
      assert.ok(
        held.has(permission),
        `${handler} requires ${permission}, which no role on this ` +
          'controller holds — the route can never be called',
      );
    }
  }
});

test('a support agent can work the support queue and nothing financial', () => {
  const support = new Set(defaultPermissionsForRole(UserRole.SUPPORT));
  const byHandler = new Map(
    routePolicies().map(({ handler, policy }) => [handler, policy]),
  );

  const canCall = (handler: string) =>
    (byHandler.get(handler)?.permissions ?? []).every((permission) =>
      support.has(permission),
    );

  assert.ok(canCall('support'));
  assert.ok(canCall('updateSupport'));
  assert.equal(canCall('financials'), false);
  assert.equal(canCall('createCommissionRule'), false);
});

test('the accountant can read the money screens', () => {
  const finance = new Set(defaultPermissionsForRole(UserRole.FINANCE_ADMIN));
  const byHandler = new Map(
    routePolicies().map(({ handler, policy }) => [handler, policy]),
  );

  const canCall = (handler: string) =>
    (byHandler.get(handler)?.permissions ?? []).every((permission) =>
      finance.has(permission),
    );

  assert.ok(canCall('financials'));
  assert.ok(canCall('commissions'));
  assert.ok(canCall('createCommissionRule'));
  // Reading a woman's support conversation is not the accountant's job.
  assert.equal(canCall('support'), false);
});
