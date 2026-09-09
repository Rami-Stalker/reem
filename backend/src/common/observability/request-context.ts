import { AsyncLocalStorage } from 'node:async_hooks';
import { randomBytes } from 'node:crypto';

/** What every log line written while serving one request can reach. */
export interface RequestContext {
  /** Short, readable, and safe to show a customer on an error screen. */
  readonly requestId: string;
  readonly method: string;
  /** The route *pattern* where one is known, so ids do not fan the logs out. */
  readonly route: string;
  readonly userId?: string;
  readonly role?: string;
  readonly startedAt: number;
}

/**
 * The request a line of work belongs to, carried without threading it through
 * every signature.
 *
 * `AsyncLocalStorage` and not a parameter, deliberately: the alternative is a
 * context argument on every service method in the platform, which is a change
 * to a thousand call sites in exchange for the same information. The cost is
 * that it is invisible at the call site — which is why nothing *depends* on it
 * being present. A logger with no context still logs; it simply cannot say
 * which request it was.
 */
const storage = new AsyncLocalStorage<RequestContext>();

/**
 * A short id a woman can read off an error screen and a support agent can
 * paste into a log search.
 *
 * Ten hex characters, not a UUID: the point is that somebody can read it aloud
 * over the phone. It identifies a request, not a person, and carries nothing —
 * so it is safe to show, safe to log, and useless to anyone who does not also
 * have the logs.
 */
export function newRequestId(): string {
  return randomBytes(5).toString('hex');
}

export function runWithRequestContext<T>(
  context: RequestContext,
  work: () => T,
): T {
  return storage.run(context, work);
}

export function currentRequestContext(): RequestContext | undefined {
  return storage.getStore();
}

/** The id alone, for the places that only need something to print. */
export function currentRequestId(): string | undefined {
  return storage.getStore()?.requestId;
}
