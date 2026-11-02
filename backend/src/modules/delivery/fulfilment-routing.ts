import { FulfilmentMode } from '@prisma/client';

/** The part of a boutique's delivery settings that decides who carries a parcel. */
export interface SelfDeliveryArea {
  readonly selfDeliveryEnabled: boolean;
  readonly selfDeliveryGovernorates: readonly string[];
  readonly selfDeliveryCities: readonly string[];
}

/** Trims, lower-cases and folds the Arabic letter variants people type interchangeably. */
export function normalisePlace(value: string | null | undefined): string {
  return (value ?? '')
    .trim()
    .toLowerCase()
    .replace(/[أإآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/\s+/g, ' ');
}

/**
 * Who carries a parcel to this address.
 *
 * The seller herself when she delivers and the address is inside her area;
 * the platform's contracted carriers otherwise. An empty governorate list
 * means "everywhere", and a city list narrows it further.
 */
export function fulfilmentModeFor(
  settings: SelfDeliveryArea | null | undefined,
  destination: { governorate: string; city?: string | null },
): FulfilmentMode {
  if (!settings?.selfDeliveryEnabled) return FulfilmentMode.PLATFORM_COURIER;

  const governorate = normalisePlace(destination.governorate);
  const city = normalisePlace(destination.city);

  const governorates = settings.selfDeliveryGovernorates.map(normalisePlace);
  if (governorates.length > 0 && !governorates.includes(governorate)) {
    return FulfilmentMode.PLATFORM_COURIER;
  }

  const cities = settings.selfDeliveryCities.map(normalisePlace);
  if (cities.length > 0 && !cities.includes(city)) {
    return FulfilmentMode.PLATFORM_COURIER;
  }

  return FulfilmentMode.SELLER_SHIPS;
}
