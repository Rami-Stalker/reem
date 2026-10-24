import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  Currency,
  DeliveryDispatch,
  DeliveryProviderAccount,
  DeliveryProviderKind,
  Prisma,
  ShipmentStatus,
} from '@prisma/client';

import { PrismaService } from '../../../prisma/prisma.service';
import { Money } from '../../../common/money';
import { ShipmentsService } from '../shipments.service';
import { DeliveryProviderRegistry } from '../providers/delivery-provider.registry';
import {
  CreateDeliveryInput,
  DeliveryAddress,
  DeliveryWebhookEventInput,
} from '../providers/delivery-provider.interface';
import {
  isForwardDeliveryStatus,
  isTerminalDeliveryStatus,
} from '../providers/delivery-status.map';

/**
 * Ohara's side of a delivery company.
 *
 * The platform keeps the order; the carrier keeps the journey. This service is
 * the only place the two meet, and it holds the rules that make that meeting
 * safe:
 *
 * **One parcel is dispatched once.** The dispatch row is written *before* the
 * carrier is called, keyed on the shipment, so a double click, a retried job
 * or two seller taps cannot become two parcels at the carrier's warehouse. The
 * same key is sent as the carrier's idempotency header.
 *
 * **A carrier's failure is never the seller's problem.** Dispatch is called
 * from `ready()`; if the carrier is down, the parcel stays packed, the dispatch
 * row records why, and ops (or a retry) tries again. Nothing in the order is
 * rolled back.
 *
 * **A carrier's word is mapped, not obeyed.** Statuses go through the canonical
 * map and the shipment's own transition table, so a carrier that reports events
 * out of order, or reports a delivery twice, cannot invent money or reopen a
 * closed parcel.
 */
@Injectable()
export class DeliveryDispatchService {
  private readonly logger = new Logger(DeliveryDispatchService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly registry: DeliveryProviderRegistry,
    private readonly shipments: ShipmentsService,
  ) {}

  // ── Choosing a carrier ────────────────────────────────────────────────

  /**
   * The carrier for a destination: enabled, covering that governorate, lowest
   * priority number, the default breaking a tie.
   *
   * Returns null when nothing is configured — the platform is then not
   * dispatching at all, which is a state ops must see rather than one the code
   * should paper over.
   */
  async selectProvider(
    governorate: string,
  ): Promise<DeliveryProviderAccount | null> {
    const accounts = await this.prisma.deliveryProviderAccount.findMany({
      where: { isEnabled: true },
      orderBy: [{ priority: 'asc' }, { isDefault: 'desc' }, { displayName: 'asc' }],
    });

    const usable = accounts.filter((account) => this.registry.has(account.adapter));
    if (usable.length === 0) return null;

    const covering = usable.filter(
      (account) =>
        account.governorates.length === 0 ||
        account.governorates.includes(governorate),
    );
    return covering[0] ?? null;
  }

  // ── Dispatch ──────────────────────────────────────────────────────────

