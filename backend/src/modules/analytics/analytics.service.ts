import { BadRequestException, Injectable } from '@nestjs/common';
import {
  AnalyticsEventType,
  AnalyticsExportFormat,
  Currency,
  OrderStatus,
  Prisma,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CANCELLED_STATUSES,
  Money,
  REVENUE_STATUSES,
} from '../../common/money';
import { dayLabel, daysIn, startOfPlatformDay } from './platform-day';
import {
  AnalyticsExportQueryDto,
  AnalyticsQueryDto,
  TrackAnalyticsEventDto,
} from './dto/analytics.dto';

interface AnalyticsUser {
  id: string;
  role: UserRole;
}

interface DateRange {
  start: Date;
  end: Date;
}

/**
 * Revenue is a property of a SUB-ORDER: one seller can have delivered while
 * another is still preparing, so "was this order revenue?" is not a question
 * the parent row can answer.
 */
const revenueStatuses = [...REVENUE_STATUSES];

/**
 * Sub-orders whose goods came back, or whose money is going back.
 *
 * Booked as sales when they were made and subtracted as refunds now, so gross
 * stays a record of what was sold and net says what was kept.
 */
const refundStatuses: SellerOrderStatus[] = [
  SellerOrderStatus.RETURNED,
  SellerOrderStatus.REFUND_PENDING,
  SellerOrderStatus.REFUNDED,
];

/**
 * Everything that was a real sale at some point: realised, or realised and
 * then disputed or sent back. Excludes what never got past the seller
 * (new, awaiting confirmation), failed at the door, or was cancelled.
 */
const bookedStatuses: SellerOrderStatus[] = [
  ...REVENUE_STATUSES,
  SellerOrderStatus.RETURN_REQUESTED,
  SellerOrderStatus.RETURN_IN_TRANSIT,
  SellerOrderStatus.DISPUTED,
  ...refundStatuses,
];

/**
 * The events a phone may report about itself.
 *
 * Everything else is written by the server at the moment it happens — a
 * product page opening, a cart line, a search, an order. Accepting those from
 * a client too would count them twice, and accepting `ORDER_PLACED` would let
 * anyone with an account write a competitor's conversion rate.
 */
export const CLIENT_TRACKABLE_EVENTS: ReadonlySet<AnalyticsEventType> = new Set([
  AnalyticsEventType.APP_OPEN,
  AnalyticsEventType.CHECKOUT_START,
  AnalyticsEventType.SELLER_VIEW,
  AnalyticsEventType.CAMPAIGN_OPEN,
  AnalyticsEventType.CAMPAIGN_CLICK,
  AnalyticsEventType.PRODUCT_IMPRESSION,
  AnalyticsEventType.PRODUCT_SHARE,
  AnalyticsEventType.CUSTOM,
]);

/** The widest window one report may span. A year of rows is read in memory. */
const MAX_RANGE_DAYS = 366;

/** The most JSON a client event may carry. */
const MAX_METADATA_BYTES = 2_048;

/** Money is aggregated within a currency, never across. */
type CurrencyTotals = Map<Currency, Money>;

function addTo(totals: CurrencyTotals, amount: Money): void {
  const running = totals.get(amount.currency);
  totals.set(amount.currency, running ? running.plus(amount) : amount);
}

function serializeTotals(totals: CurrencyTotals) {
  return [...totals.values()].map((total) => total.toJSON());
}

/** `588,860 SYP + 120 USD` — a money list as a person reads it. */
function formatTotals(totals: { amount: string; currency: Currency }[]): string {
  if (totals.length === 0) return '0';
  return totals
    .map(
      (total) =>
        `${Number(total.amount).toLocaleString('en-US', {
          maximumFractionDigits: 2,
        })} ${total.currency}`,
    )
    .join(' + ');
}

/**
 * A spreadsheet cell. A cell that opens with `=`, `+`, `-` or `@` is a formula
 * to Excel, and product titles are typed by sellers — so those are prefixed
 * with an apostrophe rather than executed on an operator's machine.
 */
