import {
  BadRequestException,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OtpDeliveryStatus, OtpOutboxStatus } from '@prisma/client';
import { Request } from 'express';
import { createHash, createHmac, timingSafeEqual } from 'crypto';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../../common/decorators/public.decorator';
import { PrismaService } from '../../../prisma/prisma.service';

interface WhatsAppStatusEntry {
  id?: string;
  status?: string;
  errors?: { title?: string; message?: string }[];
  pricing?: { billable?: boolean };
}

/**
 * Delivery receipts from Meta.
 *
 * This is what turns the transport chain from hopeful into observable. Without
 * receipts the only failure the platform can see is a rejected API call — but
 * the failure that actually strands Syrian users is the opposite one: Meta
 * accepts the message and it never arrives, because the number is not on
 * WhatsApp, the template was blocked, the carrier throttled it, or her data is
 * simply switched off. A `delivered` receipt closes the challenge; a `failed`
 * receipt escalates it to the next transport immediately instead of waiting
 * out the silence window.
 *
 * The route is public because Meta calls it, so the signature check is the
 * only thing standing between an attacker and the ability to mark every
 * challenge delivered — or to keep escalating them until the SMS budget is
 * gone. It is verified in constant time against the raw body.
 */
@Public()
@Controller('webhooks/whatsapp')
export class WhatsAppWebhookController {
  private readonly appSecret?: string;
  private readonly verifyToken?: string;

  constructor(
    private readonly prisma: PrismaService,
    config: ConfigService,
  ) {
    this.appSecret = config.get<string>('otpDelivery.whatsapp.appSecret');
    this.verifyToken = config.get<string>('otpDelivery.whatsapp.verifyToken');
  }

  /** Meta's one-time subscription handshake. */
  @Get()
  verify(
    @Query('hub.mode') mode: string,
    @Query('hub.verify_token') token: string,
    @Query('hub.challenge') challenge: string,
  ): string {
    if (
      mode === 'subscribe' &&
      this.verifyToken &&
      typeof token === 'string' &&
      sameToken(token, this.verifyToken)
    ) {
      return challenge;
    }
    throw new BadRequestException('Invalid verification token');
  }

  @Throttle({ default: { limit: 600, ttl: 60_000 } })
  @Post()
  @HttpCode(HttpStatus.OK)
  async receive(@Req() req: Request): Promise<{ received: true }> {
    this.assertSignature(req);

    // Express 5 leaves `body` undefined for an empty or non-JSON request.
    const body = (req.body ?? {}) as {
      entry?: {
        changes?: { value?: { statuses?: WhatsAppStatusEntry[] } }[];
      }[];
    };

    const statuses =
      body.entry?.flatMap(
        (entry) =>
          entry.changes?.flatMap((change) => change.value?.statuses ?? []) ?? [],
      ) ?? [];

    for (const status of statuses) {
      await this.apply(status);
    }

    return { received: true };
  }

  private async apply(status: WhatsAppStatusEntry): Promise<void> {
    if (!status.id) return;

    const delivery = await this.prisma.challengeDelivery.findFirst({
      where: { providerMessageId: status.id },
      orderBy: { createdAt: 'desc' },
    });
    if (!delivery) return;

    // 'sent' is Meta acknowledging its own queue — not news, and not a reason
    // to stop the silence timer.
    if (status.status === 'delivered' || status.status === 'read') {
      await this.prisma.challengeDelivery.update({
        where: { id: delivery.id },
        data: {
          status: OtpDeliveryStatus.DELIVERED,
          deliveredAt: new Date(),
        },
      });
      await this.prisma.otpOutbox.updateMany({
        where: { challengeId: delivery.challengeId },
        data: { status: OtpOutboxStatus.DELIVERED, sealedCode: null },
      });
      return;
    }

    if (status.status === 'failed') {
      const reason =
        status.errors?.[0]?.message ??
        status.errors?.[0]?.title ??
        'WhatsApp reported delivery failure';
      await this.prisma.challengeDelivery.update({
        where: { id: delivery.id },
        data: {
          status: OtpDeliveryStatus.FAILED,
          failedAt: new Date(),
          failureReason: reason,
        },
      });
      // Escalate now rather than after the grace period — an explicit failure
      // is certainty, and every second she waits is a second she is stuck.
      await this.prisma.otpOutbox.updateMany({
        where: {
          challengeId: delivery.challengeId,
          status: OtpOutboxStatus.AWAITING_RECEIPT,
        },
        data: {
          status: OtpOutboxStatus.PENDING,
          nextAttemptAt: new Date(),
          lastError: reason,
        },
      });
    }
  }

  private assertSignature(req: Request): void {
    if (!this.appSecret) {
      // Refuse rather than accept unsigned callbacks: an unverified webhook is
      // a public endpoint that can mark any challenge delivered.
      throw new BadRequestException('Webhook signing secret is not configured');
    }

    const header = req.get('x-hub-signature-256');
    const raw = (req as Request & { rawBody?: Buffer }).rawBody;
    if (!header || !raw) {
      throw new BadRequestException('Missing webhook signature');
    }

    const expected = `sha256=${createHmac('sha256', this.appSecret)
      .update(raw)
      .digest('hex')}`;
    const a = Buffer.from(expected);
    const b = Buffer.from(header);
    if (a.length !== b.length || !timingSafeEqual(a, b)) {
      throw new BadRequestException('Invalid webhook signature');
    }
  }
}

/**
 * Constant-time and length-independent: both sides are hashed first, so the
 * response time leaks neither how much of the token matched nor its length.
 */
function sameToken(given: string, expected: string): boolean {
  const a = createHash('sha256').update(given).digest();
  const b = createHash('sha256').update(expected).digest();
  return timingSafeEqual(a, b);
}
