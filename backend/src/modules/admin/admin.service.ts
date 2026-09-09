import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AuditSeverity,
  CommissionStatus,
  Currency,
  LedgerDirection,
  FinancialLedgerType,
  ModerationStatus,
  OrderStatus,
  Prisma,
  ProductStatus,
  ReportStatus,
  SellerOrderStatus,
  SellerVerificationStatus,
  SupportTicketStatus,
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
import { AuditService } from '../auth/audit.service';
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

/**
 * The envelope every admin list speaks.
 *
 * These endpoints used to return a bare array cut at `take`, with no total and
 * no way to ask for the second page — so a console listing "users" was really
 * listing "the twenty-five newest users", and said nothing about the other
 * eleven thousand. Search made it worse, not better: the client filtered the
 * page it happened to be holding, so searching for a woman who signed up last
 * year returned nothing and looked like an answer.
 */
export interface AdminPage<T> {
  items: T[];
  page: number;
  limit: number;
  total: number;
  has_more: boolean;
}

/**
 * The queue filter, only if the table understands it.
 *
 * `status` arrives as a free string because six different enums share one
 * query DTO. Handing an unrecognised token straight to Prisma turns a typo in
 * a URL into a 500; dropping it answers the unfiltered question instead, which
 * is what an operator who mistyped a filter would rather see than a crash.
 */
function statusIn<T extends Record<string, string>>(
  values: T,
  token: string | undefined,
): T[keyof T] | undefined {
  if (!token) return undefined;
  return Object.values(values).includes(token)
    ? (token as T[keyof T])
    : undefined;
}