  /**
   * Hands a packed parcel to a carrier.
   *
   * Idempotent on the shipment: called twice, the second call returns the first
   * dispatch untouched. Safe to call from `ready()` and from an ops retry.
   */
  async dispatch(sellerOrderId: string): Promise<DeliveryDispatch | null> {
    const shipment = await this.prisma.shipment.findUnique({
      where: { sellerOrderId },
      include: {
        dispatch: true,
        sellerOrder: {
          select: {
            id: true,
            number: true,
            currency: true,
            itemsSubtotal: true,
            seller: { select: { name: true, phone: true, location: true } },
            items: { select: { quantity: true } },
            order: {
              select: {
                recipientName: true,
                recipientPhone: true,
                governorate: true,
                city: true,
                district: true,
                addressLine: true,
                landmark: true,
                deliveryInstructions: true,
              },
            },
          },
        },
      },
    });
    if (!shipment) return null;

    // Already handed over — including a dispatch that failed mid-flight and is
    // waiting for a retry, which `retry()` owns rather than this path.
    if (shipment.dispatch && shipment.dispatch.externalDeliveryId) {
      return shipment.dispatch;
    }
    if (shipment.status !== ShipmentStatus.CREATED && !shipment.dispatch) {
      // A parcel already moving under the old in-house flow: leave it alone.
      return null;
    }

    const destination = shipment.sellerOrder.order.governorate;
    const account = await this.selectProvider(destination);
    if (!account) {
      this.logger.warn(
        `No delivery provider is enabled for ${destination}; parcel ${shipment.sellerOrder.number} is waiting`,
      );
      return null;
    }

    const dispatch =
      shipment.dispatch ??
      (await this.prisma.deliveryDispatch.create({
        data: {
          shipmentId: shipment.id,
          providerId: account.id,
          providerCode: account.code,
          status: ShipmentStatus.CREATED,
          // Derived from the parcel, not from the clock: a retry must reuse it.
          idempotencyKey: `reem-dispatch-${shipment.id}`,
          requestedAt: new Date(),
        },
      }));

    return this.callCarrier(account, dispatch, shipment);
  }

  /** Re-attempts a dispatch the carrier refused or never answered. */
  async retry(dispatchId: string): Promise<DeliveryDispatch> {
    const dispatch = await this.prisma.deliveryDispatch.findUnique({
      where: { id: dispatchId },
      include: { provider: true },
    });
    if (!dispatch) throw new NotFoundException('Dispatch not found');
    if (dispatch.externalDeliveryId) {
      throw new BadRequestException(
        'This parcel is already with the carrier — cancel it before dispatching again',
      );
    }

    const shipment = await this.prisma.shipment.findUnique({
      where: { id: dispatch.shipmentId },
      include: {
        dispatch: true,
        sellerOrder: {
          select: {
            id: true,
            number: true,
            currency: true,
            itemsSubtotal: true,
            seller: { select: { name: true, phone: true, location: true } },
            items: { select: { quantity: true } },
            order: {
              select: {
                recipientName: true,
                recipientPhone: true,
                governorate: true,
                city: true,
                district: true,
                addressLine: true,
                landmark: true,
                deliveryInstructions: true,
              },
            },
          },
        },
      },
    });
    if (!shipment) throw new NotFoundException('Shipment not found');

    return this.callCarrier(dispatch.provider, dispatch, shipment);
  }

