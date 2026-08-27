import { SetMetadata } from '@nestjs/common';
import { AuthorizationPolicy } from '../authorization/authorization.types';

export const AUTHORIZATION_POLICIES_KEY = 'authorization:policies';

export const Authorize = (...policies: AuthorizationPolicy[]) =>
  SetMetadata(AUTHORIZATION_POLICIES_KEY, policies);
