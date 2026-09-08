import { Injectable } from '@nestjs/common';
import {
  Currency,
  LedgerAccountCode,
  LedgerDirection,
  SellerOrderStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money, REVENUE_STATUSES } from '../../common/money';
import { utcCast, utcParam } from '../../common/sql/utc-timestamp';

/**
 * The figures a marketplace is actually run on.
 *
 * Every one of these was missing. The analytics module reported revenue,
 * orders, conversion and retention — all true, all about *activity* — and
 * nothing about the economics of the marketplace itself: what volume flows
 * across it, what share of that the platform keeps, and whether what it keeps
 * covers what the volume costs to carry. A shop can grow all four of the
 * existing numbers while every order loses money, and nothing here would have
 * said so.
 *
 * **Nothing below is estimated.** Volume comes from the sub-orders, which are
 * the rows that carry the money; revenue and cost come from the journal, which
 * is double-entry and reconciled nightly. There is no cost model, no assumed
 * fee, no ratio carried over from a spreadsheet — if a figure cannot be
 * derived from a posted entry it is not reported. That is the difference
 * between a KPI and a guess with a number on it.
 */

/** Definitions the reader has to be able to check. Reported alongside the figures. */
export const ECONOMICS_BASIS = {
  gmv:
    'Merchandise only, net of discounts, on sub-orders in a revenue-bearing ' +
    'state. Delivery is excluded — it is a service the platform sells, not ' +
    'merchandise the marketplace moved.',
  refunds:
    'Merchandise value on sub-orders that reached REFUNDED. Subtracted from ' +
    'gross GMV to give net GMV.',
  revenue:
    'COMMISSION_REVENUE + SHIPPING_REVENUE + PROMOTION_REVENUE, from the ' +
    'journal, excluding reversed entries. Promotion revenue is reported on ' +
    'its own line too: it is a different business from commission and grows ' +
    'for different reasons.',
  directCosts:
    'SHIPPING_EXPENSE + PLATFORM_PROMOTION_EXPENSE. What carrying this ' +
    'volume cost the platform directly. Excludes staff, servers and anything ' +
    'else the ledger does not book per order.',
  takeRate: 'Platform revenue ÷ net GMV.',
  aov: 'Net GMV ÷ the number of parent orders that contributed to it.',
  contributionMargin:
    'Platform revenue − direct costs. Contribution, not profit: fixed costs ' +
    'are not in the ledger and are not subtracted here.',
} as const;

export interface EconomicsWindow {
  from: Date;
  to: Date;
  currency: Currency;
}

interface AccountMovement {
  code: LedgerAccountCode;
  direction: LedgerDirection;
}

/** Revenue accounts are credit-normal: revenue arrives as a CREDIT. */
const REVENUE_ACCOUNTS: AccountMovement[] = [
  { code: LedgerAccountCode.COMMISSION_REVENUE, direction: LedgerDirection.CREDIT },
  { code: LedgerAccountCode.SHIPPING_REVENUE, direction: LedgerDirection.CREDIT },
  // What boutiques pay to be surfaced. Counted in platform revenue — a take
  // rate that ignored it would understate what the marketplace earns — and
  // reported on its own line too, because it is a different business from
  // commission and grows for different reasons.
  { code: LedgerAccountCode.PROMOTION_REVENUE, direction: LedgerDirection.CREDIT },
];

/** Reported beside the total, so the two businesses stay legible. */
const PROMOTION_ACCOUNTS: AccountMovement[] = [
  { code: LedgerAccountCode.PROMOTION_REVENUE, direction: LedgerDirection.CREDIT },
];

/** Expense accounts are debit-normal: a cost arrives as a DEBIT. */
const COST_ACCOUNTS: AccountMovement[] = [
  { code: LedgerAccountCode.SHIPPING_EXPENSE, direction: LedgerDirection.DEBIT },
  {
    code: LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE,
    direction: LedgerDirection.DEBIT,
  },
];

