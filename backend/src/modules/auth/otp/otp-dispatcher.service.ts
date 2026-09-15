import { Injectable } from '@nestjs/common';
import { OtpOutboxStatus, Prisma } from '@prisma/client';
import { randomInt } from 'crypto';
import { PrismaService } from '../../../prisma/prisma.service';
import { OtpCipherService } from './otp-cipher.service';

/** Emitted once a challenge and its outbox row are committed. */
export const OTP_ENQUEUED = 'otp.enqueued';

/**
 * Puts a freshly created challenge into the outbox.
 *
 * Enqueuing is a database write inside the same transaction that created the
 * challenge, not an outbound HTTP call. That is the point of an outbox: the
 * request returns as soon as the code exists, the provider's latency never
 * shows up in her wait, and a provider outage delays delivery instead of
 * failing the request she made.
 */
@Injectable()
export class OtpDispatcherService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cipher: OtpCipherService,
  ) {}

  /** Two digits she sees on screen and expects to find in the message. */
  static generateMatchCode(): string {
    return String(randomInt(0, 100)).padStart(2, '0');
  }

  /**
   * Queues the code for delivery. Runs inside the caller's transaction when
   * one is passed, so a challenge can never exist without its outbox row.
   */
  async enqueue(
    challengeId: string,
    code: string,
    tx: Prisma.TransactionClient = this.prisma,
  ): Promise<void> {
    await tx.otpOutbox.create({
      data: {
        challengeId,
        sealedCode: this.cipher.seal(code),
        status: OtpOutboxStatus.PENDING,
        nextAttemptAt: new Date(),
      },
    });
  }

  /**
   * Drops the sealed code as soon as it can no longer be needed — a delivered,
   * consumed or expired challenge has nothing left to resend, and a plaintext
   * code that outlives its purpose is just a liability sitting in a table.
   */
  async shred(challengeId: string, status: OtpOutboxStatus): Promise<void> {
    await this.prisma.otpOutbox.updateMany({
      where: { challengeId },
      data: { sealedCode: null, status },
    });
  }

  /** Copy for the transports: how long she has before the code dies. */
  expiresInMinutes(expiresAt: Date): number {
    return Math.max(1, Math.round((expiresAt.getTime() - Date.now()) / 60_000));
  }

  // A per-purpose deliverability whitelist used to live here. Nothing ever
  // called it, and it had silently gone stale — it omitted LOGIN, which is now
  // the primary sign-in code. A dead allow-list that looks authoritative is
  // worse than none: the next person to wire it up would have switched off
  // sign-in for the whole platform. Every challenge that gets written is meant
  // to be delivered; the transport chain decides how it travels.
}
