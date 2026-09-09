import {
  BadRequestException,
  CallHandler,
  ConflictException,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
  UnprocessableEntityException,
} from '@nestjs/common';
import { IdempotencyState, Prisma } from '@prisma/client';
import { Request, Response } from 'express';
import { createHash } from 'node:crypto';
import {
  Observable,
  catchError,
  concatMap,
  from,
  of,
  switchMap,
  throwError,
} from 'rxjs';

import { ConfigService } from '@nestjs/config';

import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../decorators/current-user.decorator';

export const IDEMPOTENCY_HEADER = 'idempotency-key';

/** How long a key answers for the request it named. */
const TTL_MS = 24 * 60 * 60 * 1000;

/** Keys longer than this are a client bug, not a key. */
const MAX_KEY_LENGTH = 200;

/**
 * A response bigger than this is not stored, and the replay says so rather
 * than lying. Nothing this interceptor guards returns anything near it.
 */
const MAX_STORED_BYTES = 256 * 1024;

const UNSAFE = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

/**
 * Makes a repeated unsafe request answer the same thing instead of doing it
 * again.
 *
 * **The failure this exists for.** Checkout is one request that creates an
 * order, claims stock from every seller in the basket, redeems a coupon and
 * starts a payment. On a Syrian mobile connection it can be in flight for
 * several seconds, and a woman who cannot tell whether it registered taps
 * again. She then has two orders: two stock claims against the same shelf, two
 * cash collections at her door, and a support conversation to unpick it. The
 * platform had no defence against this at all — the ledger was idempotent, the
 * delivery dispatch was idempotent, and the request that created the money was
 * not.
 *
 * **How it decides.** Inserting the record *is* the claim. `(scope, key)` is
 * unique, so exactly one concurrent attempt wins the insert and runs; the rest
 * get a unique violation, read the winner's row, and are answered from it.
 * That is the same shape as `claimStock` and for the same reason: a check
 * followed by a write is two moments, and under READ COMMITTED something can
 * happen in between.
 *
 * **Three answers, and each is deliberate:**
 *
 * - *Same key, same body, finished* → the stored response, with the status it
 *   originally returned. This is the double tap, and she sees her order.
 * - *Same key, same body, still running* → `409`. Replaying a half-finished
 *   request would be a guess; telling the client to wait is the truth.
 * - *Same key, different body* → `422`. This is a client bug, and answering it
 *   with the first response would silently discard a second real order.
 *
 * **Scope is the principal, never the key alone.** `user:<id>`, `guest:<id>`,
 * or `ip:<address>` for a caller with neither. Without it, one customer's key
 * could collide with another's, and a guessed key would read back somebody
 * else's order.
 *
 * **Opt-in by the client.** A request with no `Idempotency-Key` passes
 * straight through, so nothing that exists today breaks; the client sends one
 * where it matters. Making it mandatory is a later, separate decision — it
 * would refuse every install still running the previous version.
 */