  private async callCarrier(
    account: DeliveryProviderAccount,
    dispatch: DeliveryDispatch,
    shipment: Prisma.ShipmentGetPayload<{
      include: {
        dispatch: true;
        sellerOrder: {
          select: {
            id: true;
            number: true;
            currency: true;
            itemsSubtotal: true;
            seller: { select: { name: true; phone: true; location: true } };
            items: { select: { quantity: true } };
            order: {
              select: {
                recipientName: true;
                recipientPhone: true;
                governorate: true;
                city: true;
                district: true;
                addressLine: true;
                landmark: true;
                deliveryInstructions: true;
              };
            };
          };
        };
      };
    }>,
  ): Promise<DeliveryDispatch> {
    const provider = this.registry.get(account.adapter);
    const input = this.createInput(dispatch, shipment);

    try {
      const result = await provider.createDelivery(account, input);

      const updated = await this.prisma.deliveryDispatch.update({
        where: { id: dispatch.id },
        data: {
          providerId: account.id,
          providerCode: account.code,
          externalDeliveryId: result.externalDeliveryId,
          trackingNumber: result.trackingNumber ?? null,
          trackingUrl: result.trackingUrl ?? null,
          labelUrl: result.labelUrl ?? null,
          // The status is deliberately *not* written here. `applyStatus` below
          // owns every status change — it is what moves the shipment and the
          // sub-order with it — and writing the status first would make that
          // call a no-op, leaving the parcel invisible to the carrier's own
          // round while the dispatch row claimed it had been accepted.
          feeAmount: result.fee ? new Prisma.Decimal(result.fee.amount) : null,
          feeCurrency: result.fee?.currency ?? null,
          lastError: null,
          lastResponse: (result.raw ?? null) as Prisma.InputJsonValue,
          lastSyncedAt: new Date(),
        },
      });

      await this.prisma.deliveryProviderAccount.update({
        where: { id: account.id },
        data: { lastHealthyAt: new Date(), lastError: null },
      });

      // The in-house fleet names the rider carrying the parcel; a delivery
      // company has no rider of ours to name. One line, rather than a second
      // code path for our own couriers.
      if (
        account.kind === DeliveryProviderKind.INTERNAL &&
        result.internalCourierId
      ) {
        await this.prisma.shipment.update({
          where: { id: shipment.id },
          data: { courierId: result.internalCourierId },
        });
      }

      await this.applyStatus(updated, {
        externalDeliveryId: result.externalDeliveryId,
        status: result.status,
        providerStatus: result.providerStatus ?? null,
      });

      return updated;
    } catch (error) {
      const message = (error as Error).message.slice(0, 500);
      this.logger.error(
        `Carrier ${account.code} refused parcel ${shipment.sellerOrder.number}: ${message}`,
      );

      await this.prisma.deliveryProviderAccount.update({
        where: { id: account.id },
        data: { lastErrorAt: new Date(), lastError: message },
      });

      return this.prisma.deliveryDispatch.update({
        where: { id: dispatch.id },
        data: { lastError: message, lastSyncedAt: new Date() },
      });
    }
  }

  private createInput(
    dispatch: DeliveryDispatch,
    shipment: Prisma.ShipmentGetPayload<{
      include: {
        sellerOrder: {
          select: {
            number: true;
            currency: true;
            itemsSubtotal: true;
            seller: { select: { name: true; phone: true; location: true } };
            items: { select: { quantity: true } };
            order: {
              select: {
                recipientName: true;
                recipientPhone: true;
                governorate: true;
                city: true;
                district: true;
                addressLine: true;
                landmark: true;
                deliveryInstructions: true;
              };
            };
          };
        };
      };
    }>,
  ): CreateDeliveryInput {
    const order = shipment.sellerOrder.order;
    const seller = shipment.sellerOrder.seller;

    const pickup: DeliveryAddress = {
      name: seller.name,
      phone: seller.phone ?? '',
      // The seller's own location is a free-text city today; a carrier that
      // needs a structured pickup address gets it from the boutique profile
      // once that is captured. Sending what exists beats sending nothing.
      governorate: seller.location ?? order.governorate,
      city: seller.location ?? order.city,
      addressLine: seller.location ?? '',
    };

    const dropoff: DeliveryAddress = {
      name: order.recipientName,
      phone: order.recipientPhone,
      governorate: order.governorate,
      city: order.city,
      district: order.district,
      addressLine: order.addressLine,
      landmark: order.landmark,
      notes: order.deliveryInstructions,
    };

    const itemCount = shipment.sellerOrder.items.reduce(
      (sum, item) => sum + item.quantity,
      0,
    );

    return {
      reference: shipment.trackingCode,
      idempotencyKey: dispatch.idempotencyKey,
      pickup,
      dropoff,
      codAmount: shipment.codAmount
        ? Money.of(shipment.codAmount, shipment.currency).toString()
        : null,
      currency: shipment.currency,
      declaredValue: Money.of(
        shipment.sellerOrder.itemsSubtotal,
        shipment.sellerOrder.currency,
      ).toString(),
      itemCount,
      isExpress: shipment.isExpress,
      scheduledFor: shipment.scheduledFor,
      notes: order.deliveryInstructions,
    };
  }

  // ── Cancelling and re-reading ─────────────────────────────────────────

