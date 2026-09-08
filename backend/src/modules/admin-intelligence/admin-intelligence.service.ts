import { Injectable, Logger } from '@nestjs/common';
import {
  Currency,
  ProductStatus,
  TrustBand,
  TrustSignalStatus,
  UnmetDemandStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { EconomicsService } from '../analytics/economics.service';
import { SellerCrmService } from '../seller-commerce/seller-crm.service';
import { CatalogDuplicatesService } from '../products/catalog-duplicates.service';
import { Finding, MarketplaceFacts, findingsFor } from './kernel/findings';

const dayMs = 24 * 60 * 60 * 1000;

/** The window the briefing covers. A month — long enough to be a trend. */
export const BRIEFING_WINDOW_DAYS = 30;

/** Days of silence after which a boutique counts as quiet. */
const QUIET_SELLER_DAYS = 45;

/**
 * The morning briefing.
 *
 * Every number here is read from a system that already owns it — the trust
 * queue, the customer profiles, the economics report, the demand signals —
 * rather than recomputed. That is the whole point: a console that derives its
 * own version of the churn rate will eventually disagree with the churn
 * screen, and then nobody believes either.
 */
@Injectable()
export class AdminIntelligenceService {
  private readonly logger = new Logger(AdminIntelligenceService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly economics: EconomicsService,
    private readonly crm: SellerCrmService,
    private readonly duplicates: CatalogDuplicatesService,
  ) {}

  /**
   * What somebody should look at today, ordered by how much it matters.
   *
   * Returns an empty list on a quiet week, and says so. Padding it is how a
   * briefing stops being read.
   */
  async briefing(windowDays = BRIEFING_WINDOW_DAYS) {
    const facts = await this.gather(windowDays);
    const findings = findingsFor(facts);

    return {
      window_days: windowDays,
      generated_at: new Date().toISOString(),
      findings: findings.map((finding) => this.serialize(finding)),
      // Said explicitly rather than left as an empty array for a client to
      // interpret. "Nothing needs you today" is a useful thing to be told.
      quiet: findings.length === 0,
      facts,
    };
  }

  /** The raw counts, for a screen that wants the numbers without the advice. */
  async gather(windowDays = BRIEFING_WINDOW_DAYS): Promise<MarketplaceFacts> {
    const to = new Date();
    const from = new Date(to.getTime() - windowDays * dayMs);

    const [
      trust,
      churn,
      quiet,
      economics,
      unmet,
      duplicates,
      rising,
      stockouts,
    ] = await Promise.all([
      this.trustCounts(),
      this.churnCounts(),
      this.quietSellerCounts(),
      this.economics.overview({ from, to, currency: Currency.SYP }),
      this.unmetDemand(),
      this.duplicateCount(),
      this.risingProducts(),
      this.stockoutRisks(),
    ]);

    return {
      openTrustSignals: trust.open,
      suspectTrustSignals: trust.suspect,

      churningCustomers: churn.customers,
      churningValue: churn.value,

      quietSellers: quiet.sellers,
      quietSellerLifetimeOrders: quiet.orders,

      contributionMargin: Number(
        economics.platform.contribution_margin.amount,
      ),
      platformRevenue: Number(economics.platform.revenue.amount),
      gmv: Number(economics.volume.gmv_net.amount),
      takeRate: economics.platform.take_rate,

      unmetDemandTerms: unmet.terms,
      topUnmetTerm: unmet.top,
      topUnmetSearches: unmet.searches,

      duplicateCandidates: duplicates,

      risingProducts: rising.count,
      topRisingTitle: rising.top,

      stockoutRisks: stockouts,

      windowDays,
      currencyLabel: 'ل.س',
    };
  }

  // ── Each number, from the system that owns it ────────────────────────────

  private async trustCounts() {
    const [open, suspect] = await Promise.all([
      this.prisma.trustSignal.count({
        where: { status: TrustSignalStatus.OPEN },
      }),
      this.prisma.trustSignal.count({
        where: { status: TrustSignalStatus.OPEN, band: TrustBand.SUSPECT },
      }),
    ]);
    return { open, suspect };
  }

  /**
   * Customers past their own rhythm, and what their leaving would cost.
   *
   * Read from the cached profiles rather than recomputed — see the class note.
   * `leaving` and `gone` only: `watch` is a band to keep an eye on, not one to
   * spend a retention budget against.
   */
  private async churnCounts() {
    const rows = await this.prisma.customerProfile.aggregate({
      where: { churnBand: { in: ['leaving', 'gone'] } },
      _count: { _all: true },
      _sum: { projectedValue: true },
    });
    return {
      customers: rows._count._all,
      value: Number(rows._sum.projectedValue ?? 0),
    };
  }

  private async quietSellerCounts() {
    const rows = await this.crm.quietSellers({
      quietDays: QUIET_SELLER_DAYS,
      limit: 200,
    });
    return {
      sellers: rows.length,
      orders: rows.reduce((sum, row) => sum + row.lifetime_orders, 0),
    };
  }

  private async unmetDemand() {
    const rows = await this.prisma.unmetDemandSignal.findMany({
      where: { status: UnmetDemandStatus.OPEN, zeroResults: { gt: 0 } },
      orderBy: { demandScore: 'desc' },
      take: 50,
      select: { display: true, searches: true },
    });
    return {
      terms: rows.length,
      top: rows[0]?.display ?? null,
      searches: rows[0]?.searches ?? 0,
    };
  }

  private async duplicateCount() {
    const rows = await this.duplicates.candidates({ limit: 100, skip: 0 });
    return rows.length;
  }

  /**
   * Listings the ranking engine has put near the top that are also selling.
   *
   * Deliberately requires both: a high score on no sales is a listing the
   * engine likes, not a listing worth telling a buyer about.
   */
  private async risingProducts() {
    const rows = await this.prisma.product.findMany({
      where: {
        status: ProductStatus.ACTIVE,
        rankScore: { gte: 55 },
        recentOrders30: { gte: 3 },
      },
      orderBy: { rankScore: 'desc' },
      take: 50,
      select: { title: true },
    });
    return { count: rows.length, top: rows[0]?.title ?? null };
  }

  /** Selling well, and nearly out. */
  private async stockoutRisks() {
    return this.prisma.product.count({
      where: {
        status: ProductStatus.ACTIVE,
        recentOrders30: { gte: 3 },
        liveStock: { lte: 3, gt: 0 },
      },
    });
  }

  private serialize(finding: Finding) {
    return {
      code: finding.code,
      severity: finding.severity,
      title: finding.ar,
      action: finding.actionAr,
      href: finding.href,
      weight: finding.weight,
      evidence: finding.evidence,
    };
  }
}
