import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  CommissionRule,
  CommissionStatus,
  FinancialLedgerType,
  OrderStatus,
  PayoutStatus,
  Prisma,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CommissionLedgerStatusDto,
  CommissionReportQueryDto,
  CommissionRuleDto,
  PayoutCalculationDto,
  PayoutStatusDto,
} from './dto/commission.dto';

const settleStatuses: OrderStatus[] = [
  OrderStatus.PAID,
  OrderStatus.PROCESSING,
  OrderStatus.SHIPPED,
  OrderStatus.DELIVERED,
];

@Injectable()
export class CommissionsService {
  constructor(private readonly prisma: PrismaService) {}

  async createRule(dto: CommissionRuleDto) {
    const rule = await this.prisma.commissionRule.create({
      data: {
        name: dto.name.trim(),
        rateBps: dto.rate_bps,
        platformFeeBps: dto.platform_fee_bps ?? 0,
        fixedFee: dto.fixed_fee ?? 0,
        minCommission: dto.min_commission,
        maxCommission: dto.max_commission,
        category: dto.category?.toLowerCase().trim() || null,
        sellerTier: dto.seller_tier?.trim() || null,
        priority: dto.priority ?? 100,
      },
    });
    return this.serializeRule(rule);
  }

  async rules() {
    const rules = await this.prisma.commissionRule.findMany({
      orderBy: [{ active: 'desc' }, { priority: 'asc' }, { createdAt: 'desc' }],
    });
    return rules.map((rule) => this.serializeRule(rule));
  }

