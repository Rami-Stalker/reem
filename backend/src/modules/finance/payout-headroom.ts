import { BadRequestException } from '@nestjs/common';
import {
  CommissionStatus,
  Currency,
  LedgerAccountCode,
  PayoutStatus,
  Prisma,
} from '@prisma/client';

import { Money } from '../../common/money';

type Tx = Prisma.TransactionClient;

/** A payout nobody has released yet — still holding its share of payable. */
export const OPEN_PAYOUT_STATUSES: readonly PayoutStatus[] = [
  PayoutStatus.PENDING,
  PayoutStatus.APPROVED,
];

/**
 * Which status a payout may move to from where it is.
 *
 * Nothing guarded this before, and two of the missing edges moved money. A
 * cancelled payout has already let go of its sales, so marking it paid sent
 * its whole net out of platform cash while every sale it had covered stayed
 * claimable — the next payout paid them again. And a paid payout could be
 * "cancelled" after the money had left, which unlinked its sales from the
 * record of having been paid. Paid, failed and cancelled are final; a
 * correction is a new payout or a ledger entry, never a rewrite of this one.
 */
const PAYOUT_TRANSITIONS: Readonly<Record<PayoutStatus, readonly PayoutStatus[]>> =
  Object.freeze({
    [PayoutStatus.PENDING]: [
      PayoutStatus.APPROVED,
      PayoutStatus.PAID,
      PayoutStatus.CANCELLED,
      PayoutStatus.FAILED,
    ],
    [PayoutStatus.APPROVED]: [
      PayoutStatus.PAID,
      PayoutStatus.CANCELLED,
      PayoutStatus.FAILED,
    ],
    [PayoutStatus.PAID]: [],
    [PayoutStatus.FAILED]: [],
    [PayoutStatus.CANCELLED]: [],
  });

export function assertPayoutTransition(
  from: PayoutStatus,
  to: PayoutStatus,
): void {
  if (!PAYOUT_TRANSITIONS[from].includes(to)) {
    throw new BadRequestException({
      code: 'PAYOUT_TRANSITION_REFUSED',
      message: `A ${from.toLowerCase()} payout cannot become ${to.toLowerCase()}`,
    });
  }
}

/**
 * Serialises every payout decision for one seller.
 *
 * Two requests in the same instant — a double tap, or the seller asking while
 * the accountant calculates — each read the same unclaimed sales and each
 * created a payout over them. Nothing in the schema stopped a sale belonging
 * to two payouts, so both could be approved and the sale paid twice. Holding
 * this lock for the length of the transaction makes the second one wait and
 * then find the sales already claimed.
 */
export async function lockSellerPayouts(tx: Tx, sellerId: string): Promise<void> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${`seller-payout:${sellerId}`}))`;
}

/**
 * What the books say the platform owes this seller and nobody has asked for.
 *
 * A payout is assembled from commission rows, and a commission row carries
 * the seller's net *as sold*. What she is actually owed can be less: part of
 * a parcel came back and its share left escrow, a dispute froze or awarded
 * part of it to the customer, she bore a return leg, or a refund after payout
 * left her owing. All of that is on `SELLER_PAYABLE` and none of it is on the
 * commission rows — so a payout of their sum paid her money the ledger had
 * already given to someone else.
 *
 * The payable balance, less what other open payouts have already spoken for,
 * is the most that may leave. [excludePayoutId] leaves one payout out of the
 * open ones, so a payout being released is measured against everything but
 * itself.
 */
export async function payableHeadroom(
  tx: Tx,
  sellerId: string,
  currency: Currency,
  excludePayoutId?: string,
): Promise<Money> {
  const account = await tx.ledgerAccount.findUnique({
    where: {
      code_ownerKey_currency: {
        code: LedgerAccountCode.SELLER_PAYABLE,
        ownerKey: sellerId,
        currency,
      },
    },
    select: { balance: true },
  });
  const open = await tx.sellerPayout.aggregate({
    _sum: { net: true },
    where: {
      sellerId,
      currency,
      status: { in: [...OPEN_PAYOUT_STATUSES] },
      ...(excludePayoutId ? { id: { not: excludePayoutId } } : {}),
    },
  });
  return Money.of(account?.balance ?? 0, currency).minus(
    Money.of(open._sum.net ?? 0, currency),
  );
}

/**
 * The amount a new payout over [ledgerNet] may carry, and the adjustment that
 * records why it is less.
 *
 * The sales are still claimed in full — they are settled either way — but
 * the cash is capped at what is owed, which is how a refund debt is worked
 * off against her next payout.
 */
export function cappedPayout(
  ledgerNet: Money,
  headroom: Money,
): { net: Money; adjustment: Money } {
  const net = ledgerNet.greaterThan(headroom) ? headroom : ledgerNet;
  return { net, adjustment: net.minus(ledgerNet) };
}

/**
 * Guards a hand-made change to a commission row's status.
 *
 * A commission row's status is what decides whether a sale can be paid: only
 * `EARNED` rows are gathered into payouts. Setting a `PAID` row back to
 * `EARNED` made a sale that had already been paid claimable again, and
 * changing a row that an open payout holds left that payout describing sales
 * it no longer matched. Paid and reversed are final, and a row inside an open
 * payout is changed by acting on the payout.
 */
export async function assertCommissionLedgerChange(
  db: Tx,
  ledgerId: string,
  from: CommissionStatus,
  to: CommissionStatus,
): Promise<void> {
  if (from === to) return;
  if (from === CommissionStatus.PAID || from === CommissionStatus.REVERSED) {
    throw new BadRequestException({
      code: 'COMMISSION_STATUS_FINAL',
      message: `A ${from.toLowerCase()} commission entry cannot be changed`,
    });
  }
  const held = await db.sellerPayoutLedger.count({
    where: {
      ledgerId,
      payout: { status: { in: [...OPEN_PAYOUT_STATUSES] } },
    },
  });
  if (held > 0) {
    throw new BadRequestException({
      code: 'COMMISSION_IN_OPEN_PAYOUT',
      message:
        'This commission entry belongs to an open payout — cancel or pay the payout instead',
    });
  }
}
