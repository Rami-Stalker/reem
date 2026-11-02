import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  DeliveryDispatch,
  DeliveryFailureReason,
  DeliveryProviderKind,
  ShipmentStatus,
} from '@prisma/client';

import { Money } from '../../../common/money';
import { PrismaService } from '../../../prisma/prisma.service';
import { ShipmentsService } from '../shipments.service';
import { isTerminalDeliveryStatus } from '../providers/delivery-status.map';
import { DeliveryDispatchService } from './delivery-dispatch.service';

/** What a carrier's driver, or a seller relaying for one, may report. */
export type CarrierStep = 'pick_up' | 'out_for_delivery' | 'deliver' | 'fail';

export const CARRIER_STEPS: readonly CarrierStep[] = [
  'pick_up',
  'out_for_delivery',
  'deliver',
  'fail',
];

export interface CarrierStepInput {
  readonly handoverCode?: string;
  readonly collected?: string;
  readonly reason?: DeliveryFailureReason;
  readonly note?: string;
}

/** The statuses each step walks through, in order. */
const STEP_PATH: Readonly<Record<CarrierStep, readonly ShipmentStatus[]>> = {
  pick_up: [ShipmentStatus.PICKED_UP],
  out_for_delivery: [ShipmentStatus.PICKED_UP, ShipmentStatus.OUT_FOR_DELIVERY],
  deliver: [
    ShipmentStatus.PICKED_UP,
    ShipmentStatus.OUT_FOR_DELIVERY,
    ShipmentStatus.DELIVERED,
  ],
  fail: [
    ShipmentStatus.PICKED_UP,
    ShipmentStatus.OUT_FOR_DELIVERY,
    ShipmentStatus.FAILED,
  ],
};

/** Progress order, so a step never walks a parcel backwards. */
const ORDER: readonly ShipmentStatus[] = [
  ShipmentStatus.CREATED,
  ShipmentStatus.ASSIGNED,
  ShipmentStatus.PICKED_UP,
  ShipmentStatus.IN_TRANSIT,
  ShipmentStatus.OUT_FOR_DELIVERY,
];

/**
 * The driver link: how a delivery company with no API reports a parcel.
 *
 * Each parcel handed to a MANUAL carrier gets a secret link. The seller (or
 * ops) forwards it to the company on WhatsApp; the driver opens it in any
 * phone browser — no account, no app — and taps picked up, on the way,
 * delivered (with the customer's code) or failed. The link moves that one
 * parcel and nothing else.
 *
 * The seller can make the same reports from her own screen, for the company
 * that phones her instead of opening the link.
 *
 * Every report goes through `DeliveryDispatchService.applyStatus`, the door a
 * carrier webhook uses, so the dispatch row, the shipment, the sub-order, the
 * cash and the settlement all move exactly as they would for an integrated
 * carrier.
 */