  async settleOrder(orderId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: {
        items: {
          include: {
            product: {
              select: {
                sellerId: true,
                category: true,
                seller: { select: { tier: true } },
              },
            },
          },
        },
      },
    });
    if (!order) throw new NotFoundException('Order not found');
    if (!settleStatuses.includes(order.status)) {
      return { settled: 0, reason: 'Order is not revenue-bearing yet' };
    }

    const bySeller = new Map<
      string,
      {
        gross: number;
        commission: number;
        platformFee: number;
        ruleIds: Set<string>;
        lines: unknown[];
      }
    >();
    for (const item of order.items) {
      const gross = item.price * item.quantity;
      const rule = await this.ruleFor(
        item.product.category,
        item.product.seller.tier,
      );
      const commission = this.ruleCommission(gross, rule);
      const platformFee = this.round(
        gross * ((rule?.platformFeeBps ?? 0) / 10_000),
      );
      const row =
        bySeller.get(item.product.sellerId) ??
        { gross: 0, commission: 0, platformFee: 0, ruleIds: new Set(), lines: [] };
      row.gross += gross;
      row.commission += commission;
      row.platformFee += platformFee;
      if (rule) row.ruleIds.add(rule.id);
      row.lines.push({
        product_id: item.productId,
        quantity: item.quantity,
        gross: this.round(gross),
        category: item.product.category,
        rule_id: rule?.id ?? null,
      });
      bySeller.set(item.product.sellerId, row);
    }

    let settled = 0;
    for (const [sellerId, row] of bySeller.entries()) {
      const gross = this.round(row.gross);
      const commission = this.round(row.commission);
      const platformFee = this.round(row.platformFee);
      const net = this.round(gross - commission - platformFee);
      const ruleId = row.ruleIds.size === 1 ? [...row.ruleIds][0] : null;
      const existing = await this.prisma.commissionLedger.findUnique({
        where: { orderId_sellerId: { orderId, sellerId } },
      });
      const ledger = await this.prisma.commissionLedger.upsert({
        where: { orderId_sellerId: { orderId, sellerId } },
        update: {
          ruleId,
          gross,
          commission,
          platformFee,
          net,
          status:
            existing?.status === CommissionStatus.PAID
              ? CommissionStatus.PAID
              : CommissionStatus.EARNED,
          metadata: { lines: row.lines } as Prisma.InputJsonValue,
        },
        create: {
          ruleId,
          orderId,
          sellerId,
          gross,
          commission,
          platformFee,
          net,
          status: CommissionStatus.EARNED,
          metadata: { lines: row.lines } as Prisma.InputJsonValue,
        },
      });
      if (!existing) {
        await this.prisma.financialLedgerEntry.createMany({
          data: [
            {
              type: FinancialLedgerType.ORDER_REVENUE,
              orderId,
              sellerId,
              amount: gross,
              description: `Order revenue for seller ${sellerId}`,
              metadata: { ledger_id: ledger.id } as Prisma.InputJsonValue,
            },
            {
              type: FinancialLedgerType.COMMISSION,
              orderId,
              sellerId,
              amount: commission + platformFee,
              description: `Marketplace commission and platform fees`,
              metadata: { ledger_id: ledger.id } as Prisma.InputJsonValue,
            },
          ],
        });
      }
      settled += 1;
    }
    return { settled };
  }

  async reverseOrder(orderId: string, reason = 'Order refunded') {
    const ledgers = await this.prisma.commissionLedger.findMany({
      where: { orderId, status: { not: CommissionStatus.REVERSED } },
    });
    if (ledgers.length === 0) return { reversed: 0 };
    await this.prisma.$transaction(async (tx) => {
      for (const ledger of ledgers) {
        await tx.commissionLedger.update({
          where: { id: ledger.id },
          data: { status: CommissionStatus.REVERSED },
        });
        await tx.financialLedgerEntry.create({
          data: {
            type: FinancialLedgerType.REFUND,
            orderId,
            sellerId: ledger.sellerId,
            amount: -ledger.net,
            description: reason,
            metadata: { ledger_id: ledger.id } as Prisma.InputJsonValue,
          },
        });
      }
    });
    return { reversed: ledgers.length };
  }

  async sellerEarnings(sellerId: string) {
    await this.ensureSeller(sellerId);
    const [byStatus, paidPayout, pendingPayouts, recent] = await Promise.all([
      this.prisma.commissionLedger.groupBy({
        by: ['status'],
        where: { sellerId },
        _sum: { gross: true, commission: true, platformFee: true, net: true },
        _count: { _all: true },
      }),
      this.prisma.sellerPayout.aggregate({
        where: { sellerId, status: PayoutStatus.PAID },
        _sum: { net: true },
      }),
      this.prisma.sellerPayout.findMany({
        where: { sellerId, status: { in: [PayoutStatus.PENDING, PayoutStatus.APPROVED] } },
        orderBy: { createdAt: 'desc' },
        take: 5,
      }),
      this.prisma.commissionLedger.findMany({
        where: { sellerId },
        orderBy: { createdAt: 'desc' },
        take: 12,
      }),
    ]);
    const totals = this.statusTotals(byStatus);
    return {
      totals,
      lifetime_paid: this.round(paidPayout._sum.net ?? 0),
      pending_payouts: pendingPayouts.map((payout) => this.serializePayout(payout)),
      recent_transactions: recent.map((ledger) => this.serializeLedger(ledger)),
    };
  }

  async sellerTransactions(sellerId: string) {
    await this.ensureSeller(sellerId);
    const ledgers = await this.prisma.commissionLedger.findMany({
      where: { sellerId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return ledgers.map((ledger) => this.serializeLedger(ledger));
  }

  async adminReport(query: CommissionReportQueryDto) {
    const range = this.range(query);
    const where: Prisma.CommissionLedgerWhereInput = {
      ...(query.seller_id ? { sellerId: query.seller_id } : {}),
      createdAt: { gte: range.start, lte: range.end },
    };
    const [aggregate, byStatus, ledgers, payouts] = await Promise.all([
      this.prisma.commissionLedger.aggregate({
        where,
        _sum: { gross: true, commission: true, platformFee: true, net: true },
        _count: { _all: true },
      }),
      this.prisma.commissionLedger.groupBy({
        by: ['status'],
        where,
        _sum: { net: true },
        _count: { _all: true },
      }),
      this.prisma.commissionLedger.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: 100,
      }),
      this.prisma.sellerPayout.findMany({
        where: {
          ...(query.seller_id ? { sellerId: query.seller_id } : {}),
          createdAt: { gte: range.start, lte: range.end },
        },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
    ]);
    return {
      range: {
        start: range.start.toISOString(),
        end: range.end.toISOString(),
      },
      gross: this.round(aggregate._sum.gross ?? 0),
      commission: this.round(aggregate._sum.commission ?? 0),
      platform_fees: this.round(aggregate._sum.platformFee ?? 0),
      seller_net: this.round(aggregate._sum.net ?? 0),
      ledgers_count: aggregate._count._all,
      by_status: byStatus.map((row) => ({
        status: row.status.toLowerCase(),
        net: this.round(row._sum.net ?? 0),
        count: row._count._all,
      })),
      ledgers: ledgers.map((ledger) => this.serializeLedger(ledger)),
      payouts: payouts.map((payout) => this.serializePayout(payout)),
    };
  }

  async calculatePayout(dto: PayoutCalculationDto) {
    await this.ensureSeller(dto.seller_id);
    const start = new Date(dto.period_start);
    const end = new Date(dto.period_end);
    if (end <= start) throw new BadRequestException('Invalid payout date range');

    const ledgers = await this.prisma.commissionLedger.findMany({
      where: {
        sellerId: dto.seller_id,
        status: CommissionStatus.EARNED,
        createdAt: { gte: start, lte: end },
        payoutItems: { none: {} },
      },
    });
    if (ledgers.length === 0) {
      throw new BadRequestException('No earned commission ledgers available');
    }
    const gross = this.round(this.sum(ledgers.map((ledger) => ledger.gross)));
    const commission = this.round(this.sum(ledgers.map((ledger) => ledger.commission)));
    const platformFees = this.round(this.sum(ledgers.map((ledger) => ledger.platformFee)));
    const adjustments = this.round(dto.adjustments ?? 0);
    const net = this.round(this.sum(ledgers.map((ledger) => ledger.net)) + adjustments);
    const payout = await this.prisma.sellerPayout.create({
      data: {
        sellerId: dto.seller_id,
        periodStart: start,
        periodEnd: end,
        gross,
        commission,
        platformFees,
        adjustments,
        net,
        ledgers: {
          create: ledgers.map((ledger) => ({ ledgerId: ledger.id })),
        },
      },
    });
    return this.serializePayout(payout);
  }

  async updatePayoutStatus(id: string, dto: PayoutStatusDto) {
    const payout = await this.prisma.sellerPayout.findUnique({
      where: { id },
      include: { ledgers: true },
    });
    if (!payout) throw new NotFoundException('Payout not found');
    const now = new Date();
    const updated = await this.prisma.$transaction(async (tx) => {
      const record = await tx.sellerPayout.update({
        where: { id },
        data: {
          status: dto.status,
          reference: dto.reference ?? payout.reference,
          ...(dto.status === PayoutStatus.APPROVED && { approvedAt: now }),
          ...(dto.status === PayoutStatus.PAID && { paidAt: now }),
        },
      });
      if (dto.status === PayoutStatus.PAID) {
        await tx.commissionLedger.updateMany({
          where: { id: { in: payout.ledgers.map((item) => item.ledgerId) } },
          data: { status: CommissionStatus.PAID, paidAt: now },
        });
        await tx.financialLedgerEntry.create({
          data: {
            type: FinancialLedgerType.PAYOUT,
            sellerId: payout.sellerId,
            amount: -payout.net,
            description: `Seller payout ${dto.reference ?? payout.id}`,
            metadata: { payout_id: payout.id } as Prisma.InputJsonValue,
          },
        });
      }
      return record;
    });
    return this.serializePayout(updated);
  }

  async updateLedgerStatus(id: string, dto: CommissionLedgerStatusDto) {
    const ledger = await this.prisma.commissionLedger.update({
      where: { id },
      data: {
        status: dto.status,
        ...(dto.status === CommissionStatus.PAID && { paidAt: new Date() }),
      },
    });
    return this.serializeLedger(ledger);
  }

  private async ruleFor(category: string, sellerTier: string) {
    const now = new Date();
    const rules = await this.prisma.commissionRule.findMany({
      where: {
        active: true,
        startsAt: { lte: now },
        OR: [{ endsAt: null }, { endsAt: { gt: now } }],
        AND: [
          { OR: [{ category: null }, { category: category.toLowerCase() }] },
          { OR: [{ sellerTier: null }, { sellerTier }] },
        ],
      },
      orderBy: [{ priority: 'asc' }, { category: 'desc' }, { sellerTier: 'desc' }],
      take: 1,
    });
    return rules[0] ?? null;
  }

  private ruleCommission(gross: number, rule: CommissionRule | null) {
    const rate = rule?.rateBps ?? 1000;
    let commission = gross * (rate / 10_000) + (rule?.fixedFee ?? 0);
    if (rule?.minCommission !== null && rule?.minCommission !== undefined) {
      commission = Math.max(commission, rule.minCommission);
    }
    if (rule?.maxCommission !== null && rule?.maxCommission !== undefined) {
      commission = Math.min(commission, rule.maxCommission);
    }
    return this.round(commission);
  }

  private async ensureSeller(sellerId: string) {
    const seller = await this.prisma.user.findUnique({
      where: { id: sellerId },
      select: { id: true, role: true },
    });
    if (!seller || seller.role !== UserRole.SELLER) {
      throw new NotFoundException('Seller not found');
    }
  }

  private range(query: CommissionReportQueryDto) {
    const end = query.end ? new Date(query.end) : new Date();
    const start = query.start
      ? new Date(query.start)
      : new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);
    return { start, end };
  }

  private statusTotals(
    rows: {
      status: CommissionStatus;
      _sum: { gross: number | null; commission: number | null; platformFee: number | null; net: number | null };
      _count: { _all: number };
    }[],
  ) {
    return rows.reduce<Record<string, unknown>>((acc, row) => {
      acc[row.status.toLowerCase()] = {
        gross: this.round(row._sum.gross ?? 0),
        commission: this.round(row._sum.commission ?? 0),
        platform_fees: this.round(row._sum.platformFee ?? 0),
        net: this.round(row._sum.net ?? 0),
        count: row._count._all,
      };
      return acc;
    }, {});
  }

  private serializeRule(rule: CommissionRule) {
    return {
      id: rule.id,
      name: rule.name,
      rate_bps: rule.rateBps,
      platform_fee_bps: rule.platformFeeBps,
      fixed_fee: rule.fixedFee,
      min_commission: rule.minCommission,
      max_commission: rule.maxCommission,
      category: rule.category,
      seller_tier: rule.sellerTier,
      priority: rule.priority,
      active: rule.active,
      starts_at: rule.startsAt.toISOString(),
      ends_at: rule.endsAt?.toISOString() ?? null,
    };
  }

  private serializeLedger(ledger: {
    id: string;
    orderId: string | null;
    sellerId: string;
    gross: number;
    commission: number;
    platformFee: number;
    net: number;
    status: CommissionStatus;
    createdAt: Date;
    paidAt: Date | null;
  }) {
    return {
      id: ledger.id,
      order_id: ledger.orderId,
      seller_id: ledger.sellerId,
      gross: ledger.gross,
      commission: ledger.commission,
      platform_fee: ledger.platformFee,
      net: ledger.net,
      status: ledger.status.toLowerCase(),
      created_at: ledger.createdAt.toISOString(),
      paid_at: ledger.paidAt?.toISOString() ?? null,
    };
  }

  private serializePayout(payout: {
    id: string;
    sellerId: string;
    periodStart: Date;
    periodEnd: Date;
    gross: number;
    commission: number;
    platformFees: number;
    adjustments: number;
    net: number;
    currency: string;
    status: PayoutStatus;
    reference: string | null;
    createdAt: Date;
    approvedAt: Date | null;
    paidAt: Date | null;
  }) {
    return {
      id: payout.id,
      seller_id: payout.sellerId,
      period_start: payout.periodStart.toISOString(),
      period_end: payout.periodEnd.toISOString(),
      gross: payout.gross,
      commission: payout.commission,
      platform_fees: payout.platformFees,
      adjustments: payout.adjustments,
      net: payout.net,
      currency: payout.currency,
      status: payout.status.toLowerCase(),
      reference: payout.reference,
      created_at: payout.createdAt.toISOString(),
      approved_at: payout.approvedAt?.toISOString() ?? null,
      paid_at: payout.paidAt?.toISOString() ?? null,
    };
  }

  private sum(values: number[]) {
    return values.reduce((total, value) => total + value, 0);
  }

  private round(value: number) {
    return Math.round(value * 100) / 100;
  }
}
