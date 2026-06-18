import { Injectable, Logger } from '@nestjs/common';
import { AuditSeverity, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { RequestContext } from './interfaces/request-context.interface';

interface AuditInput {
  actorId?: string | null;
  action: string;
  category: string;
  outcome: string;
  severity?: AuditSeverity;
  metadata?: Prisma.InputJsonValue;
  context?: RequestContext;
}

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  async record(input: AuditInput): Promise<void> {
    try {
      await this.prisma.auditLog.create({
        data: {
          actorId: input.actorId ?? undefined,
          action: input.action,
          category: input.category,
          outcome: input.outcome,
          severity: input.severity ?? AuditSeverity.INFO,
          ipAddress: input.context?.ipAddress,
          userAgent: input.context?.userAgent,
          metadata: input.metadata ?? undefined,
        },
      });
    } catch (error) {
      this.logger.warn(
        `Failed to write audit log for ${input.category}.${input.action}: ${
          error instanceof Error ? error.message : 'unknown error'
        }`,
      );
    }
  }
}
