import { applyDecorators, UseGuards } from '@nestjs/common';
import { Public } from './public.decorator';
import { OptionalJwtAuthGuard } from '../guards/optional-jwt-auth.guard';

/**
 * Public route that still resolves `req.user` when a valid token is present.
 * Skips the global JwtAuthGuard but layers optional authentication on top.
 */
export const OptionalAuth = () =>
  applyDecorators(Public(), UseGuards(OptionalJwtAuthGuard));
