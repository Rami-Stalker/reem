import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { AuditSeverity, Prisma, UserRole } from '@prisma/client';
import { Observable, catchError, tap, throwError } from 'rxjs';

import { PrismaService } from '../../prisma/prisma.service';
import { DelegatedRequest } from './store-delegation.guard';

const MUTATING = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

/** The shop's own write surface — what «سجل النشاط» is about. */
const SHOP_ROUTES = [
  '/seller/',
  '/finance/seller/',
  '/returns/',
  '/promotions',
  '/ads/',
  '/reputation/seller/',
  '/content',
];

/**
 * «سجل النشاط» — every change made to a shop, by her or by her team,
 * written without anybody remembering to.
 *
 * Like the staff audit, it records the route, the outcome and what was acted
 * on — never the body's values. A team member's write is recorded under her
 * own name with the shop beside it (`metadata.store_id`), so the owner reads
 * who did what.
 */
@Injectable()
export class SellerActivityInterceptor implements NestInterceptor {
  private readonly logger = new Logger(SellerActivityInterceptor.name);

  constructor(private readonly prisma: PrismaService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') return next.handle();
    const request = context.switchToHttp().getRequest<DelegatedRequest>();
    if (!this.shouldRecord(request)) return next.handle();

    return next.handle().pipe(
      tap(() => void this.record(request, 'SUCCESS')),
      catchError((error: unknown) => {
        const status = (error as { status?: number })?.status ?? 500;
        // A refused attempt is worth seeing; a typo in a form is not.
        if (status === 401 || status === 403) {
          void this.record(request, `FAILED_${status}`);
        }
        return throwError(() => error);
      }),
    );
  }

  private shouldRecord(request: DelegatedRequest): boolean {
    if (!MUTATING.has(request.method)) return false;
    if (request.user?.role !== UserRole.SELLER) return false;
    const path = request.path;
    return SHOP_ROUTES.some((prefix) => path.startsWith(prefix));
  }

  private async record(request: DelegatedRequest, outcome: string) {
    try {
      const route = (request.route as { path?: string } | undefined)?.path ?? request.path;
      const params = (request.params ?? {}) as Record<string, string>;
      const names = Object.keys(params);
      const last = names[names.length - 1];
      const storeId = request.user!.id;
      const actorId = request.storeActor?.memberId ?? storeId;
      await this.prisma.auditLog.create({
        data: {
          actorId,
          action: `${request.method} ${route}`,
          category: 'seller',
          outcome,
          severity: outcome === 'SUCCESS' ? AuditSeverity.INFO : AuditSeverity.WARNING,
          targetType: last ?? null,
          targetId: last ? params[last] : null,
          ipAddress: request.ip ?? null,
          userAgent: request.headers['user-agent'] ?? null,
          metadata: {
            store_id: storeId,
            ...(request.storeActor && { team_role: request.storeActor.role }),
          } as Prisma.InputJsonValue,
        },
      });
    } catch (error) {
      this.logger.warn(
        `Could not record shop activity for ${request.method} ${request.path}: ${
          (error as Error).message
        }`,
      );
    }
  }
}
