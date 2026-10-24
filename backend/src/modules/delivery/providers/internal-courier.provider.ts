import { Injectable, Logger } from '@nestjs/common';
import {
  Courier,
  DeliveryProviderAccount,
  ShipmentStatus,
} from '@prisma/client';

import { PrismaService } from '../../../prisma/prisma.service';
import {
  CancelDeliveryInput,
  CreateDeliveryInput,
  CreateDeliveryResult,
  DeliveryProvider,
  DeliveryStatusResult,
  TrackingResult,
  WebhookRequest,
  WebhookVerdict,
} from './delivery-provider.interface';

/**
 * The platform's own fleet, wearing the same interface as a delivery company.
 *
 * Ohara is not going to run drivers — that is the whole point of this
 * subsystem — but it does have an in-house courier today, and a closed beta
 * that has to keep working while a carrier contract is signed. Modelling that
 * fleet as one more provider is what stops the dispatch path from having a
 * special case: `ready()` dispatches, and whether the parcel goes to a courier
 * on the payroll or to a company's API is a row in the database.
 *
 * "Creating a delivery" here means choosing which courier is carrying it. The
 * courier's own screens (pick-up, out for delivery, delivered) already exist
 * and already move the shipment, so this adapter has nothing to poll and no
 * callbacks to verify.
 */
@Injectable()
export class InternalCourierProvider implements DeliveryProvider {
  readonly code = 'internal';
  readonly displayName = 'فريق أوهارا للتوصيل';

  private readonly logger = new Logger(InternalCourierProvider.name);

  constructor(private readonly prisma: PrismaService) {}

  async createDelivery(
    account: DeliveryProviderAccount,
    input: CreateDeliveryInput,
  ): Promise<CreateDeliveryResult> {
    const courier = account.courierId
      ? await this.prisma.courier.findFirst({
          where: { id: account.courierId, isActive: true },
        })
      : await this.pickCourier(input.dropoff.governorate);

    if (!courier) {
      throw new Error(
        `No active courier covers ${input.dropoff.governorate}`,
      );
    }

    return {
      // The parcel's own reference is the id here, exactly as a delivery
      // company's would be — one delivery, one identifier. (Using the courier's
      // id instead would mean a rider could only ever carry one parcel, which
      // the `(provider, external_delivery_id)` uniqueness enforces.)
      externalDeliveryId: input.reference,
      internalCourierId: courier.id,
      status: ShipmentStatus.ASSIGNED,
      providerStatus: 'assigned',
      trackingNumber: null,
      fee: null,
      raw: { courier: courier.displayName },
    };
  }

  async cancelDelivery(
    _account: DeliveryProviderAccount,
    _input: CancelDeliveryInput,
  ): Promise<void> {
    // Nothing to call: the orchestrator cancels the shipment itself, which is
    // all "cancelling" means for a courier on the payroll.
  }

  async getDeliveryStatus(
    _account: DeliveryProviderAccount,
    _externalDeliveryId: string,
  ): Promise<DeliveryStatusResult> {
    // The fleet writes straight into `Shipment` through the courier screens,
    // so there is no outside source of truth to reconcile against. Saying so
    // is more honest than inventing a status.
    throw new Error('The in-house fleet has no status endpoint to poll');
  }

  async getTracking(
    _account: DeliveryProviderAccount,
    _externalDeliveryId: string,
  ): Promise<TrackingResult> {
    throw new Error('The in-house fleet is tracked from the shipment itself');
  }

  async handleWebhook(
    _account: DeliveryProviderAccount,
    _request: WebhookRequest,
  ): Promise<WebhookVerdict> {
    return {
      signatureValid: false,
      events: [],
      error: 'The in-house fleet does not send callbacks',
    };
  }

  /**
   * The courier for a governorate: one that covers it, else one that lists no
   * governorates at all (a nationwide fleet), and among those the one with the
   * lightest live round. A fair spread is the whole job here; ops can still
   * move a parcel by hand.
   */
  private async pickCourier(governorate: string): Promise<Courier | null> {
    const candidates = await this.prisma.courier.findMany({
      where: {
        isActive: true,
        OR: [
          { governorates: { has: governorate } },
          { governorates: { isEmpty: true } },
        ],
      },
    });
    if (candidates.length === 0) return null;

    const covering = candidates.filter((courier) =>
      courier.governorates.includes(governorate),
    );
    const pool = covering.length > 0 ? covering : candidates;
    if (pool.length === 1) return pool[0];

    const load = await this.prisma.shipment.groupBy({
      by: ['courierId'],
      where: {
        courierId: { in: pool.map((courier) => courier.id) },
        status: {
          in: [
            ShipmentStatus.ASSIGNED,
            ShipmentStatus.PICKED_UP,
            ShipmentStatus.IN_TRANSIT,
            ShipmentStatus.OUT_FOR_DELIVERY,
          ],
        },
      },
      _count: { _all: true },
    });
    const live = new Map(
      load.map((row) => [row.courierId as string, row._count._all]),
    );

    return pool.reduce((lightest, courier) =>
      (live.get(courier.id) ?? 0) < (live.get(lightest.id) ?? 0)
        ? courier
        : lightest,
    );
  }
}