function pageOf<T>(
  items: T[],
  total: number,
  query: AdminListQueryDto,
): AdminPage<T> {
  return {
    items,
    page: query.page,
    limit: query.limit,
    total,
    has_more: query.page * query.limit < total,
  };
}

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
    private readonly totp: TotpService,
    private readonly audit: AuditService,
  ) {}

  /**
   * Every write on this service is a staff action taken on someone else's
   * account, catalogue, money, or complaint. The console already has a screen
   * that promises an audit trail; until now that trail recorded sign-ins and
   * seller reviews and nothing an administrator did from the other eleven
   * screens. `AuditService.record` swallows its own failures by design, so
   * this never turns a successful moderation action into a 500.
   */
  private trace(
    actorId: string,
    action: string,
    metadata: Prisma.InputJsonValue,
    severity: AuditSeverity = AuditSeverity.INFO,
  ) {
    return this.audit.record({
      actorId,
      action,
      category: 'admin',
      outcome: 'success',
      severity,
      metadata,
    });
  }

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

    const [orders, total] = await Promise.all([
      this.prisma.order.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: this.skip(query),
        take: query.limit,
        include: {
          sellerOrders: { include: { items: true } },
          user: true,
          payment: true,
        },
      }),
      this.prisma.order.count({ where }),
    ]);

    return pageOf(
      orders.map((order) => ({
        ...serializeOrder(order),
        customer: order.user?.name ?? order.recipientName,
        is_guest: order.userId === null,
        payment_status: order.payment?.status.toLowerCase() ?? 'pending',
        sellers_count: order.sellerOrders.length,
      })),
      total,
      query,
    );
  }

  async products(query: AdminListQueryDto = new AdminListQueryDto()) {
    // `q` was accepted and thrown away here, so the catalogue screen searched
    // whatever twenty-five rows it already had.
    const where: Prisma.ProductWhereInput = {
      ...(statusIn(ProductStatus, query.status) && {
        status: statusIn(ProductStatus, query.status),
      }),
      ...(query.q && {
        OR: [
          { title: { contains: query.q, mode: 'insensitive' } },
          { slug: { contains: query.q, mode: 'insensitive' } },
          { gtin: { contains: query.q, mode: 'insensitive' } },
        ],
      }),
    };

    const [products, total] = await Promise.all([
      this.prisma.product.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: this.skip(query),
        take: query.limit,
        include: PRODUCT_CARD_INCLUDE,
      }),
      this.prisma.product.count({ where }),
    ]);
    return pageOf(
      products.map((product) => serializeProduct(product)),
      total,
      query,
    );
  }

  async users(query: AdminListQueryDto = new AdminListQueryDto()) {
    const where: Prisma.UserWhereInput = query.q
      ? {
          OR: [
            { name: { contains: query.q, mode: 'insensitive' } },
            { username: { contains: query.q, mode: 'insensitive' } },
            { phone: { contains: query.q } },
            { email: { contains: query.q, mode: 'insensitive' } },
          ],
        }
      : {};

    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: this.skip(query),
        take: query.limit,
      }),
      this.prisma.user.count({ where }),
    ]);
    return pageOf(users.map((user) => this.serializeAdminUser(user)), total, query);
  }

  async sellers(query: AdminListQueryDto = new AdminListQueryDto()) {
    const where: Prisma.UserWhereInput = {
      role: UserRole.SELLER,
      ...(query.q && {
        OR: [
          { name: { contains: query.q, mode: 'insensitive' } },
          { username: { contains: query.q, mode: 'insensitive' } },
          { phone: { contains: query.q } },
          { email: { contains: query.q, mode: 'insensitive' } },
        ],
      }),
    };

    const [sellers, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: this.skip(query),
        take: query.limit,
        include: { sellerVerification: true },
      }),
      this.prisma.user.count({ where }),
    ]);
    return pageOf(
      sellers.map((seller) => ({
        ...this.serializeAdminUser(seller),
        verification_id: seller.sellerVerification?.id ?? null,
        verification_status:
          seller.sellerVerification?.status.toLowerCase() ?? 'not_submitted',
      })),
      total,
      query,
    );
  }

  async sellerApplications(query: AdminListQueryDto = new AdminListQueryDto()) {
    const where: Prisma.SellerVerificationWhereInput = {
      ...(statusIn(SellerVerificationStatus, query.status) && {
        status: statusIn(SellerVerificationStatus, query.status),
      }),
      ...(query.q && {
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
      }),
    };

    const [applications, total, pending] = await Promise.all([
      this.prisma.sellerVerification.findMany({
        where,
        // Pending work first: a queue sorted purely by recency buries the
        // application that has been waiting longest under today's arrivals.
        orderBy: [{ status: 'asc' }, { submittedAt: 'desc' }],
        skip: this.skip(query),
        take: query.limit,
        include: { user: true },
      }),
      this.prisma.sellerVerification.count({ where }),
      this.prisma.sellerVerification.count({ where: { status: 'PENDING' } }),
    ]);
    return {
      ...pageOf(
        applications.map((application) =>
          this.serializeSellerApplication(application),
        ),
        total,
        query,
      ),
      pending,
    };
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

  async updateUser(actorId: string, id: string, dto: UpdateUserAdminDto) {
    // Suspending yourself locks the console with nobody inside it, and
    // demoting yourself is the same door closing more slowly.
    if (actorId === id) {
      throw new BadRequestException({
        code: 'CANNOT_ADMINISTER_SELF',
        message: 'Ask another administrator to change your own account',
      });
    }
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

    const before = await this.prisma.user.findUnique({
      where: { id },
      select: { role: true, disabledAt: true },
    });
    if (!before) throw new NotFoundException('User not found');

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

    await this.trace(
      actorId,
      dto.disabled === undefined ? 'user_role_changed' : 'user_access_changed',
      {
        user_id: id,
        reason: dto.reason ?? null,
        ...(dto.role && {
          role_from: before.role,
          role_to: dto.role,
        }),
        ...(dto.disabled !== undefined && {
          disabled_from: before.disabledAt !== null,
          disabled_to: dto.disabled,
        }),
      },
      // Granting a privileged role or locking an account out are the two
      // entries an incident review actually goes looking for.
      dto.disabled === true ||
        (dto.role !== undefined && PRIVILEGED_ROLES.includes(dto.role))
        ? AuditSeverity.WARNING
        : AuditSeverity.INFO,
    );

    return this.serializeAdminUser(user);
  }

  async updateProduct(
    actorId: string,
    id: string,
    dto: UpdateProductAdminDto,
  ) {
    const before = await this.prisma.product.findUnique({
      where: { id },
      select: { status: true, isFeatured: true, showInFeed: true },
    });
    if (!before) throw new NotFoundException('Product not found');

    const product = await this.prisma.product.update({
      where: { id },
      data: {
        ...(dto.status && { status: dto.status }),
        ...(dto.is_featured !== undefined && { isFeatured: dto.is_featured }),
        ...(dto.show_in_feed !== undefined && { showInFeed: dto.show_in_feed }),
      },
      include: PRODUCT_CARD_INCLUDE,
    });

    await this.trace(actorId, 'product_curated', {
      product_id: id,
      reason: dto.reason ?? null,
      ...(dto.status && { status_from: before.status, status_to: dto.status }),
      ...(dto.is_featured !== undefined && {
        featured_from: before.isFeatured,
        featured_to: dto.is_featured,
      }),
      ...(dto.show_in_feed !== undefined && {
        in_feed_from: before.showInFeed,
        in_feed_to: dto.show_in_feed,
      }),
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
      // The **real** book of record, not `FinancialLedgerEntry`.
      //
      // That table is a single-entry leftover, and only `CommissionsService`
      // still writes to it — so this screen, which calls itself "the last 50
      // financial movements", was showing commissions and nothing else. Every
      // wallet spend, refund, dispute hold, courier settlement, loyalty
      // accrual and payout was missing, and an operator reading it had no way
      // to tell that from a quiet day.
      //
      // Read from the journal instead: an entry with its lines, so a row can
      // say what moved and between which accounts.
      this.prisma.journalEntry.findMany({
        orderBy: { occurredAt: 'desc' },
        take: 50,
        include: {
          lines: {
            include: { account: { select: { code: true } } },
          },
        },
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
      ledger: ledger.map((entry) => {
        // A journal entry balances, so either side is its size; the debits
        // are the conventional one to report.
        const currency = entry.lines[0]?.currency ?? Currency.SYP;
        const amount = entry.lines
          .filter((line) => line.direction === LedgerDirection.DEBIT)
          .reduce(
            (total, line) => total.plus(Money.of(line.amount, line.currency)),
            Money.zero(currency),
          );

        return {
          id: entry.id,
          type: entry.type.toLowerCase(),
          amount: amount.toJSON(),
          currency,
          description: entry.description,
          // What the movement actually touched, which the old single-entry
          // row could not express at all.
          accounts: entry.lines.map((line) => ({
            code: line.account.code.toLowerCase(),
            direction: line.direction.toLowerCase(),
            amount: Money.of(line.amount, line.currency).toJSON(),
          })),
          /// Set when this entry undoes another, so a reversal never reads as
          /// a fresh movement on the operator's screen.
          reverses_id: entry.reversesId,
          order_id: entry.orderId,
          seller_order_id: entry.sellerOrderId,
          created_at: entry.occurredAt.toISOString(),
        };
      }),
    };
  }

  /**
   * The commission screen, as one list.
   *
   * Rules and ledger entries used to come back as two sibling arrays, and the
   * console — which renders one list per screen — showed whichever array it
   * found first and silently dropped the other. So the entries an operator
   * needs to mark paid were the half that never appeared. They are one list
   * now, each row saying which kind it is, and the settlement action offers
   * itself only on the ledger rows.
   */
  async commissions(query: AdminListQueryDto = new AdminListQueryDto()) {
    const ledgerStatus = statusIn(CommissionStatus, query.status);
    const ledgerWhere: Prisma.CommissionLedgerWhereInput = ledgerStatus
      ? { status: ledgerStatus }
      : {};

    const [rules, ledgers, ledgerCount, pendingAgg] = await Promise.all([
      this.prisma.commissionRule.findMany({ orderBy: { createdAt: 'desc' } }),
      this.prisma.commissionLedger.findMany({
        where: ledgerWhere,
        orderBy: { createdAt: 'desc' },
        skip: this.skip(query),
        take: query.limit,
      }),
      this.prisma.commissionLedger.count({ where: ledgerWhere }),
      this.prisma.commissionLedger.aggregate({
        _sum: { commission: true },
        where: { status: CommissionStatus.PENDING },
      }),
    ]);

    // Rules ride on the first page only; they are a short, stable list that an
    // operator reads once, not a queue she pages through.
    const ruleRows =
      query.page === 1
        ? rules.map((rule) => ({
            id: rule.id,
            kind: 'rule',
            name: rule.name,
            rate_bps: rule.rateBps,
            category: rule.category,
            seller_tier: rule.sellerTier,
            status: rule.active ? 'ACTIVE' : 'ARCHIVED',
          }))
        : [];

    const ledgerRows = ledgers.map((entry) => ({
      id: entry.id,
      kind: 'ledger',
      seller_id: entry.sellerId,
      gross: entry.gross,
      commission: entry.commission,
      net: entry.net,
      status: entry.status,
      created_at: entry.createdAt.toISOString(),
    }));

    // The rules ride along on page one, so they count toward the total too —
    // otherwise the console's "showing 8 of 68" describes eight rows of which
    // three are not in the sixty-eight.
    return {
      ...pageOf<Record<string, unknown>>(
        [...ruleRows, ...ledgerRows],
        ledgerCount + rules.length,
        query,
      ),
      pending_commission: (pendingAgg._sum.commission ?? 0).toString(),
      rules_count: rules.length,
    };
  }

  async createCommissionRule(actorId: string, dto: CreateCommissionRuleDto) {
    const rule = await this.prisma.commissionRule.create({
      data: {
        name: dto.name,
        rateBps: dto.rate_bps,
        category: dto.category,
        sellerTier: dto.seller_tier,
      },
    });
    await this.trace(
      actorId,
      'commission_rule_created',
      {
        rule_id: rule.id,
        name: rule.name,
        rate_bps: rule.rateBps,
        category: rule.category,
        seller_tier: rule.sellerTier,
      },
      AuditSeverity.WARNING,
    );
    return rule;
  }

  async updateCommissionLedger(
    actorId: string,
    id: string,
    dto: UpdateCommissionLedgerDto,
  ) {
    const before = await this.prisma.commissionLedger.findUnique({
      where: { id },
      select: { status: true, sellerId: true, commission: true },
    });
    if (!before) throw new NotFoundException('Commission entry not found');

    const entry = await this.prisma.commissionLedger.update({
      where: { id },
      data: {
        status: dto.status,
        ...(dto.status === CommissionStatus.PAID && { paidAt: new Date() }),
      },
    });
    await this.trace(
      actorId,
      'commission_ledger_updated',
      {
        ledger_id: id,
        seller_id: before.sellerId,
        commission: before.commission.toString(),
        status_from: before.status,
        status_to: dto.status,
      },
      // Marking commission paid is a money statement; it gets the same weight
      // as a settlement in the ledger's own trail.
      dto.status === CommissionStatus.PAID
        ? AuditSeverity.WARNING
        : AuditSeverity.INFO,
    );
    return entry;
  }

  async support(query: AdminListQueryDto = new AdminListQueryDto()) {
    const where: Prisma.SupportTicketWhereInput = {
      ...(statusIn(SupportTicketStatus, query.status) && {
        status: statusIn(SupportTicketStatus, query.status),
      }),
      ...(query.q && {
        OR: [
          { subject: { contains: query.q, mode: 'insensitive' } },
          { user: { name: { contains: query.q, mode: 'insensitive' } } },
          { user: { phone: { contains: query.q } } },
        ],
      }),
    };

    const [tickets, total, open] = await Promise.all([
      this.prisma.supportTicket.findMany({
        where,
        orderBy: [{ priority: 'desc' }, { updatedAt: 'desc' }],
        skip: this.skip(query),
        take: query.limit,
        include: { user: true, _count: { select: { messages: true } } },
      }),
      this.prisma.supportTicket.count({ where }),
      this.prisma.supportTicket.count({
        where: { status: { in: ['OPEN', 'PENDING'] } },
      }),
    ]);
    return { ...pageOf(tickets, total, query), open };
  }

  async updateSupportTicket(
    actorId: string,
    id: string,
    dto: UpdateSupportTicketDto,
  ) {
    const before = await this.prisma.supportTicket.findUnique({
      where: { id },
      select: { status: true, priority: true, userId: true },
    });
    if (!before) throw new NotFoundException('Support ticket not found');

    const ticket = await this.prisma.supportTicket.update({
      where: { id },
      data: {
        ...(dto.status && { status: dto.status }),
        ...(dto.priority && { priority: dto.priority }),
      },
    });
    await this.trace(actorId, 'support_ticket_updated', {
      ticket_id: id,
      subject_user_id: before.userId,
      ...(dto.status && { status_from: before.status, status_to: dto.status }),
      ...(dto.priority && {
        priority_from: before.priority,
        priority_to: dto.priority,
      }),
    });
    return ticket;
  }

  async moderation(query: AdminListQueryDto = new AdminListQueryDto()) {
    const where: Prisma.ModerationCaseWhereInput = {
      ...(statusIn(ModerationStatus, query.status) && {
        status: statusIn(ModerationStatus, query.status),
      }),
      ...(query.q && {
        OR: [
          { reason: { contains: query.q, mode: 'insensitive' } },
          { targetType: { contains: query.q, mode: 'insensitive' } },
        ],
      }),
    };

    const [cases, total, open] = await Promise.all([
      this.prisma.moderationCase.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: this.skip(query),
        take: query.limit,
      }),
      this.prisma.moderationCase.count({ where }),
      this.prisma.moderationCase.count({ where: { status: 'OPEN' } }),
    ]);
    return { ...pageOf(cases, total, query), open };
  }

  async updateModeration(
    actorId: string,
    id: string,
    dto: UpdateModerationCaseDto,
  ) {
    const before = await this.prisma.moderationCase.findUnique({
      where: { id },
      select: { status: true, targetType: true, targetId: true },
    });
    if (!before) throw new NotFoundException('Moderation case not found');

    const moderationCase = await this.prisma.moderationCase.update({
      where: { id },
      data: { status: dto.status, resolution: dto.resolution },
    });
    await this.trace(
      actorId,
      'moderation_case_decided',
      {
        case_id: id,
        target_type: before.targetType,
        target_id: before.targetId,
        status_from: before.status,
        status_to: dto.status,
        resolution: dto.resolution ?? null,
      },
      AuditSeverity.WARNING,
    );
    return moderationCase;
  }

  async reports(query: AdminListQueryDto = new AdminListQueryDto()) {
    const reportStatus = statusIn(ReportStatus, query.status);
    const where: Prisma.AdminReportWhereInput = reportStatus
      ? { status: reportStatus }
      : {};

    const [reports, total, open] = await Promise.all([
      this.prisma.adminReport.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: this.skip(query),
        take: query.limit,
      }),
      this.prisma.adminReport.count({ where }),
      this.prisma.adminReport.count({ where: { status: ReportStatus.OPEN } }),
    ]);
    return { ...pageOf(reports, total, query), open };
  }

  async updateReport(actorId: string, id: string, dto: UpdateReportDto) {
    const before = await this.prisma.adminReport.findUnique({
      where: { id },
      select: { status: true, type: true, title: true },
    });
    if (!before) throw new NotFoundException('Report not found');

    const report = await this.prisma.adminReport.update({
      where: { id },
      data: {
        status: dto.status,
        ...(dto.status === ReportStatus.RESOLVED && { resolvedAt: new Date() }),
      },
    });
    await this.trace(actorId, 'report_decided', {
      report_id: id,
      report_type: before.type,
      title: before.title,
      status_from: before.status,
      status_to: dto.status,
    });
    return report;
  }

  async auditLogs(query: AdminListQueryDto = new AdminListQueryDto()) {
    const where: Prisma.AuditLogWhereInput = query.q
      ? {
          OR: [
            { action: { contains: query.q, mode: 'insensitive' } },
            { category: { contains: query.q, mode: 'insensitive' } },
            { actor: { name: { contains: query.q, mode: 'insensitive' } } },
          ],
        }
      : {};

    const [logs, total] = await Promise.all([
      this.prisma.auditLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: this.skip(query),
        take: query.limit,
        include: { actor: true },
      }),
      this.prisma.auditLog.count({ where }),
    ]);
    return pageOf(
      logs.map((log) => ({
        id: log.id,
        action: log.action,
        category: log.category,
        outcome: log.outcome,
        severity: log.severity.toLowerCase(),
        actor_id: log.actorId,
        actor_name: log.actor?.name ?? null,
        ip_address: log.ipAddress,
        metadata: log.metadata,
        created_at: log.createdAt.toISOString(),
      })),
      total,
      query,
    );
  }

  async systemSettings() {
    const settings = await this.prisma.systemSetting.findMany({
      orderBy: { key: 'asc' },
    });
    return {
      items: settings.map((setting) => ({
        id: setting.id,
        key: setting.key,
        // A setting flagged sensitive holds a credential or a rate that is not
        // for every operator's screen. Listing it is fine; printing it is not.
        value: setting.sensitive ? null : setting.value,
        sensitive: setting.sensitive,
        updated_by: setting.updatedBy,
        updated_at: setting.updatedAt.toISOString(),
      })),
      total: settings.length,
    };
  }

  async upsertSystemSetting(actorId: string, dto: UpsertSystemSettingDto) {
    const before = await this.prisma.systemSetting.findUnique({
      where: { key: dto.key },
      select: { sensitive: true },
    });

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
    await this.trace(
      actorId,
      'system_setting_changed',
      {
        key: dto.key,
        created: before === null,
        // The value itself is deliberately absent for a sensitive key: the
        // audit log is read by more people than the setting is.
        ...(setting.sensitive ? {} : { value: setting.value }),
      },
      AuditSeverity.WARNING,
    );
    return setting;
  }

  async ensureProduct(id: string) {
    const product = await this.prisma.product.findUnique({ where: { id } });
    if (!product) throw new NotFoundException('Product not found');
    return product;
  }

  /**
   * `serializeUser` is the public shape — it is what a shopper sees on someone
   * else's profile, so it deliberately says nothing about suspension. The
   * console needs exactly that: without `disabled_at` the users screen cannot
   * tell an active account from a locked one, and the operator who just
   * suspended someone has no way to confirm it took.
   */
  private serializeAdminUser(user: Parameters<typeof serializeUser>[0] & {
    disabledAt?: Date | null;
    totpRequired?: boolean;
  }) {
    return {
      ...serializeUser(user),
      disabled_at: user.disabledAt?.toISOString() ?? null,
      is_disabled: user.disabledAt != null,
      totp_required: user.totpRequired ?? false,
    };
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
