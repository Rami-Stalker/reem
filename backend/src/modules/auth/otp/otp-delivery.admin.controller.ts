import {
  Body,
  Controller,
  Get,
  Inject,
  HttpCode,
  HttpStatus,
  NotFoundException,
  Param,
  Patch,
  Query,
} from '@nestjs/common';
import {
  AssuranceLevel,
  OtpDeliveryStatus,
  OtpStatus,
  OtpTransportKind,
  RiskLevel,
  SecurityEventType,
} from '@prisma/client';
import { Authorize } from '../../../common/decorators/authorize.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../../../common/decorators/current-user.decorator';
import { AppPermission } from '../../../common/permissions';
import { PrismaService } from '../../../prisma/prisma.service';
import { OtpCipherService } from './otp-cipher.service';
import { maskDestination, OTP_TRANSPORTS, OtpTransport } from './otp-transport';
import { UpdateTransportRouteDto } from './dto/transport-route.dto';
import { RequireStepUp } from '../../../common/decorators/require-step-up.decorator';
import { DeviceProof } from '../../../common/guards/device-proof.guard';

/**
 * Operating the delivery chain.
 *
 * Three surfaces, and the reason each exists is different:
 *
 * - the **report** is how the WhatsApp-vs-SMS primary gets decided in week one
 *   of the beta, from measured success rate and cost rather than from a guess;
 * - the **routes** are how operations survive a Meta policy action without a
 *   deploy — and, unguarded, are also how one admin could reroute every code on
 *   the platform to a channel they control, which is why every write here
 *   emits a CRITICAL security event;
 * - the **pending challenges** list is the closed-beta stopgap: with the
 *   ops-console transport enabled, a team member reads a code to a hand-picked
 *   tester. Every reveal is recorded against the admin who looked.
 */