@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  private readonly logger = new Logger(IdempotencyInterceptor.name);

  /**
   * Routes that refuse a request with no key at all.
   *
   * Empty until the app update carrying keys has reached the installs that
   * matter; see `configuration.ts`. Until then the protection is opt-in and
   * an old build still works.
   */
  private readonly required: ReadonlySet<string>;

  constructor(
    private readonly prisma: PrismaService,
    config?: ConfigService,
  ) {
    this.required = new Set(
      config?.get<string[]>('idempotency.requiredRoutes') ?? [],
    );
  }

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') return next.handle();

    const request = context
      .switchToHttp()
      .getRequest<Request & { user?: AuthUser; guest?: { id: string } }>();

    const key = this.keyOf(request);
    if (!UNSAFE.has(request.method)) return next.handle();

    const endpoint = `${request.method} ${request.route?.path ?? request.path}`;

    if (!key) {
      // Nothing to protect against, unless this route has been switched to
      // demanding one — at which point a client that does not send a key is
      // told plainly rather than quietly placing a duplicate order.
      if (!this.required.has(endpoint)) return next.handle();
      throw new BadRequestException({
        code: 'IDEMPOTENCY_KEY_REQUIRED',
        message: 'This request requires an Idempotency-Key header',
      });
    }

    const scope = this.scopeOf(request);
    const requestHash = this.hashOf(request.body);

    return from(this.claim({ key, scope, endpoint, requestHash })).pipe(
      switchMap((existing) => {
        if (existing) return of(existing);

        return next.handle().pipe(
          // The result is recorded **before** the response is delivered, not
          // alongside it. Fire-and-forget looked equivalent and was not: a
          // second tap arriving in the milliseconds between answering and
          // recording would find the record still `IN_FLIGHT` and be told to
          // wait for a request that had already succeeded.
          concatMap(async (body) => {
            const response = context.switchToHttp().getResponse<Response>();
            await this.complete(scope, key, response.statusCode, body);
            return body;
          }),
          // A failed request releases its key. Refusing to let her retry a
          // checkout that threw would be the opposite of helpful: the key
          // exists to stop a *successful* action happening twice, not to make
          // a failure permanent.
          catchError((error: unknown) =>
            from(this.abandon(scope, key)).pipe(
              concatMap(() => throwError(() => error)),
            ),
          ),
        );
      }),
    );
  }

  /**
   * Wins the right to run, or returns the answer somebody else already gave.
   *
   * The insert is the lock. There is no read-then-write here on purpose: two
   * taps arriving together would both read "no record" and both proceed.
   */
  private async claim(input: {
    key: string;
    scope: string;
    endpoint: string;
    requestHash: string;
  }): Promise<unknown | null> {
    // `INSERT ... ON CONFLICT DO NOTHING` rather than an insert that throws.
    //
    // Losing this race is the *expected* path — it is what a second tap looks
    // like — and letting Prisma raise a unique violation for it meant every
    // double tap printed `prisma:error` with a stack trace. Found by watching
    // the log of a live checkout: the guard was working perfectly and
    // reporting itself as a fault, which is how real errors get buried.
    //
    // Winning is "a row came back". No exception, no error line, one
    // round trip.
    const claimed = await this.prisma.$queryRaw<{ id: string }[]>`
      INSERT INTO idempotency_records
        (id, key, scope, endpoint, request_hash, state, expires_at, created_at)
      VALUES (
        gen_random_uuid(),
        ${input.key},
        ${input.scope},
        ${input.endpoint},
        ${input.requestHash},
        'IN_FLIGHT'::"IdempotencyState",
        ${new Date(Date.now() + TTL_MS)},
        now()
      )
      ON CONFLICT (scope, key) DO NOTHING
      RETURNING id
    `;
    if (claimed.length > 0) return null;

    const existing = await this.prisma.idempotencyRecord.findUnique({
      where: { scope_key: { scope: input.scope, key: input.key } },
    });
    // Expired between the insert failing and this read. Vanishingly rare, and
    // letting it run is the safe answer — the alternative is refusing a
    // request that has no record anywhere.
    if (!existing) return null;

    if (
      existing.endpoint !== input.endpoint ||
      existing.requestHash !== input.requestHash
    ) {
      throw new UnprocessableEntityException({
        code: 'IDEMPOTENCY_KEY_REUSED',
        message:
          'This idempotency key was already used for a different request',
      });
    }

    if (existing.state === IdempotencyState.IN_FLIGHT) {
      throw new ConflictException({
        code: 'IDEMPOTENCY_IN_FLIGHT',
        message: 'A request with this key is still being processed',
      });
    }

    if (existing.response === null || existing.response === undefined) {
      // Completed, but the body was too large to keep. Saying so is better
      // than replaying `null` as though that had been the answer.
      throw new ConflictException({
        code: 'IDEMPOTENCY_RESULT_UNAVAILABLE',
        message:
          'This request already completed, but its response is no longer available',
      });
    }

    return existing.response;
  }

  private async complete(
    scope: string,
    key: string,
    statusCode: number,
    body: unknown,
  ): Promise<void> {
    try {
      const serialised = this.storable(body);
      await this.prisma.idempotencyRecord.update({
        where: { scope_key: { scope, key } },
        data: {
          state: IdempotencyState.COMPLETED,
          statusCode,
          response: serialised,
          completedAt: new Date(),
        },
      });
    } catch (error) {
      // Recording the answer must never be the reason a customer's order
      // fails. The worst case is that a retry runs the request again, which is
      // exactly where the platform was before this existed.
      this.logger.warn(
        `Could not record the idempotent result for ${scope}: ${
          (error as Error).message
        }`,
      );
    }
  }

  private async abandon(scope: string, key: string): Promise<void> {
    await this.prisma.idempotencyRecord
      .deleteMany({
        where: { scope, key, state: IdempotencyState.IN_FLIGHT },
      })
      .catch(() => undefined);
  }

  private keyOf(request: Request): string | null {
    const raw = request.headers[IDEMPOTENCY_HEADER];
    const value = Array.isArray(raw) ? raw[0] : raw;
    const key = value?.trim();
    if (!key) return null;
    if (key.length > MAX_KEY_LENGTH) {
      throw new UnprocessableEntityException({
        code: 'IDEMPOTENCY_KEY_TOO_LONG',
        message: 'Idempotency key is too long',
      });
    }
    return key;
  }

  private scopeOf(
    request: Request & { user?: AuthUser; guest?: { id: string } },
  ): string {
    if (request.user?.id) return `user:${request.user.id}`;
    if (request.guest?.id) return `guest:${request.guest.id}`;
    // Neither, which is a public route. The address is a weak scope and that
    // is acceptable here: it is the same weakness the rate limiter already
    // runs on, and nothing behind a public route holds another woman's data.
    return `ip:${request.ip ?? 'unknown'}`;
  }

  /**
   * A stable fingerprint of the body.
   *
   * Keys are sorted, so `{a,b}` and `{b,a}` are the same request — two clients
   * serialising the same object differently must not read as a key reused for
   * something else.
   */
  private hashOf(body: unknown): string {
    return createHash('sha256')
      .update(JSON.stringify(this.canonical(body)))
      .digest('hex');
  }

  private canonical(value: unknown): unknown {
    if (Array.isArray(value)) return value.map((item) => this.canonical(item));
    if (value && typeof value === 'object') {
      return Object.fromEntries(
        Object.entries(value as Record<string, unknown>)
          .sort(([left], [right]) => left.localeCompare(right))
          .map(([name, item]) => [name, this.canonical(item)]),
      );
    }
    return value ?? null;
  }

  private storable(body: unknown): Prisma.InputJsonValue | undefined {
    if (body === undefined || body === null) return undefined;
    const serialised = JSON.stringify(body);
    if (!serialised || Buffer.byteLength(serialised) > MAX_STORED_BYTES) {
      return undefined;
    }
    return JSON.parse(serialised) as Prisma.InputJsonValue;
  }

}