@Injectable()
export class EconomicsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * The whole marketplace over one window.
   *
   * Take rate divides by *net* GMV rather than gross, because a refunded
   * order's commission is reversed too. Dividing kept revenue by volume that
   * came back would flatter the rate in exactly the months returns were worst.
   */
  async overview(window: EconomicsWindow) {
    const [volume, revenue, costs, promotions] = await Promise.all([
      this.volume(window),
      this.movement(window, REVENUE_ACCOUNTS),
      this.movement(window, COST_ACCOUNTS),
      this.movement(window, PROMOTION_ACCOUNTS),
    ]);

    const contribution = revenue.minus(costs);

    return {
      window: {
        from: window.from.toISOString(),
        to: window.to.toISOString(),
        currency: window.currency,
      },
      volume: {
        gmv_gross: volume.gross.toJSON(),
        refunds: volume.refunded.toJSON(),
        gmv_net: volume.net.toJSON(),
        orders: volume.orders,
        sub_orders: volume.subOrders,
        units: volume.units,
        aov: volume.aov.toJSON(),
        items_per_order: volume.itemsPerOrder,
      },
      platform: {
        revenue: revenue.toJSON(),
        promotion_revenue: promotions.toJSON(),
        direct_costs: costs.toJSON(),
        contribution_margin: contribution.toJSON(),
        take_rate: this.ratio(revenue, volume.net),
        contribution_margin_rate: this.ratio(contribution, volume.net),
        // Contribution per order is the number that says whether growth
        // helps: negative, every new order makes the hole deeper.
        contribution_per_order:
          volume.orders > 0
            ? contribution.dividedBy(volume.orders).toJSON()
            : Money.zero(window.currency).toJSON(),
      },
      basis: ECONOMICS_BASIS,
    };
  }

  /**
   * The same economics, per seller.
   *
   * Commission is read off the sub-order rather than the journal here: the
   * journal knows the platform earned it but not, without a join per entry,
   * whose parcel it came from. `commissionAmount` is written at checkout from
   * the same quote the settlement entry uses, so the two agree — and if they
   * ever stop agreeing that is a settlement bug, which the reconciliation job
   * is the right thing to catch.
   */
  async bySeller(window: EconomicsWindow, limit: number) {
    const rows = await this.prisma.sellerOrder.groupBy({
      by: ['sellerId'],
      where: this.revenueWhere(window),
      _sum: {
        itemsSubtotal: true,
        discountTotal: true,
        commissionAmount: true,
        sellerNet: true,
      },
      _count: { _all: true },
    });

    const sellers = await this.prisma.user.findMany({
      where: { id: { in: rows.map((row) => row.sellerId) } },
      select: { id: true, name: true, username: true },
    });
    const byId = new Map(sellers.map((seller) => [seller.id, seller]));

    return rows
      .map((row) => {
        const gmv = Money.of(row._sum.itemsSubtotal ?? 0, window.currency).minus(
          Money.of(row._sum.discountTotal ?? 0, window.currency),
        );
        const commission = Money.of(
          row._sum.commissionAmount ?? 0,
          window.currency,
        );
        const seller = byId.get(row.sellerId);
        return {
          seller: {
            id: row.sellerId,
            name: seller?.name ?? null,
            username: seller?.username ?? null,
          },
          gmv: gmv.toJSON(),
          commission: commission.toJSON(),
          seller_net: Money.of(row._sum.sellerNet ?? 0, window.currency).toJSON(),
          take_rate: this.ratio(commission, gmv),
          sub_orders: row._count._all,
          gmvSort: Number(gmv.toPrisma()),
        };
      })
      .sort((a, b) => b.gmvSort - a.gmvSort)
      .slice(0, limit)
      .map(({ gmvSort: _gmvSort, ...rest }) => rest);
  }

  /**
   * And per category.
   *
   * A sub-order can span categories, so the split is done on the order *items*
   * — attributing a whole parcel to whichever category happened to be first
   * would put a 200,000 handbag in the accessories column because a scarf was
   * in the same box. Line totals are already net of nothing, so the parcel's
   * discount is apportioned across its lines by value.
   */
  async byCategory(window: EconomicsWindow, limit: number) {
    const rows = await this.prisma.$queryRawUnsafe<
      {
        category_id: string;
        slug: string;
        name_ar: string;
        gmv: string;
        commission: string;
        units: number;
        sub_orders: number;
      }[]
    >(
      `
      WITH parcel AS (
        SELECT so.id,
               so.items_subtotal,
               so.discount_total,
               so.commission_amount
        FROM seller_orders so
        WHERE so.currency = $1::"Currency"
          AND so.status = ANY($2::"SellerOrderStatus"[])
          AND so.created_at >= ${utcCast('$3')} AND so.created_at < ${utcCast('$4')}
      ),
      line AS (
        SELECT oi.seller_order_id,
               p.category_id,
               oi.line_total,
               oi.quantity,
               -- The parcel's share this line represents. Guarded against a
               -- zero subtotal, which a fully discounted parcel can produce.
               CASE WHEN parcel.items_subtotal > 0
                    THEN oi.line_total / parcel.items_subtotal
                    ELSE 0 END AS share
        FROM order_items oi
        JOIN parcel ON parcel.id = oi.seller_order_id
        JOIN products p ON p.id = oi.product_id
      )
      SELECT c.id AS category_id, c.slug, c.name_ar,
             SUM(line.line_total - (parcel.discount_total * line.share))::text AS gmv,
             SUM(parcel.commission_amount * line.share)::text AS commission,
             SUM(line.quantity)::int AS units,
             COUNT(DISTINCT line.seller_order_id)::int AS sub_orders
      FROM line
      JOIN parcel ON parcel.id = line.seller_order_id
      JOIN categories c ON c.id = line.category_id
      GROUP BY c.id, c.slug, c.name_ar
      ORDER BY SUM(line.line_total - (parcel.discount_total * line.share)) DESC
      LIMIT $5
      `,
      window.currency,
      REVENUE_STATUSES as SellerOrderStatus[],
      utcParam(window.from),
      utcParam(window.to),
      limit,
    );

    return rows.map((row) => {
      const gmv = Money.of(row.gmv ?? 0, window.currency);
      const commission = Money.of(row.commission ?? 0, window.currency);
      return {
        category: {
          id: row.category_id,
          slug: row.slug,
          name: row.name_ar,
        },
        gmv: gmv.toJSON(),
        commission: commission.toJSON(),
        take_rate: this.ratio(commission, gmv),
        units: row.units,
        sub_orders: row.sub_orders,
      };
    });
  }

  // ── internals ────────────────────────────────────────────────────────────

  /** Merchandise volume and the order counts behind it. */
  private async volume(window: EconomicsWindow) {
    const [earned, refunded, parents, items] = await Promise.all([
      this.prisma.sellerOrder.aggregate({
        where: this.revenueWhere(window),
        _sum: { itemsSubtotal: true, discountTotal: true },
        _count: { _all: true },
      }),
      this.prisma.sellerOrder.aggregate({
        where: {
          ...this.baseWhere(window),
          status: SellerOrderStatus.REFUNDED,
        },
        _sum: { itemsSubtotal: true, discountTotal: true },
      }),
      // Parent orders, not sub-orders: a basket split across three boutiques
      // is one order to the woman who placed it, and AOV is about her basket.
      this.prisma.sellerOrder.findMany({
        where: this.revenueWhere(window),
        select: { orderId: true },
        distinct: ['orderId'],
      }),
      this.prisma.orderItem.aggregate({
        where: { sellerOrder: this.revenueWhere(window) },
        _sum: { quantity: true },
      }),
    ]);

    const gross = Money.of(
      earned._sum.itemsSubtotal ?? 0,
      window.currency,
    ).minus(Money.of(earned._sum.discountTotal ?? 0, window.currency));

    const refundedValue = Money.of(
      refunded._sum.itemsSubtotal ?? 0,
      window.currency,
    ).minus(Money.of(refunded._sum.discountTotal ?? 0, window.currency));

    const net = gross.minus(refundedValue);
    const orders = parents.length;
    const units = items._sum.quantity ?? 0;

    return {
      gross,
      refunded: refundedValue,
      net,
      orders,
      subOrders: earned._count._all,
      units,
      aov: orders > 0 ? net.dividedBy(orders) : Money.zero(window.currency),
      itemsPerOrder: orders > 0 ? Number((units / orders).toFixed(2)) : 0,
    };
  }

  /**
   * What moved through a set of accounts in the window, in their normal
   * direction, net of the opposite one.
   *
   * Both directions are read because a reversal that has not been paired off
   * as a `reversesId` mirror — a partial refund's commission credit, say —
   * still has to reduce the figure. Reading only credits on a revenue account
   * would report commission the platform gave back as commission it kept.
   */
  private async movement(
    window: EconomicsWindow,
    accounts: AccountMovement[],
  ): Promise<Money> {
    let total = Money.zero(window.currency);

    for (const account of accounts) {
      const sums = await this.prisma.journalLine.groupBy({
        by: ['direction'],
        where: {
          currency: window.currency,
          account: { code: account.code, currency: window.currency },
          entry: {
            occurredAt: { gte: window.from, lt: window.to },
            // A reversed entry and the mirror that cancels it net to nothing;
            // counting either alone would report movement that no longer
            // stands. Same rule `movementFor` applies.
            reversedBy: null,
            reversesId: null,
          },
        },
        _sum: { amount: true },
      });

      const normal = Money.of(
        sums.find((s) => s.direction === account.direction)?._sum.amount ?? 0,
        window.currency,
      );
      const opposite = Money.of(
        sums.find((s) => s.direction !== account.direction)?._sum.amount ?? 0,
        window.currency,
      );
      total = total.plus(normal).minus(opposite);
    }

    return total;
  }

  private baseWhere(window: EconomicsWindow) {
    return {
      currency: window.currency,
      createdAt: { gte: window.from, lt: window.to },
    };
  }

  private revenueWhere(window: EconomicsWindow) {
    return {
      ...this.baseWhere(window),
      status: { in: [...REVENUE_STATUSES] },
    };
  }

  /**
   * A rate, or null when the denominator is zero.
   *
   * Null rather than 0: a month with no sales has no take rate, and printing
   * 0% next to it says the platform kept nothing of something, which is a
   * different and untrue statement.
   */
  private ratio(numerator: Money, denominator: Money): number | null {
    const bottom = Number(denominator.toPrisma());
    if (!bottom) return null;
    return Number((Number(numerator.toPrisma()) / bottom).toFixed(4));
  }
}
