import { Injectable } from '@nestjs/common';
import {
  DeliveryFailureReason,
  DisputeStatus,
  Prisma,
  ShipmentStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { HISTORY_WINDOW_DAYS } from './cod-trust.constants';
import {
  BasketFacts,
  CodFacts,
  CustomerFacts,
  DestinationFacts,
} from './kernel/cod-facts';

/**
 * The destination as checkout knows it, before an order row exists.
 *
 * Deliberately not the `Order` — the assessment has to happen while the
 * decision can still change what the order becomes.
 */
export interface DestinationInput {
  governorate: string;
  addressLine: string;
  landmark: string | null;
  isRural: boolean;
  recipientPhone: string;
  /** Chosen from her saved addresses rather than typed at checkout. */
  fromAddressBook: boolean;
}

export interface BasketInput {
  /** USD, at the rate this order froze. */
  orderValueUsd: number;
  sellerCount: number;
  itemCount: number;
  maxUnitsOnOneLine: number;
}

/**
 * A refusal is a parcel the customer met and sent back. A failure is one she
 * never met. Keeping the sets disjoint is what lets the kernel treat
 * `delivered + refused + failed` as the number of doors a courier stood at.
 */
const NON_REFUSAL_FAILURES: DeliveryFailureReason[] = [
  DeliveryFailureReason.NO_ANSWER,
  DeliveryFailureReason.WRONG_ADDRESS,
  DeliveryFailureReason.UNREACHABLE_AREA,
];

const OPEN_DISPUTES: DisputeStatus[] = [
  DisputeStatus.OPEN,
  DisputeStatus.UNDER_REVIEW,
  DisputeStatus.ESCALATED,
  DisputeStatus.APPEALED,
];

/**
 * Everything the scorer needs, read from rows that already exist.
 *
 * No table was added to feed this. Refusals live on shipments because a
 * courier recorded one; order values live on orders because somebody paid
 * them. A separate "risk profile" table kept in sync by a job would have been
 * a second copy of facts the platform already holds, and the two would have
 * disagreed within a month.
 */
@Injectable()
export class CodFactsService {
  constructor(private readonly prisma: PrismaService) {}

  async gather(input: {
    userId: string | null;
    destination: DestinationInput;
    basket: BasketInput;
  }): Promise<CodFacts> {
    const since = new Date(
      Date.now() - HISTORY_WINDOW_DAYS * 24 * 60 * 60 * 1000,
    );

    const [customer, destination] = await Promise.all([
      this.customerFacts(input.userId, since),
      this.destinationFacts(input.userId, input.destination, since),
    ]);

    const basket: BasketFacts = {
      orderValue: input.basket.orderValueUsd,
      sellerCount: input.basket.sellerCount,
      itemCount: input.basket.itemCount,
      maxUnitsOnOneLine: input.basket.maxUnitsOnOneLine,
    };

    return { customer, destination, basket };
  }

  private async customerFacts(
    userId: string | null,
    since: Date,
  ): Promise<CustomerFacts> {
    if (!userId) {
      // A guest has no history to read, and saying so plainly is better than
      // running six queries that can only return zero.
      return {
        isGuest: true,
        accountAgeDays: null,
        phoneVerified: false,
        deviceEnrolled: false,
        deliveredParcels: 0,
        refusedParcels: 0,
        failedParcels: 0,
        cancelledAfterConfirmation: 0,
        totalOrders: 0,
        medianOrderValue: null,
        openDisputes: 0,
      };
    }

    const parcelsOf = (where: Prisma.ShipmentWhereInput) =>
      this.prisma.shipment.count({
        where: {
          ...where,
          createdAt: { gte: since },
          sellerOrder: { order: { userId } },
        },
      });

    const [
      user,
      deviceKeys,
      delivered,
      refused,
      failed,
      totalOrders,
      cancelledAfterConfirmation,
      openDisputes,
      recentOrders,
    ] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: userId },
        select: { createdAt: true, phoneVerifiedAt: true },
      }),
      this.prisma.deviceKey.count({ where: { userId } }),
      parcelsOf({ status: ShipmentStatus.DELIVERED, failureReason: null }),
      parcelsOf({ failureReason: DeliveryFailureReason.CUSTOMER_REFUSED }),
      parcelsOf({ failureReason: { in: NON_REFUSAL_FAILURES } }),
      this.prisma.order.count({
        where: { userId, placedAt: { not: null, gte: since } },
      }),
      // Cancelled *after* a seller was told to prepare it — `confirmedAt` is
      // the moment that instruction went out. A basket abandoned before that
      // costs nobody anything and must not count against her.
      this.prisma.sellerOrder.count({
        where: {
          order: { userId },
          createdAt: { gte: since },
          confirmedAt: { not: null },
          status: 'CANCELLED_BY_CUSTOMER',
        },
      }),
      this.prisma.dispute.count({
        where: {
          sellerOrder: { order: { userId } },
          status: { in: OPEN_DISPUTES },
        },
      }),
      this.prisma.order.findMany({
        where: { userId, placedAt: { not: null } },
        orderBy: { placedAt: 'desc' },
        take: 20,
        select: { grandTotal: true, fxRate: true },
      }),
    ]);

    return {
      isGuest: false,
      accountAgeDays: user
        ? Math.floor((Date.now() - user.createdAt.getTime()) / 86_400_000)
        : null,
      // `phoneVerifiedAt`, not the badge. This read `isVerified` back when
      // the OTP exchange wrote both, so a refusal-risk assessment that means
      // to ask "has she proved this number" was in fact asking "does she wear
      // a badge" — which after this change would have been false for almost
      // everybody and quietly hardened checkout for the whole market.
      phoneVerified: user?.phoneVerifiedAt != null,
      deviceEnrolled: deviceKeys > 0,
      deliveredParcels: delivered,
      refusedParcels: refused,
      failedParcels: failed,
      cancelledAfterConfirmation,
      totalOrders,
      medianOrderValue: median(
        recentOrders.map((order) => toUsd(order.grandTotal, order.fxRate)),
      ),
      openDisputes,
    };
  }

  private async destinationFacts(
    userId: string | null,
    destination: DestinationInput,
    since: Date,
  ): Promise<DestinationFacts> {
    const inGovernorate = (where: Prisma.ShipmentWhereInput) =>
      this.prisma.shipment.count({
        where: {
          ...where,
          createdAt: { gte: since },
          sellerOrder: { order: { governorate: destination.governorate } },
        },
      });

    const [attempts, refusals, phoneOwners] = await Promise.all([
      inGovernorate({
        OR: [
          { status: ShipmentStatus.DELIVERED, failureReason: null },
          { failureReason: { not: null } },
        ],
      }),
      inGovernorate({ failureReason: DeliveryFailureReason.CUSTOMER_REFUSED }),
      // Distinct accounts that have shipped to this number. The customer's own
      // account is excluded below rather than in the query, because a guest
      // order has no account to exclude.
      this.prisma.order.findMany({
        where: {
          recipientPhone: destination.recipientPhone,
          userId: { not: null },
          placedAt: { not: null, gte: since },
        },
        distinct: ['userId'],
        select: { userId: true },
        take: 20,
      }),
    ]);

    return {
      fromAddressBook: destination.fromAddressBook,
      addressLineLength: destination.addressLine.trim().length,
      hasLandmark: Boolean(destination.landmark?.trim()),
      isRural: destination.isRural,
      governorateAttempts: attempts,
      governorateRefusals: refusals,
      otherAccountsOnPhone: phoneOwners.filter(
        (order) => order.userId !== userId,
      ).length,
    };
  }
}

/**
 * An order's value in USD, through the rate that order itself froze.
 *
 * `orders.fx_rate` is USD → the order's currency, so dividing recovers the
 * dollar figure as it stood on the day — which is the only way a basket from
 * March and a basket from September can be compared at all in a currency that
 * moves the way this one does.
 */
function toUsd(grandTotal: Prisma.Decimal, fxRate: Prisma.Decimal): number {
  if (fxRate.isZero()) return 0;
  return grandTotal.dividedBy(fxRate).toNumber();
}

function median(values: number[]): number | null {
  const sorted = values.filter((v) => v > 0).sort((a, b) => a - b);
  if (sorted.length === 0) return null;
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[middle - 1] + sorted[middle]) / 2
    : sorted[middle];
}

export { toUsd };
