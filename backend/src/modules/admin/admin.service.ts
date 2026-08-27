import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  CommissionStatus,
  Currency,
  FinancialLedgerType,
  OrderStatus,
  Prisma,
  ProductStatus,
  ReportStatus,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money, REVENUE_STATUSES } from '../../common/money';
import {
  serializeOrder,
  serializeProduct,
  serializeUser,
} from '../../common/serializers';
import { AuthService } from '../auth/auth.service';
import { PRIVILEGED_ROLES, TotpService } from '../auth/totp/totp.service';
import { ReviewSellerVerificationDto } from '../auth/dto/account.dto';
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
import {
  PRODUCT_CARD_INCLUDE,
  PURCHASABLE_PRODUCT_WHERE,
} from '../../common/catalog/product-include';

/** Revenue lives on the sub-order — see CommissionsService for why. */
const revenueStatuses = [...REVENUE_STATUSES];

/** Totals are only ever summed WITHIN a currency. */
function totalsByCurrency(
  rows: { currency: Currency; _sum: { itemsSubtotal: Prisma.Decimal | null } }[],
) {
  return rows.map((row) =>
    Money.of(row._sum.itemsSubtotal ?? 0, row.currency).toJSON(),
  );
}

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
    private readonly totp: TotpService,
  ) {}

  async stats() {
    const now = new Date();
    const currentStart = new Date(now.getTime() - 30 * 24 * 60 * 60_000);
    const previousStart = new Date(now.getTime() - 60 * 24 * 60 * 60_000);
    const currentWindow: Prisma.DateTimeFilter = {
      gte: currentStart,
      lte: now,
    };
    const previousWindow: Prisma.DateTimeFilter = {
      gte: previousStart,
      lt: currentStart,
    };

    const [
      orderAgg,
      currentOrderAgg,
      previousOrderAgg,
      customerCount,
      currentCustomerCount,
      previousCustomerCount,
      sellerCount,
      pendingSellers,
      deliveredCount,
      totalOrders,
      currentDeliveredCount,
      currentTotalOrders,
      previousDeliveredCount,
      previousTotalOrders,
      openSupport,
      moderationOpen,
    ] = await Promise.all([
      this.prisma.sellerOrder.groupBy({
        by: ['currency'],
        where: { status: { in: revenueStatuses } },
        _sum: { itemsSubtotal: true },
      }),
      this.prisma.sellerOrder.groupBy({
        by: ['currency'],
        where: { status: { in: revenueStatuses }, createdAt: currentWindow },
        _sum: { itemsSubtotal: true },
      }),
      this.prisma.sellerOrder.groupBy({
        by: ['currency'],
        where: { status: { in: revenueStatuses }, createdAt: previousWindow },
        _sum: { itemsSubtotal: true },
      }),
      this.prisma.user.count({ where: { role: UserRole.CUSTOMER } }),
      this.prisma.user.count({
        where: { role: UserRole.CUSTOMER, createdAt: currentWindow },
      }),
      this.prisma.user.count({
        where: { role: UserRole.CUSTOMER, createdAt: previousWindow },
      }),
      this.prisma.user.count({ where: { role: UserRole.SELLER } }),
      this.prisma.sellerVerification.count({ where: { status: 'PENDING' } }),
      this.prisma.order.count({ where: { status: OrderStatus.DELIVERED } }),
      this.prisma.order.count(),
      this.prisma.order.count({
        where: { status: OrderStatus.DELIVERED, createdAt: currentWindow },
      }),
      this.prisma.order.count({ where: { createdAt: currentWindow } }),
      this.prisma.order.count({
        where: { status: OrderStatus.DELIVERED, createdAt: previousWindow },
      }),
      this.prisma.order.count({ where: { createdAt: previousWindow } }),
      this.prisma.supportTicket.count({ where: { status: { in: ['OPEN', 'PENDING'] } } }),
      this.prisma.moderationCase.count({ where: { status: 'OPEN' } }),
    ]);

    const totalSales = totalsByCurrency(orderAgg);
    // Trends compare like with like: the primary currency only.
    const primary = (
      rows: { currency: Currency; _sum: { itemsSubtotal: Prisma.Decimal | null } }[],
    ) =>
      Money.of(
        rows.find((row) => row.currency === Currency.SYP)?._sum.itemsSubtotal ??
          rows[0]?._sum.itemsSubtotal ??
          0,
        Currency.SYP,
      ).toUnsafeNumber();
    const conversionRate =
      totalOrders > 0 ? (deliveredCount / totalOrders) * 100 : 0;
    const currentConversionRate =
      currentTotalOrders > 0
        ? (currentDeliveredCount / currentTotalOrders) * 100
        : 0;
    const previousConversionRate =
      previousTotalOrders > 0
        ? (previousDeliveredCount / previousTotalOrders) * 100
        : 0;

    return {
      total_sales: totalSales,
      total_orders: totalOrders,
      active_users: customerCount,
      sellers: sellerCount,
      pending_seller_reviews: pendingSellers,
      open_support_tickets: openSupport,
      open_moderation_cases: moderationOpen,
      conversion_rate: Math.round(conversionRate * 10) / 10,
      sales_trend: this.formatTrend(
        primary(currentOrderAgg),
        primary(previousOrderAgg),
      ),
      orders_trend: this.formatTrend(currentTotalOrders, previousTotalOrders),
      users_trend: this.formatTrend(
        currentCustomerCount,
        previousCustomerCount,
      ),
      conversion_trend: this.formatPointTrend(
        currentConversionRate,
        previousConversionRate,
      ),
    };
  }

  async orders(query: AdminListQueryDto = new AdminListQueryDto()) {
    // The old implementation accepted a query object and ignored it entirely,
    // so admins could not filter the order list at all.
    const where: Prisma.OrderWhereInput = query.q
      ? {
          OR: [
            { number: { contains: query.q, mode: 'insensitive' } },
            { recipientName: { contains: query.q, mode: 'insensitive' } },
            { recipientPhone: { contains: query.q } },
          ],
        }
      : {};

    const orders = await this.prisma.order.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip: this.skip(query),
      take: query.limit,
      include: {
        sellerOrders: { include: { items: true } },
        user: true,
        payment: true,
      },
    });

    return orders.map((order) => ({
      ...serializeOrder(order),
      customer: order.user?.name ?? order.recipientName,
      is_guest: order.userId === null,
      payment_status: order.payment?.status.toLowerCase() ?? 'pending',
      sellers_count: order.sellerOrders.length,
    }));
  }

  async products(query: AdminListQueryDto = new AdminListQueryDto()) {
    const products = await this.prisma.product.findMany({
      orderBy: { createdAt: 'desc' },
      skip: this.skip(query),
      take: query.limit,
      include: PRODUCT_CARD_INCLUDE,
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

  async sellerApplications(query: AdminListQueryDto = new AdminListQueryDto()) {
    const applications = await this.prisma.sellerVerification.findMany({
      where: query.q
        ? {
            OR: [
              { businessName: { contains: query.q, mode: 'insensitive' } },
              { legalName: { contains: query.q, mode: 'insensitive' } },
              {
                commercialRegistration: {
                  contains: query.q,
                  mode: 'insensitive',
                },
              },
              { contactEmail: { contains: query.q, mode: 'insensitive' } },
            ],
          }
        : undefined,
      orderBy: { submittedAt: 'desc' },
      skip: this.skip(query),
      take: query.limit,
      include: { user: true },
    });
    return applications.map((application) =>
      this.serializeSellerApplication(application),
    );
  }

  async sellerApplication(id: string) {
    const application = await this.prisma.sellerVerification.findUnique({
      where: { id },
      include: {
        user: true,
        history: { orderBy: { createdAt: 'desc' }, include: { admin: true } },
      },
    });
    if (!application) throw new NotFoundException('Seller application not found');
    return this.serializeSellerApplication(application);
  }

  reviewSellerApplication(
    reviewerId: string,
    id: string,
    dto: ReviewSellerVerificationDto,
  ) {
    return this.auth.reviewSellerVerification(reviewerId, id, dto);
  }

  async updateUser(id: string, dto: UpdateUserAdminDto) {
    // A privileged account is only as strong as its weakest sign-in path, and
    // every other factor in this system arrives over a network that Syria can
    // lose for a day. Granting the role before the authenticator exists would
    // create exactly the account that cannot get in during the incident it is
    // needed for — so the order is enforced here rather than left to process.
    if (dto.role && PRIVILEGED_ROLES.includes(dto.role)) {
      if (!(await this.totp.isConfirmed(id))) {
        throw new BadRequestException({
          code: 'TOTP_REQUIRED_FOR_ROLE',
          message:
            'This account must set up an authenticator app before it can hold a privileged role',
        });
      }
    }

    const user = await this.prisma.user.update({
      where: { id },
      data: {
        ...(dto.role && { role: dto.role }),
        ...(dto.role && {
          totpRequired: PRIVILEGED_ROLES.includes(dto.role),
        }),
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
      include: PRODUCT_CARD_INCLUDE,
    });
    return serializeProduct(product);
  }

  async analytics() {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60_000);
    const [orders, users, products] = await Promise.all([
      this.prisma.order.findMany({
        where: { createdAt: { gte: thirtyDaysAgo } },
        select: {
          grandTotal: true,
          currency: true,
          createdAt: true,
          status: true,
        },
      }),
      this.prisma.user.count({ where: { createdAt: { gte: thirtyDaysAgo } } }),
      this.prisma.product.count({ where: { createdAt: { gte: thirtyDaysAgo } } }),
    ]);

    const buckets = new Map<string, Map<Currency, Money>>();
    for (const order of orders) {
      const label = order.createdAt.toISOString().slice(0, 10);
      const day = buckets.get(label) ?? new Map<Currency, Money>();
      const amount = Money.of(order.grandTotal, order.currency);
      const running = day.get(order.currency);
      day.set(order.currency, running ? running.plus(amount) : amount);
      buckets.set(label, day);
    }

    const revenue = new Map<Currency, Money>();
    for (const day of buckets.values()) {
      for (const [currency, amount] of day) {
        const running = revenue.get(currency);
        revenue.set(currency, running ? running.plus(amount) : amount);
      }
    }

    return {
      period: '30d',
      new_users: users,
      new_products: products,
      orders_count: orders.length,
      revenue: [...revenue.values()].map((amount) => amount.toJSON()),
      series: [...buckets.entries()].map(([label, value]) => ({
        label,
        value: [...value.values()].map((amount) => amount.toJSON()),
      })),
    };
  }

  async financials() {
    const [revenue, refunds, payments, ledger] = await Promise.all([
      // Gross revenue counts only revenue-bearing sub-orders. The old query
      // summed every order row with no status filter at all, so cancelled and
      // unpaid orders inflated the figure.
      this.prisma.sellerOrder.groupBy({
        by: ['currency'],
        where: { status: { in: revenueStatuses } },
        _sum: { itemsSubtotal: true },
      }),
      this.prisma.sellerOrder.groupBy({
        by: ['currency'],
        where: {
          status: {
            in: [SellerOrderStatus.REFUNDED, SellerOrderStatus.REFUND_PENDING],
          },
        },
        _sum: { itemsSubtotal: true },
      }),
      this.prisma.payment.groupBy({
        by: ['status', 'currency'],
        _sum: { capturedAmount: true },
        _count: { _all: true },
      }),
      this.prisma.financialLedgerEntry.findMany({
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
    ]);

    const grossByCurrency = new Map<Currency, Money>();
    for (const row of revenue) {
      grossByCurrency.set(
        row.currency,
        Money.of(row._sum.itemsSubtotal ?? 0, row.currency),
      );
    }
    const net = [...grossByCurrency.entries()].map(([currency, gross]) => {
      const refunded = refunds.find((row) => row.currency === currency);
      return gross
        .minus(Money.of(refunded?._sum.itemsSubtotal ?? 0, currency))
        .toJSON();
    });

    return {
      gross_revenue: totalsByCurrency(revenue),
      refunds: totalsByCurrency(refunds),
      net_revenue: net,
      payments: payments.map((payment) => ({
        status: payment.status.toLowerCase(),
        currency: payment.currency,
        amount: Money.of(
          payment._sum.capturedAmount ?? 0,
          payment.currency,
        ).toJSON(),
        count: payment._count._all,
      })),
      ledger: ledger.map((entry) => ({
        id: entry.id,
        type: entry.type.toLowerCase(),
        amount: Money.of(entry.amount, entry.currency).toJSON(),
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

  private serializeSellerApplication(application: any) {
    return {
      id: application.id,
      user: application.user ? serializeUser(application.user) : undefined,
      user_id: application.userId,
      status: application.status.toLowerCase(),
      business_name: application.businessName,
      legal_name: application.legalName,
      business_category: application.businessCategory,
      store_description: application.storeDescription,
      store_logo_url: application.storeLogoUrl,
      contact_phone: application.contactPhone,
      contact_email: application.contactEmail,
      business_address: application.businessAddress,
      warehouse_address: application.warehouseAddress,
      commercial_registration: application.commercialRegistration,
      government_id_url: application.governmentIdUrl,
      business_license_url: application.businessLicenseUrl,
      tax_id: application.taxId,
      bank_name: application.bankName,
      account_holder: application.accountHolder,
      iban: application.iban,
      payment_information: application.paymentInformation,
      shipping_methods: application.shippingMethods,
      return_policy: application.returnPolicy,
      product_categories: application.productCategories,
      years_experience: application.yearsExperience,
      website: application.website,
      social_media_links: application.socialMediaLinks,
      document_urls: application.documentUrls,
      review_reason: application.reviewReason,
      rejection_reason: application.rejectionReason,
      reviewed_by: application.reviewedBy,
      reviewed_at: application.reviewedAt?.toISOString() ?? null,
      submitted_at: application.submittedAt.toISOString(),
      updated_at: application.updatedAt.toISOString(),
      history: Array.isArray(application.history)
        ? application.history.map((entry: any) => ({
            id: entry.id,
            status: entry.status.toLowerCase(),
            reason: entry.reason,
            admin_id: entry.adminId,
            admin_name: entry.admin?.name,
            created_at: entry.createdAt.toISOString(),
          }))
        : undefined,
    };
  }

  private skip(query: AdminListQueryDto) {
    return (query.page - 1) * query.limit;
  }

  private formatTrend(current: number, previous: number) {
    if (previous === 0) return current === 0 ? '+0%' : '+100%';
    const change = ((current - previous) / previous) * 100;
    return this.formatPercent(change);
  }

  private formatPointTrend(current: number, previous: number) {
    return this.formatPercent(current - previous);
  }

  private formatPercent(value: number) {
    const rounded = Math.round(value * 10) / 10;
    const prefix = rounded >= 0 ? '+' : '';
    return `${prefix}${rounded}%`;
  }
}