  async cancel(shipmentId: string, reason?: string): Promise<void> {
    const dispatch = await this.prisma.deliveryDispatch.findUnique({
      where: { shipmentId },
      include: { provider: true },
    });
    if (!dispatch) return;
    if (isTerminalDeliveryStatus(dispatch.status)) return;

    if (dispatch.externalDeliveryId && dispatch.provider.supportsCancel) {
      const provider = this.registry.get(dispatch.provider.adapter);
      await provider.cancelDelivery(dispatch.provider, {
        externalDeliveryId: dispatch.externalDeliveryId,
        reason,
      });
    }

    await this.prisma.deliveryDispatch.update({
      where: { id: dispatch.id },
      data: {
        status: ShipmentStatus.CANCELLED,
        cancelledAt: new Date(),
        cancelReason: reason ?? null,
      },
    });
  }

  /**
   * Asks the carrier where a parcel is.
   *
   * The safety net under webhooks, not a replacement for them: a callback that
   * never arrives (a firewall, an outage, a carrier that forgot) leaves a
   * parcel frozen on the customer's tracking page, and this is what unfreezes
   * it.
   */
  async refresh(dispatchId: string): Promise<DeliveryDispatch> {
    const dispatch = await this.prisma.deliveryDispatch.findUnique({
      where: { id: dispatchId },
      include: { provider: true },
    });
    if (!dispatch) throw new NotFoundException('Dispatch not found');
    if (!dispatch.externalDeliveryId) {
      throw new BadRequestException('This parcel has not reached a carrier yet');
    }

    const provider = this.registry.get(dispatch.provider.adapter);
    const status = await provider.getDeliveryStatus(
      dispatch.provider,
      dispatch.externalDeliveryId,
    );

    await this.applyStatus(dispatch, {
      externalDeliveryId: dispatch.externalDeliveryId,
      status: status.status,
      providerStatus: status.providerStatus ?? null,
      occurredAt: status.occurredAt ?? null,
      failureReason: status.failureReason ?? null,
      failureNote: status.failureNote ?? null,
      collectedAmount: status.collectedAmount ?? null,
      trackingNumber: status.trackingNumber ?? null,
    });

    return this.prisma.deliveryDispatch.findUniqueOrThrow({
      where: { id: dispatch.id },
    });
  }

  // ── Applying a carrier's word ─────────────────────────────────────────

  /**
   * Moves the platform's own record to match what a carrier reported.
   *
   * Three refusals, in order, and each of them is a real failure mode of every
   * carrier integration:
   *
   * 1. **A status we already hold** is ignored — carriers resend.
   * 2. **A status behind the one we hold** is ignored — a retried webhook queue
   *    arrives out of order, and a parcel must never walk backwards on the
   *    customer's screen.
   * 3. **A parcel already finished** is ignored — a late "delivered" after a
   *    return would otherwise settle money twice.
   */
  async applyStatus(
    dispatch: DeliveryDispatch,
    event: Omit<DeliveryWebhookEventInput, 'externalEventId'>,
  ): Promise<void> {
    const shouldMove =
      dispatch.status !== event.status &&
      isForwardDeliveryStatus(dispatch.status, event.status);

    await this.prisma.deliveryDispatch.update({
      where: { id: dispatch.id },
      data: {
        // The carrier's own word is always recorded, even when the move is not
        // taken: support needs to see what they said.
        providerStatus: event.providerStatus ?? dispatch.providerStatus,
        trackingNumber: event.trackingNumber ?? dispatch.trackingNumber,
        lastSyncedAt: new Date(),
        ...(shouldMove
          ? {
              status: event.status,
              ...this.timestampsFor(event.status, event.occurredAt ?? new Date()),
              failureReason: event.failureReason ?? dispatch.failureReason,
              failureNote: event.failureNote ?? dispatch.failureNote,
              attemptCount:
                event.status === ShipmentStatus.FAILED
                  ? { increment: 1 }
                  : undefined,
            }
          : {}),
      },
    });

    if (!shouldMove) return;

    try {
      await this.shipments.applyCarrierStatus({
        shipmentId: dispatch.shipmentId,
        status: event.status,
        note: event.failureNote ?? event.providerStatus ?? null,
        at: event.occurredAt ?? null,
        failureReason: event.failureReason ?? null,
        collectedAmount: event.collectedAmount ?? null,
      });
    } catch (error) {
      // The carrier's record stays; ours refused. That is a reconciliation
      // problem for ops, not a reason to drop the event on the floor.
      const message = (error as Error).message.slice(0, 500);
      this.logger.error(
        `Carrier ${dispatch.providerCode} reported ${event.status} for dispatch ${dispatch.id}, ` +
          `which the parcel would not accept: ${message}`,
      );
      await this.prisma.deliveryDispatch.update({
        where: { id: dispatch.id },
        data: { lastError: message },
      });
    }
  }

