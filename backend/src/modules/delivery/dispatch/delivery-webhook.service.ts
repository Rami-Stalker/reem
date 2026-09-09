import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Prisma, ShipmentStatus } from '@prisma/client';

import { PrismaService } from '../../../prisma/prisma.service';
import { DeliveryProviderRegistry } from '../providers/delivery-provider.registry';
import { WebhookRequest } from '../providers/delivery-provider.interface';
import { DeliveryDispatchService } from './delivery-dispatch.service';

export interface WebhookOutcome {
  received: true;
  accepted: number;
  ignored: number;
}

/**
 * Everything a carrier tells us, and what is done about it.
 *
 * A delivery webhook is the one endpoint on this platform that an outsider
 * can call and that moves money — a `delivered` on a cash order books a
 * collection, settles commission and starts the seller's escrow clock. So the
 * order here is deliberate and not negotiable:
 *
 *   1. **Record first.** The raw payload lands in `delivery_webhook_events`
 *      before anything is interpreted, signature verdict included. If we later
 *      argue with a carrier about what they sent, the answer is a row.
 *   2. **Verify, then act.** An event whose signature does not check out is
 *      stored and refused. It is never applied, and it never tells the caller
 *      why — an endpoint that explains itself to an attacker is an oracle.
 *   3. **Exactly once.** Carriers redeliver. The carrier's own event id is
 *      unique per provider, so a redelivery is recorded and skipped rather
 *      than moving a parcel twice.
 *   4. **Answer 200 anyway.** A carrier that gets a 500 will retry for hours
 *      and eventually give up. Once the event is stored, the platform owns the
 *      problem; the response says "received", not "agreed".
 */
@Injectable()
export class DeliveryWebhookService {
  private readonly logger = new Logger(DeliveryWebhookService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly registry: DeliveryProviderRegistry,
    private readonly dispatches: DeliveryDispatchService,
  ) {}

  async receive(
    providerCode: string,
    request: WebhookRequest,
  ): Promise<WebhookOutcome> {
    const account = await this.prisma.deliveryProviderAccount.findUnique({
      where: { code: providerCode },
    });
    if (!account || !account.supportsWebhook) {
      // Deliberately the same answer as an unknown carrier: this route must
      // not confirm which carriers the platform works with.
      throw new NotFoundException('Unknown delivery callback');
    }

    const provider = this.registry.get(account.adapter);
    const verdict = await provider.handleWebhook(account, request);

    let accepted = 0;
    let ignored = 0;

    // A payload we could not parse at all is still worth a row: a carrier
    // whose format changed under us is diagnosable from the event log.
    if (verdict.events.length === 0) {
      await this.record({
        providerCode: account.code,
        signatureValid: verdict.signatureValid,
        payload: request.body,
        error: verdict.error ?? 'No delivery events found in the payload',
      });
      return { received: true, accepted: 0, ignored: 1 };
    }

    for (const event of verdict.events) {
      const dispatch = await this.prisma.deliveryDispatch.findFirst({
        where: {
          providerId: account.id,
          externalDeliveryId: event.externalDeliveryId,
        },
      });

      const row = await this.record({
        providerCode: account.code,
        externalEventId: event.externalEventId ?? null,
        externalDeliveryId: event.externalDeliveryId,
        dispatchId: dispatch?.id ?? null,
        signatureValid: verdict.signatureValid,
        status: event.status,
        providerStatus: event.providerStatus ?? null,
        payload: request.body,
        error: !verdict.signatureValid
          ? 'Signature rejected'
          : dispatch
            ? null
            : 'No dispatch matches this delivery id',
      });

      if (!row) {
        // Already seen: a redelivery, which is the normal case rather than an
        // error, and the reason this table has a unique key at all.
        ignored += 1;
        continue;
      }
      if (!verdict.signatureValid || !dispatch) {
        ignored += 1;
        continue;
      }

      await this.dispatches.applyStatus(dispatch, event);
      await this.prisma.deliveryWebhookEvent.update({
        where: { id: row.id },
        data: { processedAt: new Date() },
      });
      accepted += 1;
    }

    return { received: true, accepted, ignored };
  }

  /**
   * Writes the event, or returns null when this carrier has already sent it.
   *
   * The uniqueness is `(providerCode, externalEventId)`. A carrier that sends
   * no event id gets a row every time — nothing else can be done, and the
   * status guard in `applyStatus` is the second line for exactly that case.
   */
  private async record(input: {
    providerCode: string;
    externalEventId?: string | null;
    externalDeliveryId?: string | null;
    dispatchId?: string | null;
    signatureValid: boolean;
    status?: ShipmentStatus | null;
    providerStatus?: string | null;
    payload: unknown;
    error?: string | null;
  }) {
    try {
      return await this.prisma.deliveryWebhookEvent.create({
        data: {
          providerCode: input.providerCode,
          externalEventId: input.externalEventId ?? null,
          externalDeliveryId: input.externalDeliveryId ?? null,
          dispatchId: input.dispatchId ?? null,
          signatureValid: input.signatureValid,
          status: input.status ?? null,
          providerStatus: input.providerStatus ?? null,
          payload: (input.payload ?? {}) as Prisma.InputJsonValue,
          error: input.error ?? null,
        },
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        this.logger.debug(
          `Ignoring a redelivered ${input.providerCode} event ${input.externalEventId}`,
        );
        return null;
      }
      throw error;
    }
  }
}
