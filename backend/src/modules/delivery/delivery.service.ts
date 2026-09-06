import { Injectable, NotFoundException } from '@nestjs/common';
import { Currency, Prisma, ShippingZone } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money } from '../../common/money';

export interface ShippingQuote {
  readonly zone: ShippingZone | null;
  readonly fee: Money;
  readonly etaHoursMin: number;
  readonly etaHoursMax: number;
  readonly estimatedDeliveryAt: Date;
  readonly isFree: boolean;
}

/**
 * Shipping rates and ETAs.
 *
 * These used to be a hardcoded array of fourteen governorates with unitless
 * numeric fees compiled into the source, which meant nobody could change a
 * price without a deploy and no fee knew what currency it was in. Zones now
 * live in `shipping_zones`: per governorate, split by district and by
 * city-centre vs rural (Q53), each carrying a currency, a floor and a ceiling
 * inside which the seller may set their own fee (Q54).
 */
@Injectable()
export class DeliveryService {
  constructor(private readonly prisma: PrismaService) {}

  async listZones() {
    const zones = await this.prisma.shippingZone.findMany({
      where: { isActive: true },
      orderBy: [{ governorate: 'asc' }, { district: 'asc' }],
    });
    return zones.map((zone) => this.serializeZone(zone));
  }

  async listGovernorates() {
    const zones = await this.prisma.shippingZone.findMany({
      where: { isActive: true },
      orderBy: { governorate: 'asc' },
    });

    const byGovernorate = new Map<string, ShippingZone[]>();
    for (const zone of zones) {
      const group = byGovernorate.get(zone.governorate) ?? [];
      group.push(zone);
      byGovernorate.set(zone.governorate, group);
    }

    return [...byGovernorate.entries()].map(([governorate, group]) => ({
      governorate,
      districts: group
        .filter((zone) => zone.district !== null)
        .map((zone) => ({
          name: zone.district,
          is_rural: zone.isRural,
          fee: Money.of(zone.baseFee, zone.currency).toJSON(),
          eta_hours_min: zone.etaHoursMin,
          eta_hours_max: zone.etaHoursMax,
        })),
      fee: Money.of(group[0].baseFee, group[0].currency).toJSON(),
      eta_hours_min: Math.min(...group.map((zone) => zone.etaHoursMin)),
      eta_hours_max: Math.max(...group.map((zone) => zone.etaHoursMax)),
    }));
  }

  /**
   * Resolves the zone for an address. Falls back from the exact district to the
   * governorate-wide row, so a new district does not break checkout.
   */
  async resolveZone(
    governorate: string,
    district?: string | null,
    isRural = false,
  ): Promise<ShippingZone | null> {
    if (district) {
      const exact = await this.prisma.shippingZone.findFirst({
        where: {
          governorate: { equals: governorate, mode: 'insensitive' },
          district: { equals: district, mode: 'insensitive' },
          isRural,
          isActive: true,
        },
      });
      if (exact) return exact;
    }

    return this.prisma.shippingZone.findFirst({
      where: {
        governorate: { equals: governorate, mode: 'insensitive' },
        district: null,
        isActive: true,
      },
      orderBy: { isRural: 'asc' },
    });
  }

  /**
   * A shipping quote for one destination.
   *
   * `freeAbove` (Q54 P1 — free shipping over a threshold) is passed in by the
   * caller rather than read from a constant, because the threshold is a
   * membership benefit and differs per customer tier.
   */
  async quote(input: {
    governorate: string;
    district?: string | null;
    isRural?: boolean;
    isExpress?: boolean;
    subtotal?: Money;
    freeAbove?: Money | null;
  }): Promise<ShippingQuote> {
    const zone = await this.resolveZone(
      input.governorate,
      input.district,
      input.isRural ?? false,
    );

    if (!zone) {
      throw new NotFoundException(
        `We do not deliver to ${input.governorate} yet`,
      );
    }

    const currency = zone.currency;
    let fee = Money.of(
      input.isExpress && zone.expressFee ? zone.expressFee : zone.baseFee,
      currency,
    );

    const qualifiesFree =
      input.freeAbove != null &&
      input.subtotal != null &&
      input.subtotal.currency === input.freeAbove.currency &&
      input.subtotal.greaterThanOrEqual(input.freeAbove);

    if (qualifiesFree) fee = Money.zero(currency);

    return {
      zone,
      fee,
      etaHoursMin: zone.etaHoursMin,
      etaHoursMax: zone.etaHoursMax,
      estimatedDeliveryAt: this.etaFrom(zone.etaHoursMax),
      isFree: fee.isZero(),
    };
  }