function safeCell(value: string): string {
  return /^[=+\-@\t\r]/.test(value) ? `'${value}` : value;
}

function csvCell(value: string): string {
  const safe = safeCell(value);
  return /[",\r\n]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe;
}

function tsvCell(value: string): string {
  return safeCell(value).replace(/[\t\r\n]+/g, ' ');
}

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async track(userId: string, dto: TrackAnalyticsEventDto) {
    if (!CLIENT_TRACKABLE_EVENTS.has(dto.type)) {
      throw new BadRequestException(
        `${dto.type} is recorded by the server and cannot be reported`,
      );
    }
    let metadata: Prisma.InputJsonValue | undefined;
    if (dto.metadata !== undefined && dto.metadata !== null) {
      const json = JSON.stringify(dto.metadata) ?? '';
      if (Buffer.byteLength(json) > MAX_METADATA_BYTES) {
        throw new BadRequestException('Event metadata is too large');
      }
      metadata = dto.metadata as Prisma.InputJsonValue;
    }
    const event = await this.prisma.analyticsEvent.create({
      data: {
        type: dto.type,
        userId,
        sessionId: dto.session_id,
        productId: dto.product_id,
        sellerId: dto.seller_id,
        orderId: dto.order_id,
        source: dto.source,
        metadata,
      },
    });
    return { id: event.id, tracked_at: event.createdAt.toISOString() };
  }

  /**
   * One `ORDER_PLACED` per seller in the order — the funnel is counted in
   * seller checkouts, the same unit the client reports `CHECKOUT_START` in,
   * so a seller's own funnel and the platform's add up.
   */
  async recordOrderPlaced(orderId: string, userId: string | null) {
    const subOrders = await this.prisma.sellerOrder.findMany({
      where: { orderId },
      select: { sellerId: true },
    });
    if (subOrders.length === 0) return;
    await this.prisma.analyticsEvent.createMany({
      data: subOrders.map((sub) => ({
        type: AnalyticsEventType.ORDER_PLACED,
        userId,
        sellerId: sub.sellerId,
        orderId,
        source: 'checkout',
      })),
    });
  }

  async dashboard(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const sellerId = this.sellerScope(query, user);
    const [
      sales,
      revenue,
      productPerformance,
      sellerPerformance,
      customers,
      conversion,
      funnel,
      retention,
      cohorts,
      realtime,
    ] = await Promise.all([
      this.sales(query, user),
      this.revenue(query, user),
      this.productPerformance(query, user),
      this.sellerPerformance(query, user),
      this.customerAnalytics(query, user),
      this.conversion(query, user),
      this.funnel(query, user),
      this.retention(query, user),
      this.cohorts(query, user),
      this.realtime(user),
    ]);

    return {
      range: {
        start: range.start.toISOString(),
        end: range.end.toISOString(),
      },
      seller_id: sellerId,
      sales,
      revenue,
      product_performance: productPerformance,
      seller_performance: sellerPerformance,
      customers,
      conversion,
      funnel,
      retention,
      cohorts,
      realtime,
    };
  }

  /**
   * Orders and revenue over the window.
   *
   * Read from sub-orders, never from the parent order: an order holds several
   * sellers' parcels, and summing `order.grand_total` handed a seller every
   * other boutique's sales and the shipping on top. Revenue is item value on
   * realised sub-orders; an order counts once however many parcels it has.
   */
  async sales(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const subOrders = await this.prisma.sellerOrder.findMany({
      where: this.subOrderWhere(query, user, range),
      select: {
        orderId: true,
        status: true,
        currency: true,
        itemsSubtotal: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'asc' },
    });

    const byDay = new Map<string, { orders: Set<string>; revenue: CurrencyTotals }>(
      daysIn(range).map((day) => [day, { orders: new Set(), revenue: new Map() }]),
    );
    const byStatus = new Map<string, number>();
    const orders = new Set<string>();
    const paidOrders = new Map<Currency, Set<string>>();
    const revenue: CurrencyTotals = new Map();

    for (const sub of subOrders) {
      orders.add(sub.orderId);
      byStatus.set(sub.status, (byStatus.get(sub.status) ?? 0) + 1);
      const label = dayLabel(sub.createdAt);
      const day = byDay.get(label) ?? {
        orders: new Set<string>(),
        revenue: new Map<Currency, Money>(),
      };
      day.orders.add(sub.orderId);
      if (revenueStatuses.includes(sub.status)) {
        const amount = Money.of(sub.itemsSubtotal, sub.currency);
        addTo(day.revenue, amount);
        addTo(revenue, amount);
        const set = paidOrders.get(sub.currency) ?? new Set<string>();
        set.add(sub.orderId);
        paidOrders.set(sub.currency, set);
      }
      byDay.set(label, day);
    }

    const paid = new Set<string>();
    for (const set of paidOrders.values()) set.forEach((id) => paid.add(id));

    return {
      total_orders: orders.size,
      paid_orders: paid.size,
      // Per currency, over the orders that actually earned in it.
      average_order_value: [...revenue.entries()].map(([currency, total]) =>
        total
          .dividedBy(Math.max(paidOrders.get(currency)?.size ?? 0, 1))
          .roundForCurrency()
          .toJSON(),
      ),
      by_status: [...byStatus.entries()].map(([status, count]) => ({
        status: status.toLowerCase(),
        count,
      })),
      series: [...byDay.entries()]
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([date, value]) => ({
          date,
          orders: value.orders.size,
          revenue: serializeTotals(value.revenue),
        })),
    };
  }

  /**
   * Gross is everything sold — realised, or realised and since sent back.
   * Refunds are the part that came back. Net is what was kept. Cancelled is
   * reported beside them, because a rising cancellation line is a finding in
   * itself, and "refunds" used to mean the value of cancelled orders.
   */
  async revenue(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const where = this.subOrderWhere(query, user, range);

    const [booked, refunded, cancelled, paid] = await Promise.all([
      this.prisma.sellerOrder.groupBy({
        by: ['currency'],
        where: { ...where, status: { in: bookedStatuses } },
        _sum: { itemsSubtotal: true },
      }),
      this.prisma.sellerOrder.groupBy({
        by: ['currency'],
        where: { ...where, status: { in: refundStatuses } },
        _sum: { itemsSubtotal: true },
      }),
      this.prisma.sellerOrder.groupBy({
        by: ['currency'],
        where: { ...where, status: { in: [...CANCELLED_STATUSES] } },
        _sum: { itemsSubtotal: true },
      }),
      // Paid = booked sales on orders whose payment has been captured. A
      // payment belongs to the whole order, so it is attributed through the
      // sub-order rather than summed off the payment row.
      this.prisma.sellerOrder.groupBy({
        by: ['currency'],
        where: {
          ...where,
          status: { in: bookedStatuses },
          order: { payment: { is: { status: 'PAID' } } },
        },
        _sum: { itemsSubtotal: true },
      }),
    ]);

    const totals = (
      rows: { currency: Currency; _sum: { itemsSubtotal: Prisma.Decimal | null } }[],
    ) => {
      const map: CurrencyTotals = new Map();
      for (const row of rows) {
        addTo(map, Money.of(row._sum.itemsSubtotal ?? 0, row.currency));
      }
      return map;
    };
    const grossTotals = totals(booked);
    const refundTotals = totals(refunded);

    const net: CurrencyTotals = new Map();
    for (const [currency, amount] of grossTotals) {
      net.set(
        currency,
        amount.minus(refundTotals.get(currency) ?? Money.zero(currency)),
      );
    }

    return {
      gross_revenue: serializeTotals(grossTotals),
      paid_revenue: serializeTotals(totals(paid)),
      refunds: serializeTotals(refundTotals),
      cancelled: serializeTotals(totals(cancelled)),
      net_revenue: serializeTotals(net),
    };
  }

  async productPerformance(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const sellerId = this.sellerScope(query, user);
    const items = await this.prisma.orderItem.findMany({
      where: {
        ...(query.product_id ? { productId: query.product_id } : {}),
        // Realised sales only. A cancelled basket is not a best seller.
        sellerOrder: {
          createdAt: { gte: range.start, lte: range.end },
          status: { in: revenueStatuses },
          ...(sellerId ? { sellerId } : {}),
        },
      },
      select: {
        productId: true,
        titleSnapshot: true,
        quantity: true,
        lineTotal: true,
        currency: true,
      },
    });

    const rows = new Map<
      string,
      { product_id: string; title: string; units: number; revenue: CurrencyTotals }
    >();
    for (const item of items) {
      // Deleted catalog entries still have their snapshot, so the line is
      // still reportable — it just groups under its own id.
      const key = item.productId ?? `snapshot:${item.titleSnapshot}`;
      const row =
        rows.get(key) ??
        {
          product_id: item.productId ?? '',
          title: item.titleSnapshot,
          units: 0,
          revenue: new Map(),
        };
      row.units += item.quantity;
      addTo(row.revenue, Money.of(item.lineTotal, item.currency));
      rows.set(key, row);
    }

    return [...rows.values()]
      .sort((a, b) => b.units - a.units)
      .slice(0, 20)
      .map((row) => ({ ...row, revenue: serializeTotals(row.revenue) }));
  }

  async sellerPerformance(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const sellerId = this.sellerScope(query, user);

    // Seller attribution is a column on the sub-order now — no join through
    // the catalog, which is what made this wrong once products became shared.
    const subOrders = await this.prisma.sellerOrder.findMany({
      where: {
        createdAt: { gte: range.start, lte: range.end },
        status: { in: revenueStatuses },
        ...(sellerId ? { sellerId } : {}),
      },
      select: {
        sellerId: true,
        currency: true,
        itemsSubtotal: true,
        seller: { select: { name: true } },
        items: { select: { quantity: true } },
      },
    });

    const rows = new Map<
      string,
      { seller_id: string; seller: string; units: number; revenue: CurrencyTotals }
    >();
    for (const sub of subOrders) {
      const row =
        rows.get(sub.sellerId) ??
        {
          seller_id: sub.sellerId,
          seller: sub.seller.name,
          units: 0,
          revenue: new Map(),
        };
      row.units += sub.items.reduce((total, item) => total + item.quantity, 0);
      addTo(row.revenue, Money.of(sub.itemsSubtotal, sub.currency));
      rows.set(sub.sellerId, row);
    }

    return [...rows.values()]
      .sort((a, b) => b.units - a.units)
      .slice(0, 20)
      .map((row) => ({ ...row, revenue: serializeTotals(row.revenue) }));
  }

  async customerAnalytics(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const sellerId = this.sellerScope(query, user);
    const [newCustomers, subOrders] = await Promise.all([
      // For a seller, "new" means new to *her*: a first order from her inside
      // the window. The platform's sign-up count was a number about every
      // other boutique's marketing.
      sellerId
        ? this.prisma.user.count({
            where: {
              orders: {
                some: {
                  createdAt: { gte: range.start, lte: range.end },
                  sellerOrders: { some: { sellerId } },
                },
                none: {
                  createdAt: { lt: range.start },
                  sellerOrders: { some: { sellerId } },
                },
              },
            },
          })
        : this.prisma.user.count({
            where: {
              role: UserRole.CUSTOMER,
              createdAt: { gte: range.start, lte: range.end },
            },
          }),
      this.prisma.sellerOrder.findMany({
        where: this.subOrderWhere(query, user, range),
        select: {
          orderId: true,
          status: true,
          itemsSubtotal: true,
          currency: true,
          order: { select: { userId: true } },
        },
      }),
    ]);
    const byCustomer = new Map<string, { orders: Set<string>; spend: CurrencyTotals }>();
    for (const sub of subOrders) {
      // Guest checkouts have no user id and are excluded from per-customer
      // metrics rather than being bucketed under a fake key.
      const userId = sub.order.userId;
      if (!userId) continue;
      const row = byCustomer.get(userId) ?? {
        orders: new Set<string>(),
        spend: new Map<Currency, Money>(),
      };
      row.orders.add(sub.orderId);
      if (revenueStatuses.includes(sub.status)) {
        addTo(row.spend, Money.of(sub.itemsSubtotal, sub.currency));
      }
      byCustomer.set(userId, row);
    }
    const repeat = [...byCustomer.values()].filter((row) => row.orders.size > 1);
    const totals: CurrencyTotals = new Map();
    for (const row of byCustomer.values()) {
      for (const amount of row.spend.values()) addTo(totals, amount);
    }
    return {
      active_customers: byCustomer.size,
      new_customers: newCustomers,
      repeat_customers: repeat.length,
      repeat_rate:
        byCustomer.size === 0
          ? 0
          : this.round((repeat.length / byCustomer.size) * 100),
      average_customer_value: [...totals.values()].map((total) =>
        total.dividedBy(Math.max(byCustomer.size, 1)).roundForCurrency().toJSON(),
      ),
    };
  }

  async conversion(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const sellerId = this.sellerScope(query, user);
    const events = await this.eventCounts(range, sellerId, query.product_id);
    const productViews = events.get(AnalyticsEventType.PRODUCT_VIEW) ?? 0;
    const carts = events.get(AnalyticsEventType.CART_ADD) ?? 0;
    const checkouts = events.get(AnalyticsEventType.CHECKOUT_START) ?? 0;
    const orders = events.get(AnalyticsEventType.ORDER_PLACED) ?? 0;
    return {
      product_views: productViews,
      cart_adds: carts,
      checkout_starts: checkouts,
      orders,
      view_to_cart_rate: this.rate(carts, productViews),
      cart_to_checkout_rate: this.rate(checkouts, carts),
      checkout_to_order_rate: this.rate(orders, checkouts),
      overall_conversion_rate: this.rate(orders, productViews),
    };
  }

  async funnel(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const conversion = await this.conversion(query, user);
    return [
      { step: 'Product view', count: conversion.product_views },
      { step: 'Add to cart', count: conversion.cart_adds },
      { step: 'Checkout start', count: conversion.checkout_starts },
      { step: 'Order placed', count: conversion.orders },
    ];
  }

  async retention(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const where = this.orderWhere(query, user, range);
    const orders = await this.prisma.order.findMany({
      where,
      select: { userId: true, createdAt: true },
      orderBy: { createdAt: 'asc' },
    });
    const byUser = new Map<string, Date[]>();
    for (const order of orders) {
      if (!order.userId) continue;
      const dates = byUser.get(order.userId) ?? [];
      dates.push(order.createdAt);
      byUser.set(order.userId, dates);
    }
    const retained7 = [...byUser.values()].filter((dates) =>
      dates.some((date) => date.getTime() - dates[0].getTime() >= 7 * 86400_000),
    ).length;
    const retained30 = [...byUser.values()].filter((dates) =>
      dates.some((date) => date.getTime() - dates[0].getTime() >= 30 * 86400_000),
    ).length;
    return {
      customers: byUser.size,
      retained_7d: retained7,
      retained_30d: retained30,
      retention_7d_rate: this.rate(retained7, byUser.size),
      retention_30d_rate: this.rate(retained30, byUser.size),
    };
  }

  async cohorts(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const where = this.orderWhere(query, user, range);
    const sellerId = this.sellerScope(query, user);
    const [users, orders] = await Promise.all([
      this.prisma.user.findMany({
        where: {
          role: UserRole.CUSTOMER,
          createdAt: { gte: range.start, lte: range.end },
          // A seller's cohorts are her own customers, not every sign-up.
          ...(sellerId
            ? { orders: { some: { sellerOrders: { some: { sellerId } } } } }
            : {}),
        },
        select: { id: true, createdAt: true },
      }),
      this.prisma.order.findMany({
        where,
        select: { userId: true, createdAt: true },
      }),
    ]);
    const userCohort = new Map(
      users.map((user) => [user.id, dayLabel(user.createdAt).slice(0, 7)]),
    );
    const cohorts = new Map<string, { users: number; orders: number }>();
    for (const cohort of userCohort.values()) {
      const row = cohorts.get(cohort) ?? { users: 0, orders: 0 };
      row.users += 1;
      cohorts.set(cohort, row);
    }
    for (const order of orders) {
      const cohort = order.userId ? userCohort.get(order.userId) : undefined;
      if (!cohort) continue;
      const row = cohorts.get(cohort) ?? { users: 0, orders: 0 };
      row.orders += 1;
      cohorts.set(cohort, row);
    }
    return [...cohorts.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([cohort, value]) => ({
      cohort,
      customers: value.users,
      orders: value.orders,
      orders_per_customer: this.round(value.orders / Math.max(value.users, 1)),
    }));
  }

  async realtime(user: AnalyticsUser) {
    // "Today" is the day a woman in Damascus is living, not the server's.
    const today = startOfPlatformDay();
    const isSeller = user.role === UserRole.SELLER;
    const [orders, revenue, onlineUsers, activeCarts] = await Promise.all([
      this.prisma.order.count({
        where: {
          createdAt: { gte: today },
          ...(isSeller ? { sellerOrders: { some: { sellerId: user.id } } } : {}),
        },
      }),
      this.prisma.sellerOrder.groupBy({
        by: ['currency'],
        where: {
          createdAt: { gte: today },
          status: { in: revenueStatuses },
          ...(isSeller ? { sellerId: user.id } : {}),
        },
        _sum: { itemsSubtotal: true },
      }),
      this.prisma.userPresence.count({ where: { status: 'ONLINE' } }),
      // Baskets holding *her* listings, for a seller — the platform's total
      // was every boutique's demand reported as hers.
      this.prisma.cartItem.count({
        where: {
          updatedAt: { gte: today },
          ...(isSeller ? { offer: { sellerId: user.id } } : {}),
        },
      }),
    ]);
    return {
      today_orders: orders,
      today_revenue: revenue.map((row) =>
        Money.of(row._sum.itemsSubtotal ?? 0, row.currency).toJSON(),
      ),
      online_users: onlineUsers,
      active_carts: activeCarts,
      refreshed_at: new Date().toISOString(),
    };
  }

  async export(query: AnalyticsExportQueryDto, user: AnalyticsUser) {
    const dashboard = await this.dashboard(query, user);
    await this.prisma.analyticsExport.create({
      data: {
        requestedBy: user.id,
        format: query.format,
        reportType: query.report_type,
        filters: query as unknown as Prisma.InputJsonValue,
      },
    });

    if (query.format === AnalyticsExportFormat.JSON) {
      return {
        filename: 'reem-analytics.json',
        contentType: 'application/json',
        buffer: Buffer.from(JSON.stringify(dashboard, null, 2)),
      };
    }
    if (
      query.format === AnalyticsExportFormat.EXCEL ||
      query.format === AnalyticsExportFormat.CSV
    ) {
      const csv = query.format === AnalyticsExportFormat.CSV;
      const rows = this.dashboardRows(dashboard);
      const text = rows
        .map((row) =>
          row.map((cell) => (csv ? csvCell(cell) : tsvCell(cell))).join(csv ? ',' : '\t'),
        )
        .join('\r\n');
      return {
        filename: csv ? 'reem-analytics.csv' : 'reem-analytics.xls',
        contentType: csv
          ? 'text/csv; charset=utf-8'
          : 'application/vnd.ms-excel; charset=utf-8',
        // The byte-order mark is what makes Excel read the file as UTF-8.
        // Without it every Arabic product title opened as mojibake.
        buffer: Buffer.concat([
          Buffer.from([0xef, 0xbb, 0xbf]),
          Buffer.from(text, 'utf8'),
        ]),
      };
    }
    return {
      filename: 'reem-analytics.pdf',
      contentType: 'application/pdf',
      buffer: this.simplePdf(this.dashboardLines(dashboard)),
    };
  }

  private orderWhere(
    query: AnalyticsQueryDto,
    user: AnalyticsUser,
    range: DateRange,
  ): Prisma.OrderWhereInput {
    const sellerId = this.sellerScope(query, user);
    const subOrderFilter: Prisma.SellerOrderWhereInput = {
      ...(sellerId ? { sellerId } : {}),
      ...(query.product_id
        ? { items: { some: { productId: query.product_id } } }
        : {}),
    };
    return {
      createdAt: { gte: range.start, lte: range.end },
      ...(Object.keys(subOrderFilter).length > 0
        ? { sellerOrders: { some: subOrderFilter } }
        : {}),
    };
  }

  /** The sub-orders a report reads: the window, her parcels, the product. */
  private subOrderWhere(
    query: AnalyticsQueryDto,
    user: AnalyticsUser,
    range: DateRange,
  ): Prisma.SellerOrderWhereInput {
    const sellerId = this.sellerScope(query, user);
    return {
      createdAt: { gte: range.start, lte: range.end },
      ...(sellerId ? { sellerId } : {}),
      ...(query.product_id
        ? { items: { some: { productId: query.product_id } } }
        : {}),
    };
  }

  private sellerScope(query: AnalyticsQueryDto, user: AnalyticsUser) {
    if (user.role === UserRole.SELLER) return user.id;
    return query.seller_id;
  }

  private range(query: AnalyticsQueryDto): DateRange {
    const end = query.end_date ? new Date(query.end_date) : new Date();
    const start = query.start_date
      ? new Date(query.start_date)
      : new Date(end.getTime() - 30 * 86400_000);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      throw new BadRequestException('Invalid analytics date range');
    }
    if (start > end) {
      throw new BadRequestException('start_date must be before end_date');
    }
    if (end.getTime() - start.getTime() > MAX_RANGE_DAYS * 86400_000) {
      throw new BadRequestException(
        `A report covers at most ${MAX_RANGE_DAYS} days`,
      );
    }
    return { start, end };
  }

  private async eventCounts(
    range: DateRange,
    sellerId?: string,
    productId?: string,
  ) {
    const rows = await this.prisma.analyticsEvent.groupBy({
      by: ['type'],
      where: {
        occurredAt: { gte: range.start, lte: range.end },
        ...(productId ? { productId } : {}),
        // A product view is a fact about a product, not about one seller —
        // several boutiques can list the same dress — so it is written with
        // no seller and attributed here, to every seller with an offer on it.
        // Filtering on `seller_id` alone showed every seller zero views.
        ...(sellerId
          ? {
              OR: [
                { sellerId },
                { sellerId: null, product: { offers: { some: { sellerId } } } },
              ],
            }
          : {}),
      },
      _count: { _all: true },
    });
    return new Map(rows.map((row) => [row.type, row._count._all]));
  }

  private rate(numerator: number, denominator: number) {
    return denominator === 0 ? 0 : this.round((numerator / denominator) * 100);
  }

  private sum(values: number[]) {
    return values.reduce((total, value) => total + value, 0);
  }

  private round(value: number) {
    return Math.round(value * 100) / 100;
  }

  /**
   * The PDF's lines. The PDF uses a standard font, which has no Arabic glyphs,
   * so a title it cannot draw is named by its id instead of being printed as
   * question marks — the spreadsheet exports carry the real titles.
   */
  private dashboardLines(dashboard: Awaited<ReturnType<AnalyticsService['dashboard']>>) {
    const latin = (text: string, fallback: string) =>
      /^[\x20-\x7e\xa0-\xff]*$/.test(text) ? text : fallback;
    return [
      'Ohara Analytics Report',
      `Range: ${dashboard.range.start.slice(0, 10)} to ${dashboard.range.end.slice(0, 10)}`,
      `Orders: ${dashboard.sales.total_orders} (paid ${dashboard.sales.paid_orders})`,
      `Gross revenue: ${formatTotals(dashboard.revenue.gross_revenue)}`,
      `Refunds: ${formatTotals(dashboard.revenue.refunds)}`,
      `Net revenue: ${formatTotals(dashboard.revenue.net_revenue)}`,
      `Average order value: ${formatTotals(dashboard.sales.average_order_value)}`,
      `Active customers: ${dashboard.customers.active_customers}`,
      `Repeat rate: ${dashboard.customers.repeat_rate}%`,
      `Overall conversion: ${dashboard.conversion.overall_conversion_rate}%`,
      `7 day retention: ${dashboard.retention.retention_7d_rate}%`,
      `Online users: ${dashboard.realtime.online_users}`,
      '',
      'Top products',
      ...dashboard.product_performance
        .slice(0, 20)
        .map(
          (row) =>
            `${latin(row.title, `Product ${row.product_id.slice(0, 8)}`)}: ${row.units} units / ${formatTotals(row.revenue)}`,
        ),
    ];
  }

  private dashboardRows(
    dashboard: Awaited<ReturnType<AnalyticsService['dashboard']>>,
  ): string[][] {
    return [
      ['Metric', 'Value'],
      ['From', dashboard.range.start],
      ['To', dashboard.range.end],
      ['Orders', String(dashboard.sales.total_orders)],
      ['Paid orders', String(dashboard.sales.paid_orders)],
      ['Gross revenue', formatTotals(dashboard.revenue.gross_revenue)],
      ['Refunds', formatTotals(dashboard.revenue.refunds)],
      ['Cancelled', formatTotals(dashboard.revenue.cancelled)],
      ['Net revenue', formatTotals(dashboard.revenue.net_revenue)],
      ['Average order value', formatTotals(dashboard.sales.average_order_value)],
      ['Active customers', String(dashboard.customers.active_customers)],
      ['New customers', String(dashboard.customers.new_customers)],
      ['Repeat rate', `${dashboard.customers.repeat_rate}%`],
      ['Conversion', `${dashboard.conversion.overall_conversion_rate}%`],
      ['7d retention', `${dashboard.retention.retention_7d_rate}%`],
      [],
      ['Date', 'Orders', 'Revenue'],
      ...dashboard.sales.series.map((row) => [
        row.date,
        String(row.orders),
        formatTotals(row.revenue),
      ]),
      [],
      ['Funnel step', 'Count'],
      ...dashboard.funnel.map((row) => [row.step, String(row.count)]),
      [],
      ['Product', 'Units', 'Revenue'],
      ...dashboard.product_performance.map((row) => [
        row.title,
        String(row.units),
        formatTotals(row.revenue),
      ]),
      [],
      ['Seller', 'Units', 'Revenue'],
      ...dashboard.seller_performance.map((row) => [
        row.seller,
        String(row.units),
        formatTotals(row.revenue),
      ]),
    ];
  }

  private simplePdf(lines: string[]) {
    const escaped = lines
      .flatMap((line, index) => [
        `BT /F1 11 Tf 50 ${760 - index * 18} Td (${this.escapePdf(line)}) Tj ET`,
      ])
      .join('\n');
    const objects = [
      '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj',
      '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj',
      '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj',
      '4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj',
      `5 0 obj << /Length ${Buffer.byteLength(escaped)} >> stream\n${escaped}\nendstream endobj`,
    ];
    let body = '%PDF-1.4\n';
    const offsets = [0];
    for (const object of objects) {
      offsets.push(Buffer.byteLength(body));
      body += `${object}\n`;
    }
    const xrefOffset = Buffer.byteLength(body);
    body += `xref\n0 ${objects.length + 1}\n`;
    body += '0000000000 65535 f \n';
    for (const offset of offsets.slice(1)) {
      body += `${offset.toString().padStart(10, '0')} 00000 n \n`;
    }
    body += `trailer << /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF`;
    return Buffer.from(body, 'utf8');
  }

  private escapePdf(value: string) {
    return value.replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)');
  }
}
