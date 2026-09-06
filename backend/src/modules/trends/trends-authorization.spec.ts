import assert from 'node:assert/strict';
import test from 'node:test';
import { Reflector } from '@nestjs/core';
import { UserRole } from '@prisma/client';

import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { PERMISSIONS_KEY } from '../../common/decorators/permissions.decorator';
import { AppPermission } from '../../common/permissions';
import { defaultPermissionsForRole } from '../../common/role-permissions';
import { TrendsController } from './trends.controller';

/**
 * `analytics:read` is a permission a seller legitimately holds — it is how she
 * reads her own shop's numbers. The `admin/*` handlers were gated on that
 * permission and nothing else, so the permission that means "your shop" also
 * opened the surface that means "every shop": a self-registered seller could
 * read every competitor's revenue, growth, cancel rate and stock.
 *
 * These cases pin the two halves of the fix. They resolve metadata exactly the
 * way `AuthorizationGuard.policiesFor` does — `getAllAndOverride`, handler
 * before class — so they fail if the class-level guard is removed *or* if a
 * seller handler stops overriding it.
 */

const reflector = new Reflector();

const STAFF = [
  UserRole.SUPER_ADMIN,
  UserRole.ADMIN,
  UserRole.OPERATIONS_ADMIN,
  UserRole.FINANCE_ADMIN,
];

/** Every handler on the controller, paired with the roles the guard will read. */
function handlers(): Array<{ name: string; roles: UserRole[] | undefined }> {
  const proto = TrendsController.prototype as unknown as Record<string, unknown>;
  return Object.getOwnPropertyNames(proto)
    .filter((name) => name !== 'constructor')
    .filter((name) => typeof proto[name] === 'function')
    .map((name) => ({
      name,
      roles: reflector.getAllAndOverride<UserRole[]>(ROLES_KEY, [
        proto[name] as () => unknown,
        TrendsController,
      ]),
    }));
}

test('a seller is not admitted to any handler gated only by a permission', () => {
  const proto = TrendsController.prototype as unknown as Record<string, unknown>;

  for (const { name, roles } of handlers()) {
    const permissions = reflector.getAllAndOverride<string[]>(PERMISSIONS_KEY, [
      proto[name] as () => unknown,
      TrendsController,
    ]);
    if (!permissions?.length) continue;

    assert.ok(
      roles?.length,
      `${name} is gated on ${permissions.join(', ')} with no role — a seller holding that permission would pass`,
    );
    assert.equal(
      roles.includes(UserRole.SELLER),
      false,
      `${name} admits SELLER to a permission-gated admin route`,
    );
  }
});

test('the seller handlers still override the class-level staff gate', () => {
  const sellerHandlers = handlers().filter(({ roles }) =>
    roles?.includes(UserRole.SELLER),
  );

  assert.equal(
    sellerHandlers.length,
    6,
    'expected the six seller-facing trend handlers to remain seller-scoped',
  );
  for (const { name, roles } of sellerHandlers) {
    assert.deepEqual(
      roles,
      [UserRole.SELLER],
      `${name} should be seller-only, not widened by the class gate`,
    );
  }
});

test('the class gate names only roles that actually hold analytics:read', () => {
  const classRoles = reflector.get<UserRole[]>(ROLES_KEY, TrendsController);

  assert.deepEqual(classRoles, STAFF);
  for (const role of classRoles) {
    if (role === UserRole.SUPER_ADMIN) continue; // holds everything by definition
    assert.ok(
      defaultPermissionsForRole(role).includes(AppPermission.analyticsRead),
      `${role} is on the trends admin gate but does not hold analytics:read`,
    );
  }
});

test('the permission alone is still not staff-only — which is why the gate is needed', () => {
  // If this ever stops being true the class gate can go; until then it is the
  // only thing separating a seller from the platform's numbers.
  assert.ok(
    defaultPermissionsForRole(UserRole.SELLER).includes(AppPermission.analyticsRead),
    'sellers no longer hold analytics:read — revisit the class-level @Roles',
  );
});
