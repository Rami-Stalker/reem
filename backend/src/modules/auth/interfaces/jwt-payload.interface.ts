import { UserRole } from '@prisma/client';

/** Claims embedded in the access token. */
export interface JwtPayload {
  sub: string;
  phone: string | null;
  role: UserRole;
  sid?: string;
  permissions?: string[];
}