  private timestampsFor(
    status: ShipmentStatus,
    at: Date,
  ): Partial<Record<'pickedUpAt' | 'deliveredAt' | 'returnedAt' | 'cancelledAt' | 'assignedAt', Date>> {
    switch (status) {
      case ShipmentStatus.ASSIGNED:
        return { assignedAt: at };
      case ShipmentStatus.PICKED_UP:
        return { pickedUpAt: at };
      case ShipmentStatus.DELIVERED:
        return { deliveredAt: at };
      case ShipmentStatus.RETURNED:
        return { returnedAt: at };
      case ShipmentStatus.CANCELLED:
        return { cancelledAt: at };
      default:
        return {};
    }
  }

  // ── Reading ───────────────────────────────────────────────────────────

  /** What the buyer, the seller and the admin are allowed to see about a carrier. */
  async publicView(shipmentId: string) {
    const dispatch = await this.prisma.deliveryDispatch.findUnique({
      where: { shipmentId },
      include: { provider: { select: { displayName: true, code: true } } },
    });
    if (!dispatch) return null;

    return {
      provider: dispatch.provider.displayName,
      provider_code: dispatch.providerCode,
      status: dispatch.status.toLowerCase(),
      tracking_number: dispatch.trackingNumber,
      tracking_url: dispatch.trackingUrl,
      fee:
        dispatch.feeAmount && dispatch.feeCurrency
          ? Money.of(dispatch.feeAmount, dispatch.feeCurrency).toJSON()
          : null,
      assigned_at: dispatch.assignedAt,
      picked_up_at: dispatch.pickedUpAt,
      delivered_at: dispatch.deliveredAt,
      returned_at: dispatch.returnedAt,
      cancelled_at: dispatch.cancelledAt,
      failure_reason: dispatch.failureReason,
      attempt_count: dispatch.attemptCount,
    };
  }

  /**
   * A quote from the carrier that would actually carry it, where the carrier
   * prices by API. Null means "use the platform's own zone table" — checkout
   * must never fail because a carrier's pricing endpoint is slow.
   */
  async quote(input: {
    governorate: string;
    city: string;
    district?: string | null;
    currency: Currency;
    isExpress: boolean;
    declaredValue?: string | null;
  }): Promise<{ amount: string; currency: Currency; provider: string } | null> {
    const account = await this.selectProvider(input.governorate);
    if (!account || !account.supportsQuote) return null;

    const provider = this.registry.get(account.adapter);
    if (!provider.calculateDeliveryFee) return null;

    try {
      const quote = await provider.calculateDeliveryFee(account, {
        pickup: { governorate: input.governorate, city: input.city, district: null },
        dropoff: {
          governorate: input.governorate,
          city: input.city,
          district: input.district ?? null,
        },
        currency: input.currency,
        isExpress: input.isExpress,
        declaredValue: input.declaredValue ?? null,
      });
      return {
        amount: quote.amount,
        currency: quote.currency,
        provider: account.displayName,
      };
    } catch (error) {
      this.logger.warn(
        `Quote from ${account.code} failed, falling back to the zone table: ${(error as Error).message}`,
      );
      return null;
    }
  }
}
