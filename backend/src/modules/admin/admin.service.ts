import { Injectable, NotFoundException } from '@nestjs/common';
import {
  CommissionStatus,
  FinancialLedgerType,
  OrderStatus,
  Prisma,
  ProductStatus,
  ReportStatus,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  serializeOrder,
  serializeProduct,
  serializeUser,
} from '../../common/serializers';
import {
  AdminListQueryDto,
  CreateCommissionRuleDto,
  UpdateCommissionLedgerDto,
  UpdateModerationCaseDto,
  UpdateProductAdminDto,
  UpdateReportDto,
  UpdateSupportTicketDto,
  UpdateUserAdminDto,
  UpsertSystemSettingDto,
} from './dto/admin.dto';

const productInclude = {
  seller: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
} satisfies Prisma.ProductInclude;

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  async stats() {
    const [
      orderAgg,
      customerCount,
      sellerCount,
      pendingSellers,
      deliveredCount,
      totalOrders,
      openSupport,
      moderationOpen,
    ] = await Promise.all([
      this.prisma.order.aggregate({
        _sum: { total: true },
        where: {
          status: {
            in: [
              OrderStatus.DELIVERED,
              OrderStatus.SHIPPED,
              OrderStatus.PROCESSING,
              OrderStatus.PAID,
            ],
          },
        },
      }),
      this.prisma.user.count({ where: { role: UserRole.CUSTOMER } }),
      this.prisma.user.count({ where: { role: UserRole.SELLER } }),
      this.prisma.sellerVerification.count({ where: { status: 'PENDING' } }),
      this.prisma.order.count({ where: { status: OrderStatus.DELIVERED } }),
      this.prisma.order.count(),
      this.prisma.supportTicket.count({ where: { status: { in: ['OPEN', 'PENDING'] } } }),
      this.prisma.moderationCase.count({ where: { status: 'OPEN' } }),
    ]);

    const totalSales = orderAgg._sum.total ?? 0;
    const conversionRate =
      totalOrders > 0 ? (deliveredCount / totalOrders) * 100 : 0;

    return {
      total_sales: totalSales,
      total_orders: totalOrders,
      active_users: customerCount,
      sellers: sellerCount,
      pending_seller_reviews: pendingSellers,
      open_support_tickets: openSupport,
      open_moderation_cases: moderationOpen,
      conversion_rate: Math.round(conversionRate * 10) / 10,
      sales_trend: '+12.4%',
      orders_trend: '+8.1%',
      users_trend: '+3.2%',
      conversion_trend: '-0.4%',
    };
  }

  async orders(query: AdminListQueryDto = new AdminListQueryDto()) {
    const orders = await this.prisma.order.findMany({
      orderBy: { createdAt: 'desc' },
      skip: this.skip(query),
      take: query.limit,
      include: { items: true, user: true, payment: true },
    });
    return orders.map((order) => ({
      ...serializeOrder(order),
      customer: order.user.name,
      payment_status: order.payment?.status.toLowerCase() ?? 'pending',
    }));
  }

  async products(query: AdminListQueryDto = new AdminListQueryDto()) {
    const products = await this.prisma.product.findMany({
      orderBy: { createdAt: 'desc' },
      skip: this.skip(query),
      take: query.limit,
      include: productInclude,
    });
    return products.map((product) => serializeProduct(product));
  }

  async users(query: AdminListQueryDto = new AdminListQueryDto()) {
    const users = await this.prisma.user.findMany({
      where: query.q
        ? {
            OR: [
              { name: { contains: query.q, mode: 'insensitive' } },
              { phone: { contains: query.q } },
              { email: { contains: query.q, mode: 'insensitive' } },
            ],
          }
        : undefined,
      orderBy: { createdAt: 'desc' },
      skip: this.skip(query),
      take: query.limit,
    });
    return users.map(serializeUser);
  }

  async sellers(query: AdminListQueryDto = new AdminListQueryDto()) {
    const sellers = await this.prisma.user.findMany({
      where: { role: UserRole.SELLER },
      orderBy: { createdAt: 'desc' },
      skip: this.skip(query),
      take: query.limit,
      include: { sellerVerification: true },
    });
    return sellers.map((seller) => ({
      ...serializeUser(seller),
      verification_status:
        seller.sellerVerification?.status.toLowerCase() ?? 'not_submitted',
    }));
  }

  async updateUser(id: string, dto: UpdateUserAdminDto) {
    const user = await this.prisma.user.update({
      where: { id },
      data: {
        ...(dto.role && { role: dto.role }),
        ...(dto.disabled !== undefined && {
          disabledAt: dto.disabled ? new Date() : null,
        }),
      },
    });
    return serializeUser(user);
  }

  async updateProduct(id: string, dto: UpdateProductAdminDto) {
    const product = await this.prisma.product.update({
      where: { id },
      data: { ...(dto.status && { status: dto.status }) },
      include: productInclude,
    });
    return serializeProduct(product);
  }

  async analytics() {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60_000);
    const [orders, users, products] = await Promise.all([
      this.prisma.order.findMany({
        where: { createdAt: { gte: thirtyDaysAgo } },
        select: { total: true, createdAt: true, status: true },
      }),
      this.prisma.user.count({ where: { createdAt: { gte: thirtyDaysAgo } } }),
      this.prisma.product.count({ where: { createdAt: { gte: thirtyDaysAgo } } }),
    ]);

    const buckets = new Map<string, number>();
    for (const order of orders) {
      const label = order.createdAt.toISOString().slice(0, 10);
      buckets.set(label, (buckets.get(label) ?? 0) + order.total);
    }

    return {
      period: '30d',
      new_users: users,
      new_products: products,
      orders_count: orders.length,
      revenue: orders.reduce((sum, order) => sum + order.total, 0),
      series: [...buckets.entries()].map(([label, value]) => ({
        label,
        value: Math.round(value * 100) / 100,
      })),
    };
  }

  async financials() {
    const [revenue, refunds, payments, ledger] = await Promise.all([
      this.prisma.order.aggregate({ _sum: { total: true } }),
      this.prisma.order.aggregate({
        _sum: { total: true },
        where: { status: OrderStatus.REFUNDED },
      }),
      this.prisma.payment.groupBy({
        by: ['status'],
        _sum: { amount: true },
        _count: { _all: true },
      }),
      this.prisma.financialLedgerEntry.findMany({
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
    ]);

    return {
      gross_revenue: revenue._sum.total ?? 0,
      refunds: refunds._sum.total ?? 0,
      net_revenue: (revenue._sum.total ?? 0) - (refunds._sum.total ?? 0),
      payments: payments.map((payment) => ({
        status: payment.status.toLowerCase(),
        amount: payment._sum.amount ?? 0,
        count: payment._count._all,
      })),
      ledger: ledger.map((entry) => ({
        id: entry.id,
        type: entry.type.toLowerCase(),
        amount: entry.amount,
        currency: entry.currency,
        description: entry.description,
        created_at: entry.createdAt.toISOString(),
      })),
    };
  }

  async commissions() {
    const [rules, ledgers, pendingAgg] = await Promise.all([
      this.prisma.commissionRule.findMany({ orderBy: { createdAt: 'desc' } }),
      this.prisma.commissionLedger.findMany({
        orderBy: { createdAt: 'desc' },
        take: 100,
      }),
      this.prisma.commissionLedger.aggregate({
        _sum: { commission: true },
        where: { status: CommissionStatus.PENDING },
      }),
    ]);
    return {
      pending_commission: pendingAgg._sum.commission ?? 0,
      rules: rules.map((rule) => ({
        id: rule.id,
        name: rule.name,
        rate_bps: rule.rateBps,
        category: rule.category,
        active: rule.active,
      })),
      ledgers: ledgers.map((entry) => ({
        id: entry.id,
        seller_id: entry.sellerId,
        gross: entry.gross,
        commission: entry.commission,
        net: entry.net,
        status: entry.status.toLowerCase(),
        created_at: entry.createdAt.toISOString(),
      })),
    };
  }

  async createCommissionRule(dto: CreateCommissionRuleDto) {
    return this.prisma.commissionRule.create({
      data: {
        name: dto.name,
        rateBps: dto.rate_bps,
        category: dto.category,
        sellerTier: dto.seller_tier,
      },
    });
  }

  async updateCommissionLedger(id: string, dto: UpdateCommissionLedgerDto) {
    return this.prisma.commissionLedger.update({
      where: { id },
      data: {
        status: dto.status,
        ...(dto.status === CommissionStatus.PAID && { paidAt: new Date() }),
      },
    });
  }

  support() {
    return this.prisma.supportTicket.findMany({
      orderBy: [{ priority: 'desc' }, { updatedAt: 'desc' }],
      take: 100,
      include: { user: true, _count: { select: { messages: true } } },
    });
  }

  updateSupportTicket(id: string, dto: UpdateSupportTicketDto) {
    return this.prisma.supportTicket.update({
      where: { id },
      data: {
        ...(dto.status && { status: dto.status }),
        ...(dto.priority && { priority: dto.priority }),
      },
    });
  }

  moderation() {
    return this.prisma.moderationCase.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  updateModeration(id: string, dto: UpdateModerationCaseDto) {
    return this.prisma.moderationCase.update({
      where: { id },
      data: { status: dto.status, resolution: dto.resolution },
    });
  }

  reports() {
    return this.prisma.adminReport.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  updateReport(id: string, dto: UpdateReportDto) {
    return this.prisma.adminReport.update({
      where: { id },
      data: {
        status: dto.status,
        ...(dto.status === ReportStatus.RESOLVED && { resolvedAt: new Date() }),
      },
    });
  }

  auditLogs() {
    return this.prisma.auditLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200,
      include: { actor: true },
    });
  }

  systemSettings() {
    return this.prisma.systemSetting.findMany({ orderBy: { key: 'asc' } });
  }

  async upsertSystemSetting(actorId: string, dto: UpsertSystemSettingDto) {
    const setting = await this.prisma.systemSetting.upsert({
      where: { key: dto.key },
      create: {
        key: dto.key,
        value: dto.value as Prisma.InputJsonValue,
        sensitive: dto.sensitive ?? false,
        updatedBy: actorId,
      },
      update: {
        value: dto.value as Prisma.InputJsonValue,
        sensitive: dto.sensitive,
        updatedBy: actorId,
      },
    });
    return setting;
  }

  async ensureProduct(id: string) {
    const product = await this.prisma.product.findUnique({ where: { id } });
    if (!product) throw new NotFoundException('Product not found');
    return product;
  }

  private skip(query: AdminListQueryDto) {
    return (query.page - 1) * query.limit;
  }
}