@Controller('admin/auth/delivery')
export class OtpDeliveryAdminController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cipher: OtpCipherService,
    @Inject(OTP_TRANSPORTS) private readonly transports: OtpTransport[],
  ) {}

  @Authorize({
    action: 'read',
    resource: 'admin',
    permissions: [AppPermission.adminDashboard],
  })
  @Get('report')
  async report(@Query('days') days?: string) {
    const window = Math.min(Math.max(Number(days) || 7, 1), 90);
    const since = new Date(Date.now() - window * 864e5);

    const deliveries = await this.prisma.challengeDelivery.findMany({
      where: { createdAt: { gte: since } },
      select: {
        transport: true,
        status: true,
        costMicros: true,
        sentAt: true,
        deliveredAt: true,
        createdAt: true,
      },
    });

    const byTransport = new Map<
      OtpTransportKind,
      {
        attempts: number;
        sent: number;
        delivered: number;
        failed: number;
        skipped: number;
        costMicros: bigint;
        latencies: number[];
      }
    >();

    for (const row of deliveries) {
      const bucket = byTransport.get(row.transport) ?? {
        attempts: 0,
        sent: 0,
        delivered: 0,
        failed: 0,
        skipped: 0,
        costMicros: 0n,
        latencies: [],
      };
      bucket.attempts += 1;
      bucket.costMicros += row.costMicros;
      if (row.status === OtpDeliveryStatus.SKIPPED) bucket.skipped += 1;
      if (row.status === OtpDeliveryStatus.FAILED) bucket.failed += 1;
      if (row.sentAt) bucket.sent += 1;
      if (row.status === OtpDeliveryStatus.DELIVERED) {
        bucket.delivered += 1;
        if (row.sentAt && row.deliveredAt) {
          bucket.latencies.push(
            row.deliveredAt.getTime() - row.sentAt.getTime(),
          );
        }
      }
      byTransport.set(row.transport, bucket);
    }

    const routes = await this.prisma.otpTransportRoute.findMany({
      orderBy: { priority: 'asc' },
    });

    return {
      window_days: window,
      transports: routes.map((route) => {
        const stats = byTransport.get(route.transport);
        const attempts = stats?.attempts ?? 0;
        const sent = stats?.sent ?? 0;
        const delivered = stats?.delivered ?? 0;
        return {
          transport: route.transport.toLowerCase(),
          priority: route.priority,
          enabled: route.enabled,
          breaker_tripped_at: route.breakerTrippedAt?.toISOString() ?? null,
          daily_budget_micros: route.dailyBudgetMicros?.toString() ?? null,
          spent_today_micros: route.spentTodayMicros.toString(),
          attempts,
          sent,
          delivered,
          failed: stats?.failed ?? 0,
          skipped: stats?.skipped ?? 0,
          // Confirmed delivery over accepted sends — and `null`, not 0, for a
          // channel that never confirms anything. An SMS gateway working
          // perfectly must not read as a 0% channel on the screen that decides
          // which channel is primary.
          delivery_rate: this.deliveryRate(route.transport, sent, delivered),
          median_time_to_delivery_ms: this.median(stats?.latencies ?? []),
          cost_micros: (stats?.costMicros ?? 0n).toString(),
        };
      }),
    };
  }

  @Authorize({
    action: 'manage',
    resource: 'admin',
    permissions: [AppPermission.adminDashboard],
  })
  // Whoever writes this table reroutes every code on the platform.
  @DeviceProof()
  @RequireStepUp(AssuranceLevel.AAL3, 'otp_transport_routes')
  @Patch('routes/:transport')
  @HttpCode(HttpStatus.OK)
  async updateRoute(
    @Param('transport') transport: string,
    @Body() dto: UpdateTransportRouteDto,
    @CurrentUser() admin: AuthUser,
  ) {
    const kind = transport.toUpperCase() as OtpTransportKind;
    const existing = await this.prisma.otpTransportRoute.findUnique({
      where: { transport: kind },
    });
    if (!existing) throw new NotFoundException('Unknown transport');

    const route = await this.prisma.otpTransportRoute.update({
      where: { transport: kind },
      data: {
        priority: dto.priority,
        enabled: dto.enabled,
        dailyBudgetMicros:
          dto.daily_budget_micros === undefined
            ? undefined
            : dto.daily_budget_micros === null
              ? null
              : BigInt(dto.daily_budget_micros),
        // Any deliberate change to a route is also the way to clear a breaker
        // that tripped on yesterday's budget.
        breakerTrippedAt: dto.reset_breaker ? null : undefined,
        spentTodayMicros: dto.reset_breaker ? 0n : undefined,
        note: dto.note,
      },
    });

    await this.prisma.securityEvent.create({
      data: {
        type: SecurityEventType.OTP_ROUTE_CHANGED,
        riskLevel: RiskLevel.CRITICAL,
        actorId: admin.id,
        resource: `otp_transport_route:${kind}`,
        metadata: {
          action: 'transport_route_updated',
          before: {
            priority: existing.priority,
            enabled: existing.enabled,
            daily_budget_micros: existing.dailyBudgetMicros?.toString() ?? null,
          },
          after: {
            priority: route.priority,
            enabled: route.enabled,
            daily_budget_micros: route.dailyBudgetMicros?.toString() ?? null,
          },
        },
      },
    });

    return {
      transport: route.transport.toLowerCase(),
      priority: route.priority,
      enabled: route.enabled,
      daily_budget_micros: route.dailyBudgetMicros?.toString() ?? null,
      note: route.note,
    };
  }

  /**
   * Closed-beta stopgap: the codes still in flight, so a team member can read
   * one out to a tester. Only returns anything while the ops-console transport
   * is the one that accepted the challenge.
   */
  @Authorize({
    action: 'manage',
    resource: 'admin',
    permissions: [AppPermission.adminDashboard],
  })
  @Get('pending-challenges')
  async pendingChallenges(@CurrentUser() admin: AuthUser) {
    const rows = await this.prisma.otpOutbox.findMany({
      where: {
        sealedCode: { not: null },
        challenge: {
          status: OtpStatus.PENDING,
          expiresAt: { gt: new Date() },
          deliveries: { some: { transport: OtpTransportKind.OPS_CONSOLE } },
        },
      },
      include: { challenge: true },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    if (rows.length > 0) {
      await this.prisma.securityEvent.create({
        data: {
          type: SecurityEventType.OTP_CODE_REVEALED,
          riskLevel: RiskLevel.CRITICAL,
          actorId: admin.id,
          resource: 'otp_pending_challenges',
          metadata: {
            action: 'otp_codes_revealed',
            challenge_ids: rows.map((row) => row.challengeId),
          },
        },
      });
    }

    return {
      data: rows.map((row) => ({
        challenge_id: row.challengeId,
        destination: maskDestination(row.challenge.destination),
        purpose: row.challenge.purpose.toLowerCase(),
        match_code: row.challenge.matchCode,
        code: this.cipher.open(row.sealedCode),
        expires_at: row.challenge.expiresAt.toISOString(),
      })),
    };
  }

  /** Null when the channel cannot report receipts — "no data", not "zero". */
  private deliveryRate(
    transport: OtpTransportKind,
    sent: number,
    delivered: number,
  ): number | null {
    const impl = this.transports.find((t) => t.kind === transport);
    if (!impl?.reportsReceipts()) return null;
    if (sent === 0) return null;
    return Number((delivered / sent).toFixed(3));
  }

  private median(values: number[]): number | null {
    if (values.length === 0) return null;
    const sorted = [...values].sort((a, b) => a - b);
    const middle = Math.floor(sorted.length / 2);
    return sorted.length % 2 === 0
      ? Math.round((sorted[middle - 1] + sorted[middle]) / 2)
      : sorted[middle];
  }
}
