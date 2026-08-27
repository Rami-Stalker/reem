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
import { Money, REVENUE_STATUSES } from '../../common/money';
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

/** Money is aggregated within a currency, never across. */
type CurrencyTotals = Map<Currency, Money>;

function addTo(totals: CurrencyTotals, amount: Money): void {
  const running = totals.get(amount.currency);
  totals.set(amount.currency, running ? running.plus(amount) : amount);
}

function serializeTotals(totals: CurrencyTotals) {
  return [...totals.values()].map((total) => total.toJSON());
}

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async track(userId: string, dto: TrackAnalyticsEventDto) {
    const event = await this.prisma.analyticsEvent.create({
      data: {
        type: dto.type,
        userId,
        sessionId: dto.session_id,
        productId: dto.product_id,
        sellerId: dto.seller_id,
        orderId: dto.order_id,
        source: dto.source,
        metadata: dto.metadata as Prisma.InputJsonValue,
      },
    });
    return { id: event.id, tracked_at: event.createdAt.toISOString() };
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

  async sales(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const where = this.orderWhere(query, user, range);
    const orders = await this.prisma.order.findMany({
      where,
      select: {
        id: true,
        currency: true,
        grandTotal: true,
        createdAt: true,
        sellerOrders: { select: { status: true, itemsSubtotal: true, currency: true } },
      },
      orderBy: { createdAt: 'asc' },
    });

    const byDay = new Map<string, { orders: number; revenue: CurrencyTotals }>();
    const byStatus = new Map<string, number>();
    const orderValues: CurrencyTotals = new Map();
    let revenueBearing = 0;

    for (const order of orders) {
      const day = order.createdAt.toISOString().slice(0, 10);
      const current = byDay.get(day) ?? { orders: 0, revenue: new Map() };
      current.orders += 1;

      let counted = false;
      for (const sub of order.sellerOrders) {
        byStatus.set(sub.status, (byStatus.get(sub.status) ?? 0) + 1);
        if (!revenueStatuses.includes(sub.status)) continue;
        addTo(current.revenue, Money.of(sub.itemsSubtotal, sub.currency));
        counted = true;
      }
      if (counted) revenueBearing += 1;

      byDay.set(day, current);
      addTo(orderValues, Money.of(order.grandTotal, order.currency));
    }

    return {
      total_orders: orders.length,
      paid_orders: revenueBearing,
      average_order_value: [...orderValues.entries()].map(([, total]) =>
        total.dividedBy(Math.max(orders.length, 1)).roundForCurrency().toJSON(),
      ),
      by_status: [...byStatus.entries()].map(([status, count]) => ({
        status: status.toLowerCase(),
        count,
      })),
      series: [...byDay.entries()].map(([date, value]) => ({
        date,
        orders: value.orders,
        revenue: serializeTotals(value.revenue),
      })),
    };
  }

  async revenue(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const where = this.orderWhere(query, user, range);

    const [gross, refunded, paid] = await Promise.all([
      this.prisma.order.groupBy({
        by: ['currency'],
        where,
        _sum: { grandTotal: true },
      }),
      this.prisma.order.groupBy({
        by: ['currency'],
        where: { ...where, status: OrderStatus.CANCELLED },
        _sum: { grandTotal: true },
      }),
      this.prisma.payment.groupBy({
        by: ['currency'],
        where: { order: { is: where }, status: 'PAID' },
        _sum: { capturedAmount: true },
      }),
    ]);

    const grossTotals: CurrencyTotals = new Map();
    for (const row of gross) {
      addTo(grossTotals, Money.of(row._sum.grandTotal ?? 0, row.currency));
    }
    const refundTotals: CurrencyTotals = new Map();
    for (const row of refunded) {
      addTo(refundTotals, Money.of(row._sum.grandTotal ?? 0, row.currency));
    }

    const net: CurrencyTotals = new Map();
    for (const [currency, amount] of grossTotals) {
      net.set(
        currency,
        amount.minus(refundTotals.get(currency) ?? Money.zero(currency)),
      );
    }

    return {
      gross_revenue: serializeTotals(grossTotals),
      paid_revenue: paid.map((row) =>
        Money.of(row._sum.capturedAmount ?? 0, row.currency).toJSON(),
      ),
      refunds: serializeTotals(refundTotals),
      net_revenue: serializeTotals(net),
    };
  }

  async productPerformance(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const sellerId = this.sellerScope(query, user);
    const items = await this.prisma.orderItem.findMany({
      where: {
        ...(query.product_id ? { productId: query.product_id } : {}),
        sellerOrder: {
          createdAt: { gte: range.start, lte: range.end },
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
    const where = this.orderWhere(query, user, range);
    const [newCustomers, orders] = await Promise.all([
      this.prisma.user.count({
        where: {
          role: UserRole.CUSTOMER,
          createdAt: { gte: range.start, lte: range.end },
        },
      }),
      this.prisma.order.findMany({
        where,
        select: { userId: true, grandTotal: true, currency: true },
      }),
    ]);
    const byCustomer = new Map<string, { orders: number; spend: CurrencyTotals }>();
    for (const order of orders) {
      // Guest checkouts have no user id and are excluded from per-customer
      // metrics rather than being bucketed under a fake key.
      if (!order.userId) continue;
      const row = byCustomer.get(order.userId) ?? {
        orders: 0,
        spend: new Map<Currency, Money>(),
      };
      row.orders += 1;
      addTo(row.spend, Money.of(order.grandTotal, order.currency));
      byCustomer.set(order.userId, row);
    }
    const repeat = [...byCustomer.values()].filter((row) => row.orders > 1);
    return {
      active_customers: byCustomer.size,
      new_customers: newCustomers,
      repeat_customers: repeat.length,
      repeat_rate:
        byCustomer.size === 0 ? 0 : this.round((repeat.length / byCustomer.size) * 100),
      average_customer_value: (() => {
        const totals: CurrencyTotals = new Map();
        for (const row of byCustomer.values()) {
          for (const amount of row.spend.values()) addTo(totals, amount);
        }
        return [...totals.values()].map((total) =>
          total.dividedBy(Math.max(byCustomer.size, 1)).roundForCurrency().toJSON(),
        );
      })(),
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
    const [users, orders] = await Promise.all([
      this.prisma.user.findMany({
        where: {
          role: UserRole.CUSTOMER,
          createdAt: { gte: range.start, lte: range.end },
        },
        select: { id: true, createdAt: true },
      }),
      this.prisma.order.findMany({
        where,
        select: { userId: true, createdAt: true },
      }),
    ]);
    const userCohort = new Map(
      users.map((user) => [user.id, user.createdAt.toISOString().slice(0, 7)]),
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
    return [...cohorts.entries()].map(([cohort, value]) => ({
      cohort,
      customers: value.users,
      orders: value.orders,
      orders_per_customer: this.round(value.orders / Math.max(value.users, 1)),
    }));
  }

  async realtime(user: AnalyticsUser) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const sellerFilter: Prisma.OrderWhereInput =
      user.role === UserRole.SELLER
        ? { sellerOrders: { some: { sellerId: user.id } } }
        : {};
    const [orders, revenue, onlineUsers, activeCarts] = await Promise.all([
      this.prisma.order.count({
        where: { createdAt: { gte: today }, ...sellerFilter },
      }),
      this.prisma.sellerOrder.groupBy({
        by: ['currency'],
        where: {
          createdAt: { gte: today },
          status: { in: revenueStatuses },
          ...(user.role === UserRole.SELLER ? { sellerId: user.id } : {}),
        },
        _sum: { itemsSubtotal: true },
      }),
      this.prisma.userPresence.count({ where: { status: 'ONLINE' } }),
      this.prisma.cartItem.count({ where: { updatedAt: { gte: today } } }),
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
      const tsv = this.dashboardTsv(dashboard);
      return {
        filename:
          query.format === AnalyticsExportFormat.CSV
            ? 'reem-analytics.csv'
            : 'reem-analytics.xls',
        contentType:
          query.format === AnalyticsExportFormat.CSV
            ? 'text/csv'
            : 'application/vnd.ms-excel',
        buffer: Buffer.from(
          query.format === AnalyticsExportFormat.CSV
            ? tsv.replace(/\t/g, ',')
            : tsv,
          'utf8',
        ),
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
        ...(sellerId ? { sellerId } : {}),
        ...(productId ? { productId } : {}),
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

  private dashboardLines(dashboard: Awaited<ReturnType<AnalyticsService['dashboard']>>) {
    return [
      'Reem Analytics Report',
      `Range: ${dashboard.range.start} - ${dashboard.range.end}`,
      `Orders: ${dashboard.sales.total_orders}`,
      `Gross revenue: ${dashboard.revenue.gross_revenue}`,
      `Net revenue: ${dashboard.revenue.net_revenue}`,
      `Active customers: ${dashboard.customers.active_customers}`,
      `Repeat rate: ${dashboard.customers.repeat_rate}%`,
      `Overall conversion: ${dashboard.conversion.overall_conversion_rate}%`,
      `7 day retention: ${dashboard.retention.retention_7d_rate}%`,
      `Online users: ${dashboard.realtime.online_users}`,
      '',
      'Top products',
      ...dashboard.product_performance
        .slice(0, 8)
        .map((row) => `${row.title}: ${row.units} units / ${row.revenue}`),
    ];
  }

  private dashboardTsv(
    dashboard: Awaited<ReturnType<AnalyticsService['dashboard']>>,
  ) {
    const lines = [
      ['Metric', 'Value'],
      ['Orders', String(dashboard.sales.total_orders)],
      ['Gross revenue', String(dashboard.revenue.gross_revenue)],
      ['Net revenue', String(dashboard.revenue.net_revenue)],
      ['Active customers', String(dashboard.customers.active_customers)],
      ['Repeat rate', `${dashboard.customers.repeat_rate}%`],
      ['Conversion', `${dashboard.conversion.overall_conversion_rate}%`],
      ['7d retention', `${dashboard.retention.retention_7d_rate}%`],
      [],
      ['Product', 'Units', 'Revenue'],
      ...dashboard.product_performance.map((row) => [
        row.title,
        String(row.units),
        String(row.revenue),
      ]),
    ];
    return lines.map((line) => line.join('\t')).join('\n');
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
