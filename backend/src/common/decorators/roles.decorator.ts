import { SetMetadata } from '@nestjs/common';
import { UserRole } from '@prisma/client';

export const ROLES_KEY = 'roles';

/**
 * Restrict a route (or controller) to the given roles.
 *
 * Enforced by the global `AuthorizationGuard`, which merges this into whatever
 * `@Authorize(...)` policies the handler declares. There is no separate roles
 * guard — one existed, was never registered, and had drifted out of step with
 * the guard that actually runs.
 */
export const Roles = (...roles: UserRole[]) => SetMetadata(ROLES_KEY, roles);