  /**
   * Q54 P2 — the seller picks their own fee, but the platform bounds it. Used
   * when a sub-order is fulfilled by the seller rather than a platform courier.
   */
  clampToZone(fee: Money, zone: ShippingZone): Money {
    return fee
      .clampMin(Money.of(zone.minFee, zone.currency))
      .clampMax(Money.of(zone.maxFee, zone.currency));
  }

  private etaFrom(hours: number): Date {
    const eta = new Date();
    eta.setHours(eta.getHours() + hours);
    return eta;
  }

  private serializeZone(zone: ShippingZone) {
    return {
      id: zone.id,
      governorate: zone.governorate,
      district: zone.district,
      is_rural: zone.isRural,
      currency: zone.currency,
      base_fee: Money.of(zone.baseFee, zone.currency).toJSON(),
      min_fee: Money.of(zone.minFee, zone.currency).toJSON(),
      max_fee: Money.of(zone.maxFee, zone.currency).toJSON(),
      express_fee: zone.expressFee
        ? Money.of(zone.expressFee, zone.currency).toJSON()
        : null,
      eta_hours_min: zone.etaHoursMin,
      eta_hours_max: zone.etaHoursMax,
      supports_pickup_point: zone.supportsPickupPoint,
    };
  }
}

/**
 * Default SYP zone rows, used by the seeder.
 *
 * Fees are in **new** Syrian pounds: 150 here is the 15,000 this table
 * carried before the redenomination, which is the same delivery charge with
 * two fewer zeros on it.
 */
export const DEFAULT_SHIPPING_ZONES: Prisma.ShippingZoneCreateManyInput[] = [
  // Q61 P1 — same-day inside a city; Q62 — one to two days between them.
  zone('دمشق', null, false, 150, 3, 8),
  zone('ريف دمشق', null, true, 200, 6, 24),
  zone('حلب', null, false, 250, 24, 48),
  zone('حمص', null, false, 220, 24, 48),
  zone('حماة', null, false, 220, 24, 48),
  zone('اللاذقية', null, false, 250, 24, 48),
  zone('طرطوس', null, false, 250, 24, 48),
  zone('إدلب', null, true, 300, 48, 72),
  zone('درعا', null, false, 240, 24, 48),
  zone('السويداء', null, false, 260, 24, 48),
  zone('القنيطرة', null, true, 280, 48, 72),
  zone('دير الزور', null, true, 400, 72, 120),
  zone('الرقة', null, true, 400, 72, 120),
  zone('الحسكة', null, true, 400, 72, 120),
];

function zone(
  governorate: string,
  district: string | null,
  isRural: boolean,
  baseFee: number,
  etaHoursMin: number,
  etaHoursMax: number,
): Prisma.ShippingZoneCreateManyInput {
  return {
    governorate,
    district,
    isRural,
    currency: Currency.SYP,
    baseFee: new Prisma.Decimal(baseFee),
    minFee: new Prisma.Decimal(Math.round(baseFee * 0.6)),
    maxFee: new Prisma.Decimal(Math.round(baseFee * 1.6)),
    expressFee: new Prisma.Decimal(Math.round(baseFee * 1.8)),
    etaHoursMin,
    etaHoursMax,
    supportsPickupPoint: !isRural,
  };
}
