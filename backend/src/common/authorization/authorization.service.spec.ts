import assert from 'node:assert/strict';
import test from 'node:test';
import { UserRole } from '@prisma/client';
import { Request } from 'express';
import { AppPermission } from '../permissions';
import { AuthUser } from '../decorators/current-user.decorator';
import { AuthorizationService } from './authorization.service';

const prismaWithoutRoleRows = {
  role: {
    findUnique: async () => null,
  },
  userRoleAssignment: {
    findMany: async () => [],
  },
};

function user(role: UserRole): AuthUser {
  return {
    id: 'user-1',
    phone: '+966500000001',
    role,
    permissions: [],
  };
}

test('authorization falls back to default admin permissions when RBAC rows are empty', async () => {
  const service = new AuthorizationService(prismaWithoutRoleRows as never);

  assert.equal(
    await service.can(
      user(UserRole.ADMIN),
      {
        action: 'read',
        resource: 'admin',
        permissions: [AppPermission.adminDashboard],
      },
      {} as Request,
    ),
    true,
  );
});

test('authorization fallback does not grant admin permissions to customers', async () => {
  const service = new AuthorizationService(prismaWithoutRoleRows as never);

  assert.equal(
    await service.can(
      user(UserRole.CUSTOMER),
      {
        action: 'read',
        resource: 'admin',
        permissions: [AppPermission.adminDashboard],
      },
      {} as Request,
    ),
    false,
  );
});
