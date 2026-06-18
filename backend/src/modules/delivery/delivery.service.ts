import { Injectable } from '@nestjs/common';

interface GovernorateConfig {
  name: string;
  fee: number;
  etaDays: number;
}

/**
 * Syria delivery zones. Fees + ETA are config-driven so they can later be moved
 * to the database / an admin panel without touching the checkout flow.
 */
const GOVERNORATES: GovernorateConfig[] = [
  { name: 'Damascus', fee: 5, etaDays: 1 },
  { name: 'Rif Dimashq', fee: 6, etaDays: 2 },
  { name: 'Aleppo', fee: 8, etaDays: 3 },
  { name: 'Homs', fee: 7, etaDays: 2 },
  { name: 'Hama', fee: 7, etaDays: 3 },
  { name: 'Latakia', fee: 8, etaDays: 3 },
  { name: 'Tartus', fee: 8, etaDays: 3 },
  { name: 'Idlib', fee: 9, etaDays: 4 },
  { name: 'Daraa', fee: 7, etaDays: 3 },
  { name: 'As-Suwayda', fee: 8, etaDays: 3 },
  { name: 'Quneitra', fee: 8, etaDays: 4 },
  { name: 'Deir ez-Zor', fee: 12, etaDays: 5 },
  { name: 'Raqqa', fee: 12, etaDays: 5 },
  { name: 'Al-Hasakah', fee: 12, etaDays: 5 },
];

const DEFAULT_FEE = 10;
const DEFAULT_ETA_DAYS = 4;
/** Orders above this subtotal ship free. */
const FREE_SHIPPING_THRESHOLD = 300;

@Injectable()
export class DeliveryService {
  private readonly byKey = new Map<string, GovernorateConfig>(
    GOVERNORATES.map((g) => [g.name.toLowerCase(), g]),
  );

  listGovernorates() {
    return GOVERNORATES.map((g) => ({
      name: g.name,
      fee: g.fee,
      eta_days: g.etaDays,
    }));
  }

  private config(governorate: string): GovernorateConfig | undefined {
    return this.byKey.get(governorate.trim().toLowerCase());
  }

  feeFor(governorate: string, subtotal = 0): number {
    if (subtotal >= FREE_SHIPPING_THRESHOLD) return 0;
    return this.config(governorate)?.fee ?? DEFAULT_FEE;
  }

  etaDaysFor(governorate: string): number {
    return this.config(governorate)?.etaDays ?? DEFAULT_ETA_DAYS;
  }

  estimatedDeliveryAt(governorate: string): Date {
    const d = new Date();
    d.setDate(d.getDate() + this.etaDaysFor(governorate));
    return d;
  }

  quote(governorate: string, subtotal = 0) {
    const fee = this.feeFor(governorate, subtotal);
    const etaDays = this.etaDaysFor(governorate);
    return {
      governorate,
      delivery_fee: fee,
      free_shipping: fee === 0,
      estimated_days: etaDays,
      estimated_delivery_at: this.estimatedDeliveryAt(governorate).toISOString(),
    };
  }
}
