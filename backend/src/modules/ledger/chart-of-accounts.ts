import { LedgerAccountCode, LedgerAccountKind } from '@prisma/client';

/**
 * The chart of accounts: what kind each account code is, and whether it
 * belongs to a party or to the platform.
 *
 * Keeping this as data rather than scattering `if (code === ...)` through the
 * services means a new account is one row here, and the invariants below
 * (natural balance, ownership) apply to it automatically.
 */
/** Which table a per-owner account's owner lives in. */
export type AccountOwnerType = 'USER' | 'COURIER';

export interface AccountDefinition {
  readonly kind: LedgerAccountKind;
  /**
   * True when the code names one account *per party* — a seller's payable, a
   * customer's wallet. False for platform singletons like `PLATFORM_CASH`.
   */
  readonly perOwner: boolean;
  /**
   * Which foreign key holds the owner. Only meaningful when [perOwner]; a
   * courier is not a user, so its cash account hangs off `courierId`.
   */
  readonly ownerType?: AccountOwnerType;
  /** Short English label for admin screens and exports. */
  readonly label: string;
}

export const CHART_OF_ACCOUNTS: Readonly<
  Record<LedgerAccountCode, AccountDefinition>
> = Object.freeze({
  // ── Assets ────────────────────────────────────────────────────────────
  [LedgerAccountCode.PLATFORM_CASH]: {
    kind: LedgerAccountKind.ASSET,
    perOwner: false,
    label: 'Platform cash',
  },
  [LedgerAccountCode.COURIER_CASH_IN_TRANSIT]: {
    kind: LedgerAccountKind.ASSET,
    // One per courier, so a settlement shortfall is attributable to a person.
    perOwner: true,
    ownerType: 'COURIER',
    label: 'Courier cash in transit',
  },
  [LedgerAccountCode.GATEWAY_RECEIVABLE]: {
    kind: LedgerAccountKind.ASSET,
    perOwner: false,
    label: 'Payment gateway receivable',
  },

  // ── Liabilities ───────────────────────────────────────────────────────
  [LedgerAccountCode.SELLER_ESCROW]: {
    kind: LedgerAccountKind.LIABILITY,
    perOwner: true,
    ownerType: 'USER',
    label: 'Seller escrow (within return window)',
  },
  [LedgerAccountCode.SELLER_PAYABLE]: {
    kind: LedgerAccountKind.LIABILITY,
    perOwner: true,
    ownerType: 'USER',
    label: 'Seller payable',
  },
  [LedgerAccountCode.CUSTOMER_WALLET]: {
    kind: LedgerAccountKind.LIABILITY,
    perOwner: true,
    ownerType: 'USER',
    label: 'Customer wallet',
  },
  [LedgerAccountCode.DISPUTE_HELD]: {
    kind: LedgerAccountKind.LIABILITY,
    perOwner: true,
    ownerType: 'USER',
    label: 'Funds held pending dispute',
  },
  [LedgerAccountCode.LOYALTY_LIABILITY]: {
    kind: LedgerAccountKind.LIABILITY,
    perOwner: false,
    label: 'Loyalty points outstanding',
  },
  [LedgerAccountCode.COURIER_PAYABLE]: {
    kind: LedgerAccountKind.LIABILITY,
    // One per carrier, and hung off `courierId` for the same reason the
    // in-transit cash account is: a courier is not a user. The two together
    // give an operator both sides of a carrier relationship — the cash it
    // holds of ours, and the fees we owe it.
    perOwner: true,
    ownerType: 'COURIER',
    label: 'Delivery fees payable to carrier',
  },

  // ── Revenue ───────────────────────────────────────────────────────────
  [LedgerAccountCode.COMMISSION_REVENUE]: {
    kind: LedgerAccountKind.REVENUE,
    perOwner: false,
    label: 'Commission revenue',
  },
  [LedgerAccountCode.PROMOTION_REVENUE]: {
    kind: LedgerAccountKind.REVENUE,
    perOwner: false,
    label: 'Promotion revenue',
  },
  [LedgerAccountCode.SHIPPING_REVENUE]: {
    kind: LedgerAccountKind.REVENUE,
    perOwner: false,
    label: 'Shipping revenue',
  },

  // ── Expense ───────────────────────────────────────────────────────────
  [LedgerAccountCode.SHIPPING_EXPENSE]: {
    kind: LedgerAccountKind.EXPENSE,
    perOwner: false,
    label: 'Shipping expense',
  },
  [LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE]: {
    kind: LedgerAccountKind.EXPENSE,
    perOwner: false,
    label: 'Platform-funded promotions',
  },

  // ── Adjustments ───────────────────────────────────────────────────────
  [LedgerAccountCode.FX_ADJUSTMENT]: {
    kind: LedgerAccountKind.EXPENSE,
    perOwner: false,
    label: 'FX adjustment',
  },
  [LedgerAccountCode.ROUNDING_ADJUSTMENT]: {
    kind: LedgerAccountKind.EXPENSE,
    perOwner: false,
    label: 'Rounding adjustment',
  },
  [LedgerAccountCode.SUSPENSE]: {
    kind: LedgerAccountKind.EXPENSE,
    perOwner: false,
    label: 'Suspense',
  },
});

/**
 * Debit-normal kinds: a debit increases them. The rest are credit-normal.
 *
 * This is the single place the sign convention is decided; every balance
 * update in `LedgerService` derives from it.
 */
const DEBIT_NORMAL: ReadonlySet<LedgerAccountKind> = new Set([
  LedgerAccountKind.ASSET,
  LedgerAccountKind.EXPENSE,
]);

export function isDebitNormal(kind: LedgerAccountKind): boolean {
  return DEBIT_NORMAL.has(kind);
}

export function definitionOf(code: LedgerAccountCode): AccountDefinition {
  return CHART_OF_ACCOUNTS[code];
}
