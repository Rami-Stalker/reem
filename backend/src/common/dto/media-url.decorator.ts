import { applyDecorators } from '@nestjs/common';
import { IsUrl } from 'class-validator';

/**
 * A URL pointing at media this platform serves.
 *
 * Distinct from a plain `@IsUrl()` for one reason: `require_tld` defaults to
 * true, so `http://localhost:3000/media/files/…` — the URL this very API hands
 * back to a developer running the app on one machine — fails validation. The
 * upload succeeds, the URL comes back, and saving the product then rejects it.
 * IP hosts already pass, so the failure only ever appears on the desktop and
 * simulator targets, which is precisely where it is most confusing.
 *
 * Still strict about the parts that matter: an absolute `http`/`https` URL and
 * nothing else, so `javascript:` and `data:` remain unrepresentable in any
 * column a client later renders.
 */
export const MediaUrlField = (message?: string) =>
  applyDecorators(
    IsUrl(
      {
        require_tld: false,
        require_protocol: true,
        protocols: ['http', 'https'],
      },
      message ? { message } : undefined,
    ),
  );
