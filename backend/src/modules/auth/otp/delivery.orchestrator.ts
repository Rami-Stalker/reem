import { Inject, Injectable, Logger } from '@nestjs/common';
import {
  OtpDeliveryStatus,
  OtpTransportKind,
  OtpTransportRoute,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { OtpDispatch, OTP_TRANSPORTS, OtpTransport } from './otp-transport';

/** How long a transport gets to produce a delivery receipt before we move on. */
const RECEIPT_GRACE_MS = 25_000;

export interface DispatchAttemptResult {
  /** The transport that accepted it, if any. */
  transport: OtpTransportKind | null;
  status: 'accepted' | 'exhausted';
  /** True when the transport can never report delivery, so no receipt is due. */
  terminal: boolean;
  /** True when the plaintext must survive the send (ops-console read-out). */
  retainCode: boolean;
  deliveryId?: string;
  failureReason?: string;
}

/**
 * Chooses a transport, sends through it, and books the cost.
 *
 * The chain is data (`otp_transport_routes`), not code, so operations can flip
 * the primary channel during a Meta policy action without a deploy. Each
 * attempt writes a `ChallengeDelivery` row — that per-attempt record is the
 * only place success rate, time-to-handset and cost per channel can be read
 * from, and without it "delivery is broken" is an anecdote rather than a
 * number.
 */
@Injectable()
export class DeliveryOrchestrator {
  private readonly logger = new Logger(DeliveryOrchestrator.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(OTP_TRANSPORTS) private readonly transports: OtpTransport[],
  ) {}

  /** The enabled chain in priority order, budget breakers already applied. */
  async chain(): Promise<OtpTransportRoute[]> {
    const routes = await this.prisma.otpTransportRoute.findMany({
      where: { enabled: true },
      orderBy: { priority: 'asc' },
    });
    return routes.filter((route) => !this.breakerOpen(route));
  }

  /**
   * Sends `dispatch` through the transport at `index` in the chain, skipping
   * forward over transports that are unconfigured or over budget.
   */
  async dispatchFrom(
    challengeId: string,
    index: number,
    dispatch: OtpDispatch,
  ): Promise<DispatchAttemptResult & { nextIndex: number }> {
    const chain = await this.chain();

    for (let position = index; position < chain.length; position += 1) {
      const route = chain[position];
      const transport = this.transports.find((t) => t.kind === route.transport);

      if (!transport || !transport.isConfigured()) {
        await this.record(challengeId, route, {
          status: OtpDeliveryStatus.SKIPPED,
          failureReason: 'transport not configured',
        });
        continue;
      }

      const outcome = await transport.send(dispatch);

      if (outcome.status === 'unavailable') {
        await this.record(challengeId, route, {
          status: OtpDeliveryStatus.SKIPPED,
          failureReason: outcome.reason,
        });
        continue;
      }

      if (outcome.status === 'failed') {
        await this.record(challengeId, route, {
          status: OtpDeliveryStatus.FAILED,
          failureReason: outcome.reason,
          costMicros: outcome.costMicros ?? 0,
        });
        await this.bookSpend(route, outcome.costMicros ?? 0);
        continue;
      }

      const delivery = await this.record(challengeId, route, {
        status: OtpDeliveryStatus.SENT,
        providerMessageId: outcome.providerMessageId,
        costMicros: outcome.costMicros,
        sentAt: new Date(),
        metadata: outcome.metadata,
      });
      await this.bookSpend(route, outcome.costMicros);

      return {
        transport: route.transport,
        status: 'accepted',
        terminal: outcome.terminal === true,
        retainCode: outcome.retainCode === true,
        deliveryId: delivery.id,
        nextIndex: position + 1,
      };
    }

    return {
      transport: null,
      status: 'exhausted',
      terminal: true,
      retainCode: false,
      failureReason: 'no transport in the chain could accept the message',
      nextIndex: chain.length,
    };
  }

  /**
   * True when a delivery has been sitting in `SENT` past the receipt grace
   * period. That silence — accepted by the provider, never confirmed on the
   * handset — is the dominant Syrian failure mode, and reacting to it is the
   * whole reason failover exists rather than a retry on the same channel.
   */
  isOverdue(sentAt: Date | null): boolean {
    if (!sentAt) return false;
    return Date.now() - sentAt.getTime() > RECEIPT_GRACE_MS;
  }

  /** Marks the delivery as undelivered so the outbox can escalate past it. */
  async markUndelivered(deliveryId: string, reason: string): Promise<void> {
    await this.prisma.challengeDelivery.updateMany({
      where: { id: deliveryId, status: OtpDeliveryStatus.SENT },
      data: {
        status: OtpDeliveryStatus.FAILED,
        failedAt: new Date(),
        failureReason: reason,
      },
    });
  }

  private breakerOpen(route: OtpTransportRoute): boolean {
    if (route.dailyBudgetMicros === null) return false;
    if (!this.isToday(route.spentOn)) return false;
    return route.spentTodayMicros >= route.dailyBudgetMicros;
  }

  /**
   * Books spend against the route's daily budget and trips the breaker when it
   * is exhausted. Cost degrades before access: a tripped breaker falls through
   * to the cheaper transport rather than refusing to send at all.
   */
  private async bookSpend(
    route: OtpTransportRoute,
    costMicros: number,
  ): Promise<void> {
    if (costMicros <= 0) return;

    const today = this.startOfToday();
    const rollOver = !this.isToday(route.spentOn);
    const spent = (rollOver ? 0n : route.spentTodayMicros) + BigInt(costMicros);
    const tripped =
      route.dailyBudgetMicros !== null && spent >= route.dailyBudgetMicros;

    await this.prisma.otpTransportRoute.update({
      where: { id: route.id },
      data: {
        spentTodayMicros: spent,
        spentOn: today,
        breakerTrippedAt: tripped ? new Date() : rollOver ? null : undefined,
      },
    });

    if (tripped) {
      this.logger.warn(
        `Daily budget exhausted for ${route.transport}; falling through to the next transport`,
      );
    }
  }

  private record(
    challengeId: string,
    route: OtpTransportRoute,
    data: {
      status: OtpDeliveryStatus;
      providerMessageId?: string;
      costMicros?: number;
      sentAt?: Date;
      failureReason?: string;
      metadata?: Record<string, unknown>;
    },
  ) {
    return this.prisma.challengeDelivery.create({
      data: {
        challengeId,
        transport: route.transport,
        routeId: route.id,
        status: data.status,
        providerMessageId: data.providerMessageId,
        costMicros: BigInt(data.costMicros ?? 0),
        sentAt: data.sentAt,
        failedAt:
          data.status === OtpDeliveryStatus.FAILED ? new Date() : undefined,
        failureReason: data.failureReason,
        metadata: (data.metadata ?? undefined) as Prisma.InputJsonValue,
      },
    });
  }

  private startOfToday(): Date {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return today;
  }

  private isToday(value: Date | null): boolean {
    if (!value) return false;
    return value.getTime() === this.startOfToday().getTime();
  }
}
