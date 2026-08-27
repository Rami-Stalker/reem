import { BadRequestException } from '@nestjs/common';
import { OrderStatus, SellerOrderStatus, UserRole } from '@prisma/client';

/**
 * The order lifecycle, as one authority.
 *
 * Before this file the same status list was copy-pasted under three different
 * names in four services (`revenueStatuses`, `settleStatuses`, …) and status
 * transitions were free-form `order.update({ status })` calls, so a sub-order
 * could jump from NEW straight to REFUNDED and nothing would object.
 */

// ── Actors ──────────────────────────────────────────────────────────────

export type StatusActor = 'CUSTOMER' | 'SELLER' | 'COURIER' | 'ADMIN' | 'SYSTEM';

const ADMIN_ROLES: readonly UserRole[] = [
  UserRole.SUPER_ADMIN,
  UserRole.OPERATIONS_ADMIN,
  UserRole.SUPPORT_ADMIN,
  UserRole.FINANCE_ADMIN,
  UserRole.ADMIN,
];

export function actorForRole(role: UserRole): StatusActor {
  if (ADMIN_ROLES.includes(role)) return 'ADMIN';
  if (role === UserRole.SELLER) return 'SELLER';
  return 'CUSTOMER';
}

// ── Sub-order transition table ──────────────────────────────────────────

const T = SellerOrderStatus;

/**
 * Allowed transitions, and who may make them. Admin may perform any listed
 * transition (support intervention, Q70 P1 "التدخل بالطلبات وتعديلها") but
 * still cannot invent an edge that is not in this table.
 */
const SELLER_ORDER_TRANSITIONS: Readonly<
  Record<SellerOrderStatus, ReadonlyArray<{ to: SellerOrderStatus; by: readonly StatusActor[] }>>
