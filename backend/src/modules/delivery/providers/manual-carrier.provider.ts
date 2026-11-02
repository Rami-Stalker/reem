import { Injectable } from '@nestjs/common';
import {
  CourierKind,
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
 * A delivery company the platform works by phone and WhatsApp — no API.
 *
 * Most carriers in Syria have no integration to call, and before this adapter
 * such a company could not carry a parcel at all: nobody on its side could
 * move the parcel, so it sat «جاهز للشحن» for ever. Here "creating a delivery"
 * means recording that the company has it. Its driver then reports through
 * the driver link (`CarrierLinkService`) and the seller can relay what the
 * company told her; both go through the same status path a webhook does.
 *
 * The company is also a `Courier` row of kind THIRD_PARTY, created on first
 * use, so cash it collects at the door is booked against it and settles like
 * any courier's.
 */
@Injectable()
export class ManualCarrierProvider implements DeliveryProvider {
  readonly code = 'manual';
  readonly displayName = 'شركة توصيل متعاقدة (بدون ربط تقني)';

  constructor(private readonly prisma: PrismaService) {}

  async createDelivery(
    account: DeliveryProviderAccount,
    input: CreateDeliveryInput,
  ): Promise<CreateDeliveryResult> {
    const courierId = await this.companyCourier(account);
    return {
      externalDeliveryId: input.reference,
      trackingNumber: input.reference,
      internalCourierId: courierId,
      status: ShipmentStatus.ASSIGNED,
      providerStatus: 'assigned',
      fee: null,
    };
  }

  async cancelDelivery(
    _account: DeliveryProviderAccount,
    _input: CancelDeliveryInput,
  ): Promise<void> {
    // Nothing to call — the company is told by phone, and the dispatch row
    // is cancelled by the orchestrator.
  }

  async getDeliveryStatus(): Promise<DeliveryStatusResult> {
    throw new Error('A carrier worked by phone has no status endpoint to poll');
  }

  async getTracking(): Promise<TrackingResult> {
    throw new Error('A carrier worked by phone is tracked from the shipment itself');
  }

  async handleWebhook(
    _account: DeliveryProviderAccount,
    _request: WebhookRequest,
  ): Promise<WebhookVerdict> {
    return {
      signatureValid: false,
      events: [],
      error: 'A carrier worked by phone reports through its driver link',
    };
  }

  /** The company's own courier row — the one its cash is held against. */
  private async companyCourier(account: DeliveryProviderAccount): Promise<string> {
    if (account.courierId) return account.courierId;

    return this.prisma.$transaction(async (tx) => {
      const fresh = await tx.deliveryProviderAccount.findUniqueOrThrow({
        where: { id: account.id },
        select: { courierId: true },
      });
      if (fresh.courierId) return fresh.courierId;

      const courier = await tx.courier.create({
        data: {
          kind: CourierKind.THIRD_PARTY,
          displayName: account.displayName,
          companyName: account.displayName,
          phone: '',
          governorates: account.governorates,
        },
      });
      await tx.deliveryProviderAccount.update({
        where: { id: account.id },
        data: { courierId: courier.id },
      });
      return courier.id;
    });
  }
}
