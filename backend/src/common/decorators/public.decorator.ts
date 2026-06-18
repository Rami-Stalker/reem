import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/** Marks a route as public so the global JwtAuthGuard is skipped. */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