@Injectable()
export class CarrierLinkService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly dispatches: DeliveryDispatchService,
    private readonly shipments: ShipmentsService,
  ) {}

  // ── The driver's side ─────────────────────────────────────────────────

  /** What the driver needs at the door, and nothing more. */
  async view(token: string) {
    const dispatch = await this.byToken(token);
    const shipment = await this.prisma.shipment.findUniqueOrThrow({
      where: { id: dispatch.shipmentId },
      include: {
        sellerOrder: {
          select: {
            number: true,
            seller: { select: { name: true, phone: true, location: true } },
            order: {
              select: {
                recipientName: true,
                recipientPhone: true,
                governorate: true,
                city: true,
                district: true,
                addressLine: true,
                landmark: true,
                latitude: true,
                longitude: true,
                deliveryInstructions: true,
              },
            },
          },
        },
      },
    });
    const order = shipment.sellerOrder.order;
    const finished = isTerminalDeliveryStatus(shipment.status);

    return {
      carrier: dispatch.providerCode,
      tracking_code: shipment.trackingCode,
      order_number: shipment.sellerOrder.number,
      status: shipment.status.toLowerCase(),
      finished,
      // Only while the parcel is out there: a closed link must not keep
      // handing out a woman's address and phone.
      pickup: finished
        ? null
        : {
            name: shipment.sellerOrder.seller.name,
            phone: shipment.sellerOrder.seller.phone,
            location: shipment.sellerOrder.seller.location,
          },
      recipient: finished
        ? null
        : {
            name: order.recipientName,
            phone: shipment.maskedPhone ?? order.recipientPhone,
            governorate: order.governorate,
            city: order.city,
            district: order.district,
            address_line: order.addressLine,
            landmark: order.landmark,
            latitude: order.latitude,
            longitude: order.longitude,
            delivery_instructions: order.deliveryInstructions,
          },
      cod_amount: shipment.codAmount
        ? Money.of(shipment.codAmount, shipment.currency).toJSON()
        : null,
      handover_code_required: shipment.handoverCode != null && shipment.codAmount == null,
      attempt_count: shipment.attemptCount,
      available_steps: finished ? [] : this.stepsFrom(shipment.status),
    };
  }

  async actByToken(token: string, step: CarrierStep, input: CarrierStepInput) {
    const dispatch = await this.byToken(token);
    await this.act(dispatch, step, input);
    return this.view(token);
  }

  // ── The seller relaying for the company ───────────────────────────────

  /** True when this sub-order is with a carrier worked by phone. */
  async manualDispatchFor(sellerOrderId: string): Promise<DeliveryDispatch | null> {
    const shipment = await this.prisma.shipment.findUnique({
      where: { sellerOrderId },
      select: { dispatch: { include: { provider: { select: { kind: true } } } } },
    });
    const dispatch = shipment?.dispatch;
    if (!dispatch || dispatch.provider.kind !== DeliveryProviderKind.MANUAL) return null;
    if (!dispatch.externalDeliveryId) return null;
    return dispatch;
  }

  async relayForSeller(sellerOrderId: string, step: CarrierStep, input: CarrierStepInput) {
    const dispatch = await this.manualDispatchFor(sellerOrderId);
    if (!dispatch) {
      throw new ForbiddenException(
        'هذا الطلب مع شركة توصيل مربوطة تقنيًا أو مع مندوب المنصة — حالته تُحدَّث تلقائيًا',
      );
    }
    await this.act(dispatch, step, input);
  }

  /** The steps a parcel in this status can take next. */
  stepsFrom(status: ShipmentStatus): CarrierStep[] {
    switch (status) {
      case ShipmentStatus.CREATED:
      case ShipmentStatus.ASSIGNED:
        return ['pick_up'];
      case ShipmentStatus.PICKED_UP:
      case ShipmentStatus.IN_TRANSIT:
        return ['out_for_delivery', 'deliver', 'fail'];
      case ShipmentStatus.OUT_FOR_DELIVERY:
        return ['deliver', 'fail'];
      case ShipmentStatus.FAILED:
        return ['out_for_delivery', 'deliver', 'fail'];
      default:
        return [];
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────

  private async act(dispatch: DeliveryDispatch, step: CarrierStep, input: CarrierStepInput) {
    if (!CARRIER_STEPS.includes(step)) throw new NotFoundException('Unknown step');

    const shipment = await this.prisma.shipment.findUniqueOrThrow({
      where: { id: dispatch.shipmentId },
    });
    if (isTerminalDeliveryStatus(shipment.status)) {
      throw new BadRequestException('هذه الشحنة مغلقة');
    }
    if (!this.stepsFrom(shipment.status).includes(step)) {
      throw new BadRequestException(
        `لا يمكن تنفيذ هذه الخطوة والشحنة في حالة ${shipment.status.toLowerCase()}`,
      );
    }

    // Checked before anything moves, so a wrong code changes nothing but
    // the attempt counter.
    let handoverVerified = false;
    if (step === 'deliver') {
      handoverVerified = await this.shipments.checkHandover(shipment, input.handoverCode);
    }
    if (step === 'fail' && !input.reason) {
      throw new BadRequestException('اختر سبب فشل التسليم');
    }

    const from = shipment.status;
    for (const to of STEP_PATH[step]) {
      if (this.alreadyPast(from, to)) continue;
      const fresh = await this.prisma.deliveryDispatch.findUniqueOrThrow({
        where: { id: dispatch.id },
      });
      await this.dispatches.applyStatus(
        fresh,
        {
          externalDeliveryId: fresh.externalDeliveryId ?? '',
          status: to,
          providerStatus: to.toLowerCase(),
          occurredAt: new Date(),
          failureReason: to === ShipmentStatus.FAILED ? input.reason ?? null : null,
          failureNote: to === ShipmentStatus.FAILED ? input.note ?? null : null,
          collectedAmount: to === ShipmentStatus.DELIVERED ? input.collected ?? null : null,
        },
        { handoverVerified },
      );

      // `applyStatus` records a refusal rather than throwing it — right for a
      // webhook nobody is watching, wrong for a person waiting on a button.
      const after = await this.prisma.shipment.findUniqueOrThrow({
        where: { id: shipment.id },
        select: { status: true },
      });
      if (after.status !== to) {
        const reason = await this.prisma.deliveryDispatch.findUnique({
          where: { id: dispatch.id },
          select: { lastError: true },
        });
        throw new BadRequestException(
          reason?.lastError ?? 'لم تُقبل هذه الخطوة — تحقّق من حالة الطلب',
        );
      }
    }
  }

  /** True when a parcel at `from` has already made the step to `to`. */
  private alreadyPast(from: ShipmentStatus, to: ShipmentStatus): boolean {
    if (from === ShipmentStatus.FAILED) {
      // A retry goes back on the road; picked-up is long behind it.
      return to === ShipmentStatus.PICKED_UP;
    }
    const a = ORDER.indexOf(from);
    const b = ORDER.indexOf(to);
    return a >= 0 && b >= 0 && a >= b;
  }

  private async byToken(token: string): Promise<DeliveryDispatch> {
    if (!token || token.length < 16 || token.length > 64) {
      throw new NotFoundException('الرابط غير صالح');
    }
    const dispatch = await this.prisma.deliveryDispatch.findUnique({
      where: { carrierLinkToken: token },
    });
    if (!dispatch) throw new NotFoundException('الرابط غير صالح');
    return dispatch;
  }
}