> = {
  [T.NEW]: [
    { to: T.AWAITING_SELLER_CONFIRMATION, by: ['SYSTEM'] },
    { to: T.CANCELLED_BY_CUSTOMER, by: ['CUSTOMER', 'ADMIN'] },
    { to: T.CANCELLED_BY_SELLER, by: ['SELLER', 'ADMIN'] },
  ],
  [T.AWAITING_SELLER_CONFIRMATION]: [
    { to: T.PREPARING, by: ['SELLER', 'ADMIN'] },
    { to: T.CANCELLED_BY_CUSTOMER, by: ['CUSTOMER', 'ADMIN'] },
    { to: T.CANCELLED_BY_SELLER, by: ['SELLER', 'ADMIN'] },
  ],
  [T.PREPARING]: [
    { to: T.READY_TO_SHIP, by: ['SELLER', 'ADMIN'] },
    // Q38 P2 — the customer may cancel any time before the parcel ships.
    { to: T.CANCELLED_BY_CUSTOMER, by: ['CUSTOMER', 'ADMIN'] },
    { to: T.CANCELLED_BY_SELLER, by: ['SELLER', 'ADMIN'] },
  ],
  [T.READY_TO_SHIP]: [
    { to: T.HANDED_TO_COURIER, by: ['SELLER', 'COURIER', 'ADMIN'] },
    { to: T.CANCELLED_BY_CUSTOMER, by: ['CUSTOMER', 'ADMIN'] },
    { to: T.CANCELLED_BY_SELLER, by: ['SELLER', 'ADMIN'] },
  ],
  [T.HANDED_TO_COURIER]: [
    { to: T.IN_TRANSIT, by: ['COURIER', 'ADMIN'] },
    { to: T.DELIVERY_FAILED, by: ['COURIER', 'ADMIN'] },
  ],
  [T.IN_TRANSIT]: [
    { to: T.DELIVERED, by: ['COURIER', 'ADMIN'] },
    { to: T.DELIVERY_FAILED, by: ['COURIER', 'ADMIN'] },
    { to: T.REJECTED_ON_DELIVERY, by: ['COURIER', 'ADMIN'] },
  ],
  [T.DELIVERY_FAILED]: [
    // A retry attempt puts the parcel back on the road.
    { to: T.IN_TRANSIT, by: ['COURIER', 'ADMIN'] },
    { to: T.RETURN_IN_TRANSIT, by: ['COURIER', 'ADMIN'] },
    { to: T.CANCELLED_BY_CUSTOMER, by: ['ADMIN'] },
  ],
  [T.REJECTED_ON_DELIVERY]: [
    { to: T.RETURN_IN_TRANSIT, by: ['COURIER', 'ADMIN'] },
    { to: T.REFUND_PENDING, by: ['ADMIN', 'SYSTEM'] },
  ],
  [T.DELIVERED]: [
    { to: T.RETURN_REQUESTED, by: ['CUSTOMER', 'ADMIN'] },
    { to: T.DISPUTED, by: ['CUSTOMER', 'SELLER', 'ADMIN'] },
  ],
  [T.RETURN_REQUESTED]: [
    { to: T.RETURN_IN_TRANSIT, by: ['SELLER', 'COURIER', 'ADMIN'] },
    { to: T.EXCHANGE_IN_PROGRESS, by: ['SELLER', 'ADMIN'] },
    { to: T.DISPUTED, by: ['CUSTOMER', 'SELLER', 'ADMIN'] },
    // Seller refused the return; the order goes back to its delivered state.
    { to: T.DELIVERED, by: ['SELLER', 'ADMIN'] },
  ],
  [T.RETURN_IN_TRANSIT]: [
    { to: T.RETURNED, by: ['SELLER', 'ADMIN'] },
    { to: T.DISPUTED, by: ['CUSTOMER', 'SELLER', 'ADMIN'] },
  ],
  [T.RETURNED]: [
    { to: T.REFUND_PENDING, by: ['ADMIN', 'SYSTEM'] },
    // Q37 P2 — «استبدال جاري». The goods are back and the seller is preparing
    // the replacement instead of the money. Without this edge an exchange
    // could only be declared before the returned parcel arrived, which is the
    // one moment nobody can honestly decide it.
    { to: T.EXCHANGE_IN_PROGRESS, by: ['SELLER', 'ADMIN'] },
  ],
  [T.EXCHANGE_IN_PROGRESS]: [
    { to: T.EXCHANGED, by: ['SELLER', 'ADMIN'] },
    { to: T.DISPUTED, by: ['CUSTOMER', 'SELLER', 'ADMIN'] },
  ],
  [T.EXCHANGED]: [{ to: T.DISPUTED, by: ['CUSTOMER', 'ADMIN'] }],
  [T.REFUND_PENDING]: [{ to: T.REFUNDED, by: ['ADMIN', 'SYSTEM'] }],
  [T.REFUNDED]: [],
  [T.CANCELLED_BY_CUSTOMER]: [{ to: T.REFUND_PENDING, by: ['ADMIN', 'SYSTEM'] }],
  [T.CANCELLED_BY_SELLER]: [{ to: T.REFUND_PENDING, by: ['ADMIN', 'SYSTEM'] }],
  [T.DISPUTED]: [
    { to: T.REFUND_PENDING, by: ['ADMIN'] },
    { to: T.DELIVERED, by: ['ADMIN'] },
    { to: T.RETURN_IN_TRANSIT, by: ['ADMIN'] },
  ],
};

export function canTransition(
  from: SellerOrderStatus,
  to: SellerOrderStatus,
  actor: StatusActor,
): boolean {
  return SELLER_ORDER_TRANSITIONS[from].some(
    (edge) => edge.to === to && (edge.by.includes(actor) || actor === 'ADMIN'),
  );
}

export function assertTransition(
  from: SellerOrderStatus,
  to: SellerOrderStatus,
  actor: StatusActor,
): void {
  if (from === to) {
    throw new BadRequestException(`Order is already ${from}`);
  }
  if (!canTransition(from, to, actor)) {
    throw new BadRequestException(
      `Cannot move a sub-order from ${from} to ${to} as ${actor}`,
    );
  }
}

export function nextStatuses(
  from: SellerOrderStatus,
  actor: StatusActor,
): SellerOrderStatus[] {
  return SELLER_ORDER_TRANSITIONS[from]
    .filter((edge) => edge.by.includes(actor) || actor === 'ADMIN')
    .map((edge) => edge.to);
}

// ── Status sets ─────────────────────────────────────────────────────────

