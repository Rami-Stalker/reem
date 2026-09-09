import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { AuditSeverity, Prisma, UserRole } from '@prisma/client';
import { Request } from 'express';
import { Observable, catchError, tap, throwError } from 'rxjs';

import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../decorators/current-user.decorator';

const MUTATING = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

const STAFF: ReadonlySet<UserRole> = new Set([
  UserRole.SUPER_ADMIN,
  UserRole.OPERATIONS_ADMIN,
  UserRole.SUPPORT_ADMIN,
  UserRole.FINANCE_ADMIN,
  UserRole.CONTENT_MODERATOR,
  UserRole.ADMIN,
  UserRole.SUPPORT,
]);

/**
 * Body fields that must never reach the audit trail, whatever route carries
 * them. Matched case-insensitively as substrings, so `new_password` and
 * `refreshToken` are both caught.
 */
const NEVER_RECORD = [
  'password',
  'token',
  'secret',
  'code',
  'otp',
  'pin',
  'key',
  'signature',
  'authorization',
];

/**
 * Every write a member of staff makes, recorded without anyone remembering to.
 *
 * **Why an interceptor and not a call in each service.** Twelve services wrote
 * audit entries. The admin write surface is several times that — delivery
 * providers, experiments, flash sales, search synonyms, value policies,
 * notification campaigns, commission rules, moderation queues, trend
 * recomputation — and every one of them was a place somebody had to remember.
 * A trail with holes in it is worse than no trail, because it is read as
 * complete. Coverage that depends on nobody forgetting is not coverage.
 *
 * **What is recorded.** The actor, the route, the outcome, and *what was acted
 * on* — the route's own id parameter, which is what makes "show me everything
 * that happened to this order" answerable at all. The body's **field names**
 * go in the metadata; its values do not. That is deliberate: an audit trail
 * that copies request bodies becomes a second, unguarded store of every
 * customer's address and every seller's bank details, and the money trail that
 * genuinely needs amounts already has one in `FinancialAuditService`.
 *
 * **Failures are recorded too**, and at a higher severity — a refused attempt
 * to reach a payout screen is worth more to an investigation than a successful
 * one. The refusal it sees is the one thrown *inside* a handler, which is
 * where this platform's ownership checks live (`assertMayIssue`,
 * `requireCourier`, and their kin). A request `AuthorizationGuard` turns away
 * never reaches an interceptor at all — guards run first — and that denial is
 * already written to `SecurityEvent` by the guard. The two together are the
 * trail; neither alone is.
 *
 * Writing the entry never blocks the response and never fails the request: an
 * audit record that costs a support agent her action would be turned off
 * within a week.
 */
@Injectable()
export class AdminAuditInterceptor implements NestInterceptor {
  private readonly logger = new Logger(AdminAuditInterceptor.name);

  constructor(private readonly prisma: PrismaService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') return next.handle();

    const request = context
      .switchToHttp()
      .getRequest<Request & { user?: AuthUser }>();

    if (!this.shouldRecord(request)) return next.handle();

    return next.handle().pipe(
      tap(() => void this.record(request, 'SUCCESS', AuditSeverity.INFO)),
      catchError((error: unknown) => {
        const status = (error as { status?: number })?.status ?? 500;
        void this.record(
          request,
          `FAILED_${status}`,
          // A refused write by somebody holding a staff role is either a
          // misconfigured permission or somebody probing. Either is worth
          // finding in a list of its own.
          status === 401 || status === 403
            ? AuditSeverity.WARNING
            : AuditSeverity.INFO,
        );
        return throwError(() => error);
      }),
    );
  }

  /**
   * Staff writes only.
   *
   * A customer changing her own address is not an audit event — it is her
   * data, she is entitled to it, and recording every one of them would bury
   * the entries that matter under the ordinary use of the app.
   */
  private shouldRecord(request: Request & { user?: AuthUser }): boolean {
    if (!MUTATING.has(request.method)) return false;
    const role = request.user?.role;
    return Boolean(role && STAFF.has(role));
  }

  private async record(
    request: Request & { user?: AuthUser },
    outcome: string,
    severity: AuditSeverity,
  ): Promise<void> {
    try {
      const route = request.route?.path ?? request.path;
      const target = this.targetOf(request, route);

      await this.prisma.auditLog.create({
        data: {
          actorId: request.user?.id ?? null,
          action: `${request.method} ${route}`,
          category: this.categoryOf(route),
          outcome,
          severity,
          targetType: target.type,
          targetId: target.id,
          ipAddress: request.ip ?? null,
          userAgent: request.headers['user-agent'] ?? null,
          metadata: {
            path: request.path,
            params: this.safeParams(request),
            // Names, never values. See the class comment.
            fields: this.fieldNames(request.body),
          } as Prisma.InputJsonValue,
        },
      });
    } catch (error) {
      // Never the reason an action fails. A dropped audit line is a gap; a
      // support agent who cannot resolve a ticket is an outage.
      this.logger.warn(
        `Could not record an audit entry for ${request.method} ${request.path}: ${
          (error as Error).message
        }`,
      );
    }
  }

  /**
   * What the route acted on.
   *
   * Read from the route pattern rather than the URL, so `/admin/sellers/:id`
   * yields `seller` and the concrete id — the pair the forensic index is built
   * on. A route with several ids (`/admin/.../:id/items/:itemId`) reports the
   * innermost, which is the thing that actually changed.
   */
  private targetOf(
    request: Request,
    route: string,
  ): { type: string | null; id: string | null } {
    const params = (request.params ?? {}) as Record<string, string>;
    const names = Object.keys(params);
    if (names.length === 0) return { type: this.resourceOf(route), id: null };

    const name = names[names.length - 1];
    return {
      type: this.resourceOf(route, name),
      id: params[name] ?? null,
    };
  }

  /**
   * The resource a route names — `/admin/delivery/providers/:id` → `provider`.
   *
   * Taken from the last path segment before the parameter, singularised
   * crudely. It is a label for grouping, not an identifier, so "close enough
   * to search by" is the bar it has to clear.
   */
  private resourceOf(route: string, paramName?: string): string | null {
    const segments = route.split('/').filter(Boolean);
    const marker = paramName ? `:${paramName}` : null;
    const index = marker ? segments.indexOf(marker) : segments.length;
    const noun = segments
      .slice(0, index === -1 ? segments.length : index)
      .reverse()
      .find((segment) => !segment.startsWith(':'));
    if (!noun) return null;
    return noun.endsWith('ies')
      ? `${noun.slice(0, -3)}y`
      : noun.endsWith('s')
        ? noun.slice(0, -1)
        : noun;
  }

  private categoryOf(route: string): string {
    const first = route.split('/').filter(Boolean)[0] ?? 'api';
    return first.startsWith(':') ? 'api' : first;
  }

  /** Route params are ids the caller already knows; values are safe here. */
  private safeParams(request: Request): Record<string, string> {
    return { ...((request.params ?? {}) as Record<string, string>) };
  }

  /**
   * Which fields a write touched, without their values.
   *
   * Enough to answer "did she change the commission rate or only its label",
   * and not enough to turn the audit table into a copy of every address book
   * and bank detail on the platform. Anything that looks like a credential is
   * dropped even as a name, because a field called `new_password` appearing in
   * a log is itself a hint worth not giving.
   */
  private fieldNames(body: unknown): string[] {
    if (!body || typeof body !== 'object' || Array.isArray(body)) return [];
    return Object.keys(body as Record<string, unknown>)
      .filter(
        (name) =>
          !NEVER_RECORD.some((banned) => name.toLowerCase().includes(banned)),
      )
      .sort();
  }
}
