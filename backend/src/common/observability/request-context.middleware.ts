import { Injectable, NestMiddleware } from '@nestjs/common';
import { NextFunction, Request, Response } from 'express';

import { AuthUser } from '../decorators/current-user.decorator';
import {
  RequestContext,
  newRequestId,
  runWithRequestContext,
} from './request-context';

/** Accepted from a trusted caller so a trace survives a hop. */
const INBOUND_HEADER = 'x-request-id';
const OUTBOUND_HEADER = 'X-Request-Id';

/** Long enough to be an id, short enough not to be a payload. */
const MAX_INBOUND_LENGTH = 64;

/**
 * Gives every request a name, and puts it on the response.
 *
 * The id is minted **before** anything else runs so that a failure in a guard
 * — an expired session, a refused permission — is still attributable. It goes
 * out on the response header and into the error body, so the woman looking at
 * "something went wrong" is holding the string that finds her request in the
 * logs.
 *
 * An inbound `X-Request-Id` is honoured when it looks like an id, because a
 * reverse proxy or a future service hop should be able to keep one trace. It
 * is sanitised rather than trusted: the value is echoed into logs and a header,
 * and anything that is not a short alphanumeric string is replaced rather than
 * carried.
 *
 * **The user is attached later, not here.** Middleware runs before the guards,
 * so `request.user` does not exist yet; the context object is mutable in that
 * one field and the auth guard fills it in. That is why `userId` is optional
 * on every log line rather than assumed.
 */
@Injectable()
export class RequestContextMiddleware implements NestMiddleware {
  use(request: Request, response: Response, next: NextFunction): void {
    const context: RequestContext & { userId?: string; role?: string } = {
      requestId: this.idFor(request),
      method: request.method,
      // The pattern is not resolved until routing has run, so this starts as
      // the path and is narrowed by the interceptor once the handler is known.
      route: request.path,
      startedAt: Date.now(),
    };

    response.setHeader(OUTBOUND_HEADER, context.requestId);
    // Hung on the request too, so the exception filter can reach it without
    // depending on async-local storage surviving whatever threw.
    (request as Request & { requestContext?: RequestContext }).requestContext =
      context;

    runWithRequestContext(context, () => next());
  }

  private idFor(request: Request): string {
    const raw = request.headers[INBOUND_HEADER];
    const value = Array.isArray(raw) ? raw[0] : raw;
    if (
      value &&
      value.length <= MAX_INBOUND_LENGTH &&
      /^[A-Za-z0-9._-]+$/.test(value)
    ) {
      return value;
    }
    return newRequestId();
  }
}

/**
 * Fills in who was making the request, once the guards have decided.
 *
 * Separate from the middleware because the answer does not exist when the
 * middleware runs. Called from the auth guard, which is the first place that
 * knows.
 */
export function attachPrincipalToContext(
  request: Request & { user?: AuthUser; requestContext?: RequestContext },
): void {
  const context = request.requestContext as
    | (RequestContext & { userId?: string; role?: string })
    | undefined;
  if (!context || !request.user) return;
  context.userId = request.user.id;
  context.role = request.user.role;
}