/** Sub-orders that count as realised revenue for reports and commissions. */
export const REVENUE_STATUSES: readonly SellerOrderStatus[] = [
  T.PREPARING,
  T.READY_TO_SHIP,
  T.HANDED_TO_COURIER,
  T.IN_TRANSIT,
  T.DELIVERED,
  T.EXCHANGE_IN_PROGRESS,
  T.EXCHANGED,
];

/** Terminal states — nothing further happens and escrow is settled. */
export const TERMINAL_STATUSES: readonly SellerOrderStatus[] = [
  T.REFUNDED,
  T.EXCHANGED,
];

export const CANCELLED_STATUSES: readonly SellerOrderStatus[] = [
  T.CANCELLED_BY_CUSTOMER,
  T.CANCELLED_BY_SELLER,
  T.REJECTED_ON_DELIVERY,
];

export const SHIPPED_STATUSES: readonly SellerOrderStatus[] = [
  T.HANDED_TO_COURIER,
  T.IN_TRANSIT,
];

/** Q38 P2 — the customer can still cancel while nothing has shipped. */
export const CUSTOMER_CANCELLABLE: readonly SellerOrderStatus[] = [
  T.NEW,
  T.AWAITING_SELLER_CONFIRMATION,
  T.PREPARING,
  T.READY_TO_SHIP,
];

/**
 * Parcels that may still have money collected at the door.
 *
 * A whitelist rather than an exclusion, because the question it answers —
 * "is any of this order's cash still out there?" — must not quietly say no for
 * a status somebody adds later. Everything not listed has either arrived and
 * been collected, or is never going to arrive.
 */
export const AWAITING_COLLECTION: readonly SellerOrderStatus[] = [
  T.NEW,
  T.AWAITING_SELLER_CONFIRMATION,
  T.PREPARING,
  T.READY_TO_SHIP,
  T.HANDED_TO_COURIER,
  T.IN_TRANSIT,
  T.DELIVERY_FAILED,
];

/** Q39 P2 — size/address edits are allowed until preparation starts. */
export const CUSTOMER_EDITABLE: readonly SellerOrderStatus[] = [
  T.NEW,
  T.AWAITING_SELLER_CONFIRMATION,
];

export function isRevenue(status: SellerOrderStatus): boolean {
  return REVENUE_STATUSES.includes(status);
}

export function isCancelled(status: SellerOrderStatus): boolean {
  return CANCELLED_STATUSES.includes(status);
}

// ── Parent derivation ───────────────────────────────────────────────────

/**
 * The parent order's status is never written directly — it is a pure function
 * of its children, which is what makes "partially shipped" and "partially
 * cancelled" representable at all (Q65 P1: one order, several parcels).
 */
export function deriveOrderStatus(
  children: readonly SellerOrderStatus[],
  opts: { paid: boolean },
): OrderStatus {
  if (children.length === 0) {
    return opts.paid ? OrderStatus.CONFIRMED : OrderStatus.PENDING_PAYMENT;
  }
  if (!opts.paid && children.every((s) => s === T.NEW)) {
    return OrderStatus.PENDING_PAYMENT;
  }

  const live = children.filter((s) => !isCancelled(s));
  if (live.length === 0) return OrderStatus.CANCELLED;

  const settled = children.filter(
    (s) => TERMINAL_STATUSES.includes(s) || s === T.RETURNED,
  );
  if (settled.length === children.length) return OrderStatus.CLOSED;

  const delivered = live.filter(
    (s) =>
      s === T.DELIVERED ||
      s === T.RETURN_REQUESTED ||
      s === T.RETURN_IN_TRANSIT ||
      s === T.RETURNED ||
      s === T.EXCHANGE_IN_PROGRESS ||
      s === T.EXCHANGED ||
      s === T.DISPUTED,
  );
  if (delivered.length === live.length) return OrderStatus.DELIVERED;
  if (delivered.length > 0) return OrderStatus.PARTIALLY_DELIVERED;

  const shipped = live.filter((s) => SHIPPED_STATUSES.includes(s));
  if (shipped.length === live.length) return OrderStatus.SHIPPED;
  if (shipped.length > 0) return OrderStatus.PARTIALLY_SHIPPED;

  if (live.length < children.length) return OrderStatus.PARTIALLY_CANCELLED;
  return OrderStatus.CONFIRMED;
}
