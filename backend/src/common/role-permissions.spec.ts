import assert from 'node:assert/strict';
import test from 'node:test';
import { UserRole } from '@prisma/client';
import { AppPermission } from './permissions';
import { defaultPermissionsForRole } from './role-permissions';

test('admin fallback permissions allow dashboard access', () => {
  const permissions = defaultPermissionsForRole(UserRole.ADMIN);

  assert.ok(permissions.includes(AppPermission.adminDashboard));
  assert.ok(permissions.includes(AppPermission.userManage));
});

test('customer fallback permissions stay scoped to customer workflows', () => {
  const permissions = defaultPermissionsForRole(UserRole.CUSTOMER);

  assert.ok(permissions.includes(AppPermission.checkoutCreate));
  assert.equal(permissions.includes(AppPermission.adminDashboard), false);
});
