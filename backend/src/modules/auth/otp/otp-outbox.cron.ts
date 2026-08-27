import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import {
  OtpDeliveryStatus,
  OtpOutboxStatus,
  OtpStatus,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { DeliveryOrchestrator } from './delivery.orchestrator';
import { OtpCipherService } from './otp-cipher.service';
import { OtpDispatcherService } from './otp-dispatcher.service';

/** Retry backoff for a transport that errored, before escalating past it. */
const RETRY_BACKOFF_MS = 8_000;
/** Rows claimed per tick. Small: a code is worthless if it arrives late. */
const BATCH_SIZE = 25;

interface ClaimedRow {
  id: string;
  challenge_id: string;
  sealed_code: string | null;
  transport_index: number;
  attempts: number;
}

/**
 * Drains the OTP outbox.
 *
 * Two things make this safe to run on more than one instance. Claiming uses
 * `FOR UPDATE SKIP LOCKED`, so two workers never grab the same row. And the
 * claim flips the row to `IN_FLIGHT` in the same statement, so a crash mid-send
 * leaves a row that the stale-reclaim pass below picks up rather than a row
 * that is lost.
 *
 * The escalation rule is the interesting part: a transport that *errored* is
 * retried once on the same channel after a short backoff, but a transport that
 * *accepted and then went silent* is abandoned for the next channel. Those are
 * different failures — the first is usually a hiccup, the second is the
 * message sitting in a queue that will never reach her handset.
 */
@Injectable()
export class OtpOutboxCron {
  private readonly logger = new Logger(OtpOutboxCron.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly orchestrator: DeliveryOrchestrator,
    private readonly cipher: OtpCipherService,
    private readonly dispatcher: OtpDispatcherService,
  ) {}

  @Cron(CronExpression.EVERY_5_SECONDS)
  async drain(): Promise<void> {
    await this.escalateSilentDeliveries();
    await this.reclaimStale();

    const claimed = await this.claim();
    for (const row of claimed) {
      await this.deliver(row).catch((error) => {
        this.logger.error(
          `Outbox row ${row.id} failed: ${error instanceof Error ? error.message : error}`,
        );
      });
    }
  }

  /** Retires codes that can no longer be used, and their plaintext with them. */
  @Cron(CronExpression.EVERY_MINUTE)
  async retireExpired(): Promise<void> {
    const expired = await this.prisma.otpRequest.findMany({
      where: {
        status: OtpStatus.PENDING,
        expiresAt: { lt: new Date() },
        outbox: { isNot: null },
      },
      select: { id: true },
      take: 200,
    });

    for (const challenge of expired) {
      await this.dispatcher.shred(challenge.id, OtpOutboxStatus.CANCELLED);
    }
    if (expired.length > 0) {
      this.logger.log(`Retired ${expired.length} expired challenges`);
    }
  }

  /**
   * Atomically takes up to `BATCH_SIZE` due rows. `SKIP LOCKED` is what lets a
   * second instance run this loop without duplicating a single message.
   */
  private claim(): Promise<ClaimedRow[]> {
    return this.prisma.$queryRaw<ClaimedRow[]>`
      UPDATE otp_outbox
      SET status = 'IN_FLIGHT', attempts = attempts + 1, updated_at = NOW()
      WHERE id IN (
        SELECT id FROM otp_outbox
        WHERE status = 'PENDING' AND next_attempt_at <= NOW()
        ORDER BY next_attempt_at ASC
        LIMIT ${BATCH_SIZE}
        FOR UPDATE SKIP LOCKED
      )
      RETURNING id, challenge_id, sealed_code, transport_index, attempts
    `;
  }

  /** A worker that died mid-send leaves IN_FLIGHT rows; give them back. */
  private async reclaimStale(): Promise<void> {
    await this.prisma.$executeRaw`
      UPDATE otp_outbox
      SET status = 'PENDING', next_attempt_at = NOW()
      WHERE status = 'IN_FLIGHT' AND updated_at < NOW() - INTERVAL '2 minutes'
    `;
  }

  private async deliver(row: ClaimedRow): Promise<void> {
    const challenge = await this.prisma.otpRequest.findUnique({
      where: { id: row.challenge_id },
    });

    // Verified, expired or gone while it sat in the queue: nothing to send.
    if (
      !challenge ||
      challenge.status !== OtpStatus.PENDING ||
      challenge.expiresAt < new Date()
    ) {
      await this.finish(row.id, OtpOutboxStatus.CANCELLED);
      return;
    }

    const code = this.cipher.open(row.sealed_code);
    if (!code) {
      // The sealed code is unreadable, so this challenge can never be
      // delivered. Failing it loudly beats silently sending nothing.
      await this.finish(row.id, OtpOutboxStatus.EXHAUSTED, 'sealed code unreadable');
      return;
    }

    const result = await this.orchestrator.dispatchFrom(
      challenge.id,
      row.transport_index,
      {
        phone: challenge.destination,
        code,
        matchCode: challenge.matchCode ?? '00',
        purpose: challenge.purpose,
        expiresInMinutes: this.dispatcher.expiresInMinutes(challenge.expiresAt),
      },
    );

    if (result.status === 'exhausted') {
      if (row.attempts < 2) {
        // Every channel failed on this pass — usually a shared cause such as
        // the network being down. Back off and try the whole chain again
        // before declaring the challenge undeliverable.
        await this.prisma.otpOutbox.update({
          where: { id: row.id },
          data: {
            status: OtpOutboxStatus.PENDING,
            transportIndex: 0,
            nextAttemptAt: new Date(Date.now() + RETRY_BACKOFF_MS),
            lastError: result.failureReason,
          },
        });
        return;
      }
      await this.finish(
        row.id,
        OtpOutboxStatus.EXHAUSTED,
        result.failureReason,
      );
      this.logger.error(
        `Challenge ${challenge.id} could not be delivered by any transport`,
      );
      return;
    }

    if (result.terminal) {
      // Nothing more will be heard about this one — SMS gateways and voice
      // calls do not report back. Treat the accepted send as the end of the
      // road and drop the plaintext, unless the transport asked to keep it:
      // the ops console's "delivery" is a human who still has to read it.
      await this.prisma.otpOutbox.update({
        where: { id: row.id },
        data: {
          status: OtpOutboxStatus.DELIVERED,
          sealedCode: result.retainCode ? undefined : null,
          transportIndex: result.nextIndex,
          lastError: null,
        },
      });
      return;
    }

    // Accepted by a transport that does report delivery: hold the row until a
    // receipt arrives or the silence window closes.
    await this.prisma.otpOutbox.update({
      where: { id: row.id },
      data: {
        status: OtpOutboxStatus.AWAITING_RECEIPT,
        transportIndex: result.nextIndex,
        lastError: null,
      },
    });
  }

  /**
   * Finds challenges whose last send was accepted but never confirmed, and
   * pushes them onto the next transport — carrying the SAME code, so she is
   * never told to start over just because a channel went quiet.
   */
  private async escalateSilentDeliveries(): Promise<void> {
    const waiting = await this.prisma.otpOutbox.findMany({
      where: { status: OtpOutboxStatus.AWAITING_RECEIPT },
      take: BATCH_SIZE,
      include: {
        challenge: {
          include: {
            deliveries: {
              where: { status: OtpDeliveryStatus.SENT },
              orderBy: { sentAt: 'desc' },
              take: 1,
            },
          },
        },
      },
    });

    for (const row of waiting) {
      const latest = row.challenge.deliveries[0];
      if (!latest || !this.orchestrator.isOverdue(latest.sentAt)) continue;

      await this.orchestrator.markUndelivered(
        latest.id,
        'no delivery receipt within the grace period',
      );
      await this.prisma.otpOutbox.update({
        where: { id: row.id },
        data: {
          status: OtpOutboxStatus.PENDING,
          nextAttemptAt: new Date(),
          lastError: 'escalated after delivery silence',
        },
      });
      this.logger.warn(
        `Escalating challenge ${row.challengeId} past ${latest.transport} after silence`,
      );
    }
  }

  private async finish(
    outboxId: string,
    status: OtpOutboxStatus,
    lastError?: string,
  ): Promise<void> {
    await this.prisma.otpOutbox.update({
      where: { id: outboxId },
      data: { status, sealedCode: null, lastError },
    });
  }
}
