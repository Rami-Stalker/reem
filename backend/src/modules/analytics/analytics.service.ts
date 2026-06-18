import { BadRequestException, Injectable } from '@nestjs/common';
import {
  AnalyticsEventType,
  AnalyticsExportFormat,
  OrderStatus,
  Prisma,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
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

const revenueStatuses: OrderStatus[] = [
  OrderStatus.PAID,
  OrderStatus.PROCESSING,
  OrderStatus.SHIPPED,
  OrderStatus.DELIVERED,
];

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
      select: { id: true, total: true, status: true, createdAt: true },
      orderBy: { createdAt: 'asc' },
    });
    const byDay = new Map<string, { orders: number; revenue: number }>();
    const byStatus = new Map<string, number>();
    for (const order of orders) {
      const day = order.createdAt.toISOString().slice(0, 10);
      const current = byDay.get(day) ?? { orders: 0, revenue: 0 };
      current.orders += 1;
      if (revenueStatuses.includes(order.status)) current.revenue += order.total;
      byDay.set(day, current);
      byStatus.set(order.status, (byStatus.get(order.status) ?? 0) + 1);
    }
    return {
      total_orders: orders.length,
      paid_orders: orders.filter((order) => revenueStatuses.includes(order.status))
        .length,
      average_order_value: this.round(
        this.sum(orders.map((order) => order.total)) / Math.max(orders.length, 1),
      ),
      by_status: [...byStatus.entries()].map(([status, count]) => ({
        status: status.toLowerCase(),
        count,
      })),
      series: [...byDay.entries()].map(([date, value]) => ({
        date,
        orders: value.orders,
        revenue: this.round(value.revenue),
      })),
    };
  }

  async revenue(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const where = this.orderWhere(query, user, range);
    const [gross, refunded, paid] = await Promise.all([
      this.prisma.order.aggregate({ where, _sum: { total: true } }),
      this.prisma.order.aggregate({
        where: { ...where, status: OrderStatus.REFUNDED },
        _sum: { total: true },
      }),
      this.prisma.payment.aggregate({
        where: { order: { is: where }, status: 'PAID' },
        _sum: { amount: true },
      }),
    ]);
    const grossRevenue = gross._sum.total ?? 0;
    const refunds = refunded._sum.total ?? 0;
    return {
      gross_revenue: this.round(grossRevenue),
      paid_revenue: this.round(paid._sum.amount ?? 0),
      refunds: this.round(refunds),
      net_revenue: this.round(grossRevenue - refunds),
    };
  }

  async productPerformance(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const sellerId = this.sellerScope(query, user);
    const items = await this.prisma.orderItem.findMany({
      where: {
        ...(query.product_id ? { productId: query.product_id } : {}),
        order: { createdAt: { gte: range.start, lte: range.end } },
        ...(sellerId ? { product: { sellerId } } : {}),
      },
      include: { product: { select: { id: true, title: true, sellerId: true } } },
    });
    const rows = new Map<
      string,
      { product_id: string; title: string; units: number; revenue: number }
    >();
    for (const item of items) {
      const row =
        rows.get(item.productId) ??
        {
          product_id: item.productId,
          title: item.product.title,
          units: 0,
          revenue: 0,
        };
      row.units += item.quantity;
      row.revenue += item.quantity * item.price;
      rows.set(item.productId, row);
    }
    return [...rows.values()]
      .sort((a, b) => b.revenue - a.revenue)
      .slice(0, 20)
      .map((row) => ({ ...row, revenue: this.round(row.revenue) }));
  }

  async sellerPerformance(query: AnalyticsQueryDto, user: AnalyticsUser) {
    const range = this.range(query);
    const sellerId = this.sellerScope(query, user);
    const items = await this.prisma.orderItem.findMany({
      where: {
        order: { createdAt: { gte: range.start, lte: range.end } },
        ...(sellerId ? { product: { sellerId } } : {}),
      },
      include: {
        product: {
          select: { sellerId: true, seller: { select: { name: true } } },
        },
      },
    });
    const rows = new Map<
      string,
      { seller_id: string; seller: string; units: number; revenue: number }
    >();
    for (const item of items) {
      const row =
        rows.get(item.product.sellerId) ??
        {
          seller_id: item.product.sellerId,
          seller: item.product.seller.name,
          units: 0,
          revenue: 0,
        };
      row.units += item.quantity;
      row.revenue += item.quantity * item.price;
      rows.set(item.product.sellerId, row);
    }
    return [...rows.values()]
      .sort((a, b) => b.revenue - a.revenue)
      .slice(0, 20)
      .map((row) => ({ ...row, revenue: this.round(row.revenue) }));
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
      this.prisma.order.findMany({ where, select: { userId: true, total: true } }),
    ]);
    const byCustomer = new Map<string, { orders: number; spend: number }>();
    for (const order of orders) {
      const row = byCustomer.get(order.userId) ?? { orders: 0, spend: 0 };
      row.orders += 1;
      row.spend += order.total;
      byCustomer.set(order.userId, row);
    }
    const repeat = [...byCustomer.values()].filter((row) => row.orders > 1);
    return {
      active_customers: byCustomer.size,
      new_customers: newCustomers,
      repeat_customers: repeat.length,
      repeat_rate:
        byCustomer.size === 0 ? 0 : this.round((repeat.length / byCustomer.size) * 100),
      average_customer_value: this.round(
        this.sum([...byCustomer.values()].map((row) => row.spend)) /
          Math.max(byCustomer.size, 1),
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
      const cohort = userCohort.get(order.userId);
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
    const sellerFilter =
      user.role === UserRole.SELLER
        ? { items: { some: { product: { sellerId: user.id } } } }
        : {};
    const [orders, revenue, onlineUsers, activeCarts] = await Promise.all([
      this.prisma.order.count({
        where: { createdAt: { gte: today }, ...sellerFilter },
      }),
      this.prisma.order.aggregate({
        where: {
          createdAt: { gte: today },
          status: { in: revenueStatuses },
          ...sellerFilter,
        },
        _sum: { total: true },
      }),
      this.prisma.userPresence.count({ where: { status: 'ONLINE' } }),
      this.prisma.cartItem.count({ where: { updatedAt: { gte: today } } }),
    ]);
    return {
      today_orders: orders,
      today_revenue: this.round(revenue._sum.total ?? 0),
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
    const itemFilter: Prisma.OrderItemWhereInput = {
      ...(query.product_id ? { productId: query.product_id } : {}),
      ...(sellerId ? { product: { sellerId } } : {}),
    };
    return {
      createdAt: { gte: range.start, lte: range.end },
      ...(Object.keys(itemFilter).length > 0
        ? { items: { some: itemFilter } }
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
