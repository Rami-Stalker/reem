import { Inject, Injectable, Logger, NotFoundException } from '@nestjs/common';
import {
  Prisma,
  TrendInsightAudience,
  TrendInsightStatus,
  TrendRunKind,
  TrendStage,
  TrendSubjectKind,
  TrendWindow,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { TrendRunRecorder } from '../collection/trend-run.recorder';
import { addDays, utcToday } from '../collection/day';
import {
  AttributeRuleInput,
  InsightFinding,
  attributeFindings,
  categoryFindings,
  productFindings,
  render,
  searchFindings,
  sellerFindings,
} from '../kernel/insight-rules';
import { TrendScoreMetrics, windowDays, windowEnum } from '../kernel/trend-score';
import { describeFacets, normaliseQuery } from '../kernel/query-normalizer';
import { clamp, median, round } from '../kernel/trend-math';
import {
  INSIGHT_TTL_DAYS,
  MAX_ADMIN_INSIGHTS,
  MAX_INSIGHTS_PER_SELLER,
  PLATFORM_SCOPE,
  TEMPLATE_NARRATOR,
  UNMET_DEMAND,
} from '../trend.constants';
import { PhrasingRequest, TREND_LLM, TrendLlm } from './llm/trend-llm';

/**
 * Layer 4: findings, in Arabic.
 *
 * The order of operations here is the design, and it does not change when a
 * model is configured:
 *
 *   scores → rules → findings → Arabic templates → (optionally) Claude → rows
 *
 * The templates run **before** the model, unconditionally, and their output is
 * passed to the model as the reference phrasing. So the row that reaches the
 * database always has correct Arabic in it; the model's contribution is to
 * make that Arabic better. A model that is slow, down, badly prompted or
 * having an off night costs the reader nothing but warmth.
 *
 * The other property worth naming is that the run is **quiet by design**. Each
 * rule carries a volume floor as well as a ratio test, and the writer keeps
 * only the top `MAX_INSIGHTS_PER_SELLER` by priority. A feed that produces
 * fifty rows a morning is a feed nobody reads, and an unread insight is worth
 * exactly as much as no insight.
 */
@Injectable()
export class TrendInsightsService {
  private readonly logger = new Logger(TrendInsightsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly runs: TrendRunRecorder,
    @Inject(TREND_LLM) private readonly llm: TrendLlm,
  ) {}

  /** Generate today's insights for everybody. */
  async generate(
    options: {
      generatedOn?: Date;
      window?: TrendWindow;
      triggeredBy?: string | null;
    } = {},
  ): Promise<{ admin: number; seller: number }> {
    const generatedOn = options.generatedOn ?? utcToday();
    const window = options.window ?? TrendWindow.D7;
    const run = await this.runs.start(TrendRunKind.INSIGHTS, {
      fromDay: generatedOn,
      toDay: generatedOn,
      triggeredBy: options.triggeredBy ?? null,
    });

    try {
      const findings: InsightFinding[] = [
        ...(await this.productFindings(generatedOn, window)),
        ...(await this.categoryFindings(generatedOn, window)),
        ...(await this.attributeFindings(generatedOn, window)),
        ...(await this.searchFindings(generatedOn)),
        ...(await this.sellerFindings(generatedOn, window)),
      ];

      const kept = this.prioritise(findings);
      const written = await this.write(kept, generatedOn);
      await this.expireStale(generatedOn);

      const admin = kept.filter(
        (f) => f.audience === TrendInsightAudience.ADMIN,
      ).length;
      await this.runs.succeed(run, written, {
        considered: findings.length,
        kept: kept.length,
        admin,
        seller: kept.length - admin,
        narrator: this.llm.enabled ? this.llm.name : TEMPLATE_NARRATOR,
      });
      return { admin, seller: kept.length - admin };
    } catch (error) {
      await this.runs.fail(run, error);
      throw error;
    }
  }

  // ── Rules over products ────────────────────────────────────────────────

  private async productFindings(
    generatedOn: Date,
    window: TrendWindow,
  ): Promise<InsightFinding[]> {
    const days = windowDays(window);
    const scores = await this.prisma.productTrendScore.findMany({
      where: { window, capturedOn: generatedOn },
      include: {
        product: {
          select: {
            id: true,
            title: true,
            categoryId: true,
            category: { select: { nameAr: true } },
          },
        },
      },
      // A run that touches ten thousand rows is a run that times out. The
      // leaderboard's head and its problem cases are where every finding is.
      orderBy: { score: 'desc' },
      take: 2000,
    });
    if (!scores.length) return [];

    const productIds = scores.map((row) => row.productId);

    // Category context: the median price and the peer conversion rate a
    // product is judged against. Computed from today's scores rather than
    // from a constant, so "behind its peers" means behind *these* peers.
    const peerRates = new Map<string, number[]>();
    const peerPrices = new Map<string, number[]>();
    for (const row of scores) {
      const metrics = row.metrics as unknown as TrendScoreMetrics | null;
      if (!metrics) continue;
      if (metrics.views >= 20) {
        const list = peerRates.get(row.categoryId) ?? [];
        list.push(metrics.viewToOrderRate);
        peerRates.set(row.categoryId, list);
      }
    }
    const categoryMedians = await this.prisma.categoryDemandDaily.findMany({
      where: { day: generatedOn, categoryId: { in: [...new Set(scores.map((s) => s.categoryId))] } },
      select: { categoryId: true, medianPriceSyp: true },
    });
    for (const row of categoryMedians) {
      if (row.medianPriceSyp === null) continue;
      peerPrices.set(row.categoryId, [Number(row.medianPriceSyp)]);
    }

    // Who to address. A product with exactly one live seller is hers to act
    // on; one with several is a merchandising matter, because no single seller
    // can be told to fix a page they share.
    //
    // Grouped in memory rather than with `groupBy(_min: sellerId)`, because
    // Postgres has no `min(uuid)` — that aggregate compiles happily in Prisma
    // and then fails at run time with `function min(uuid) does not exist`.
    const offers = await this.prisma.sellerOffer.findMany({
      where: { productId: { in: productIds }, isActive: true, status: 'ACTIVE' },
      select: { productId: true, sellerId: true },
    });
    const sellersByProduct = new Map<string, Set<string>>();
    for (const offer of offers) {
      const set = sellersByProduct.get(offer.productId) ?? new Set<string>();
      set.add(offer.sellerId);
      sellersByProduct.set(offer.productId, set);
    }
    const soleSeller = new Map<string, string | null>();
    for (const [productId, sellers] of sellersByProduct) {
      soleSeller.set(productId, sellers.size === 1 ? [...sellers][0] : null);
    }

    // Stock and price, from today's facts.
    const facts = await this.prisma.productDemandDaily.findMany({
      where: { day: generatedOn, productId: { in: productIds } },
      select: { productId: true, stockUnits: true, minPriceSyp: true },
    });
    const supply = new Map(
      facts.map((row) => [
        row.productId,
        {
          stockUnits: row.stockUnits,
          priceSyp: row.minPriceSyp === null ? null : Number(row.minPriceSyp),
        },
      ]),
    );

    // Forecasts, for the stock-out and spike rules.
    const forecasts = await this.prisma.trendForecast.findMany({
      where: {
        subjectKind: TrendSubjectKind.PRODUCT,
        subjectKey: { in: productIds },
        scopeKey: PLATFORM_SCOPE,
        horizonDays: 7,
        generatedOn: { gte: addDays(generatedOn, -7), lte: generatedOn },
      },
      orderBy: { generatedOn: 'asc' },
    });
    const forecastFor = new Map(forecasts.map((row) => [row.subjectKey, row]));

    const findings: InsightFinding[] = [];
    for (const row of scores) {
      const metrics = row.metrics as unknown as TrendScoreMetrics | null;
      if (!metrics) continue;
      const stock = supply.get(row.productId);
      const forecastRow = forecastFor.get(row.productId);
      const peers = peerRates.get(row.categoryId) ?? [];

      findings.push(
        ...productFindings({
          productId: row.productId,
          title: row.product.title,
          categoryId: row.categoryId,
          categoryNameAr: row.product.category?.nameAr ?? '',
          sellerId: soleSeller.get(row.productId) ?? null,
          windowDays: days,
          score: {
            score: row.score,
            stage: row.stage,
            confidence: row.confidence,
            sampleSize: row.sampleSize,
            components: {
              viewGrowth: row.viewGrowth,
              searchGrowth: row.searchGrowth,
              cartGrowth: row.cartGrowth,
              conversion: row.conversion,
              salesVelocity: row.salesVelocity,
              acceleration: row.acceleration,
              engagement: row.engagement,
              quality: row.quality,
              availability: row.availability,
            },
            metrics,
            method: row.method,
          },
          previousScore: row.previousScore,
          stockUnits: stock?.stockUnits ?? 0,
          priceSyp: stock?.priceSyp ?? null,
          categoryMedianPriceSyp: peerPrices.get(row.categoryId)?.[0] ?? null,
          peerViewToOrderRate: peers.length >= 3 ? median(peers) : null,
          forecast: forecastRow
            ? {
                horizonDays: forecastRow.horizonDays,
                totalUnits: forecastRow.totalUnits,
                confidence: forecastRow.confidence,
                stockoutInDays: forecastRow.stockoutInDays,
              }
            : null,
        }),
      );
    }
    return findings;
  }

  // ── Rules over categories ──────────────────────────────────────────────

  private async categoryFindings(
    generatedOn: Date,
    window: TrendWindow,
  ): Promise<InsightFinding[]> {
    const days = windowDays(window);
    const scores = await this.prisma.categoryTrendScore.findMany({
      where: { window, capturedOn: generatedOn },
      include: { category: { select: { nameAr: true } } },
    });
    if (!scores.length) return [];

    const facts = await this.prisma.categoryDemandDaily.findMany({
      where: {
        day: generatedOn,
        categoryId: { in: scores.map((row) => row.categoryId) },
      },
      select: { categoryId: true, liveProducts: true, inStockProducts: true },
    });
    const supply = new Map(facts.map((row) => [row.categoryId, row]));

    const findings: InsightFinding[] = [];
    for (const row of scores) {
      const metrics = row.metrics as unknown as TrendScoreMetrics | null;
      if (!metrics) continue;
      const shelf = supply.get(row.categoryId);
      findings.push(
        ...categoryFindings({
          categoryId: row.categoryId,
          nameAr: row.category?.nameAr ?? '',
          windowDays: days,
          score: {
            score: row.score,
            stage: row.stage,
            confidence: row.confidence,
            sampleSize: row.sampleSize,
            components: {
              viewGrowth: row.viewGrowth,
              searchGrowth: row.searchGrowth,
              cartGrowth: row.cartGrowth,
              conversion: row.conversion,
              salesVelocity: row.salesVelocity,
              acceleration: row.acceleration,
              engagement: row.engagement,
              quality: row.quality,
              availability: row.availability,
            },
            metrics,
            method: row.method,
          },
          previousScore: row.previousScore,
          liveProducts: shelf?.liveProducts ?? 0,
          inStockProducts: shelf?.inStockProducts ?? 0,
        }),
      );
    }
    return findings;
  }

  // ── Rules over colours and price bands ─────────────────────────────────

  private async attributeFindings(
    generatedOn: Date,
    window: TrendWindow,
  ): Promise<InsightFinding[]> {
    const days = windowDays(window);
    const currentFrom = addDays(generatedOn, -(days - 1));
    const previousFrom = addDays(currentFrom, -days);

    const [current, previous] = await Promise.all([
      this.attributeTotals(currentFrom, generatedOn),
      this.attributeTotals(previousFrom, addDays(currentFrom, -1)),
    ]);
    if (!current.size) return [];

    // Shares are taken within (dimension, scope), which is what makes a move
    // in black a statement about black rather than about a busy week.
    const denominators = new Map<string, number>();
    const previousDenominators = new Map<string, number>();
    for (const [, row] of current) {
      const key = `${row.dimension}:${row.scopeKey}`;
      denominators.set(key, (denominators.get(key) ?? 0) + row.demand);
    }
    for (const [, row] of previous) {
      const key = `${row.dimension}:${row.scopeKey}`;
      previousDenominators.set(key, (previousDenominators.get(key) ?? 0) + row.demand);
    }

    const scopeNames = await this.categoryNames(
      [...current.values()]
        .map((row) => row.scopeKey)
        .filter((key) => key !== PLATFORM_SCOPE),
    );

    const findings: InsightFinding[] = [];
    for (const [key, row] of current) {
      const before = previous.get(key);
      const denominatorKey = `${row.dimension}:${row.scopeKey}`;
      const total = denominators.get(denominatorKey) ?? 0;
      const previousTotal = previousDenominators.get(denominatorKey) ?? 0;

      const input: AttributeRuleInput = {
        dimension: row.dimension,
        value: row.value,
        labelAr: row.labelAr,
        scopeKey: row.scopeKey,
        scopeLabelAr:
          row.scopeKey === PLATFORM_SCOPE
            ? null
            : (scopeNames.get(row.scopeKey) ?? null),
        windowDays: days,
        current: row.demand,
        previous: before?.demand ?? 0,
        share: total > 0 ? row.demand / total : 0,
        previousShare:
          previousTotal > 0 ? (before?.demand ?? 0) / previousTotal : 0,
        orders: row.orders,
      };
      findings.push(...attributeFindings(input));
    }
    return findings;
  }

  private async attributeTotals(from: Date, to: Date) {
    const rows = await this.prisma.trendAttributeDaily.groupBy({
      by: ['dimension', 'value', 'scopeKey'],
      where: { day: { gte: from, lte: to } },
      _sum: { views: true, cartAdds: true, orders: true, units: true },
    });
    const labels = await this.prisma.trendAttributeDaily.findMany({
      where: { day: { gte: from, lte: to } },
      select: { dimension: true, value: true, scopeKey: true, labelAr: true },
      distinct: ['dimension', 'value', 'scopeKey'],
    });
    const labelFor = new Map(
      labels.map((row) => [
        `${row.dimension}:${row.value}:${row.scopeKey}`,
        row.labelAr,
      ]),
    );

    return new Map(
      rows.map((row) => {
        const key = `${row.dimension}:${row.value}:${row.scopeKey}`;
        return [
          key,
          {
            dimension: row.dimension,
            value: row.value,
            scopeKey: row.scopeKey,
            labelAr: labelFor.get(key) ?? row.value,
            // "Demand" for a facet is attention plus intent: views alone
            // follow whatever the home page featured this week.
            demand:
              (row._sum.views ?? 0) + (row._sum.cartAdds ?? 0) * 5,
            orders: row._sum.orders ?? 0,
            units: row._sum.units ?? 0,
          },
        ];
      }),
    );
  }

  // ── Rules over searches ────────────────────────────────────────────────

  private async searchFindings(generatedOn: Date): Promise<InsightFinding[]> {
    const window = UNMET_DEMAND.window;
    const currentFrom = addDays(generatedOn, -(window - 1));
    const previousFrom = addDays(currentFrom, -window);

    const [current, previous] = await Promise.all([
      this.searchTotals(currentFrom, generatedOn),
      this.searchTotals(previousFrom, addDays(currentFrom, -1)),
    ]);
    if (!current.size) return [];

    const signals = await this.prisma.unmetDemandSignal.findMany({
      where: { termKey: { in: [...current.keys()] } },
      select: {
        termKey: true,
        demandScore: true,
        suggestedCategoryId: true,
        status: true,
      },
    });
    const signalFor = new Map(signals.map((row) => [row.termKey, row]));

    const findings: InsightFinding[] = [];
    for (const [termKey, row] of current) {
      const signal = signalFor.get(termKey);
      // A gap a buyer has already dismissed should not come back every night.
      if (signal?.status === 'DISMISSED' || signal?.status === 'ADDRESSED') {
        continue;
      }
      const facets = normaliseQuery(row.display).facets;
      findings.push(
        ...searchFindings({
          termKey,
          display: row.display,
          facetSummary: describeFacets(facets),
          windowDays: window,
          searches: row.searches,
          previousSearches: previous.get(termKey)?.searches ?? 0,
          zeroResults: row.zeroResults,
          missRate: row.searches > 0 ? row.zeroResults / row.searches : 0,
          clicks: row.clicks,
          orders: row.orders,
          demandScore: signal?.demandScore ?? 0,
          suggestedCategoryId: signal?.suggestedCategoryId ?? null,
        }),
      );
    }
    return findings;
  }

  private async searchTotals(from: Date, to: Date) {
    const rows = await this.prisma.searchTermDaily.groupBy({
      by: ['termKey'],
      where: { day: { gte: from, lte: to } },
      _sum: { searches: true, zeroResults: true, clicks: true, orders: true },
    });
    const displays = await this.prisma.searchTermDaily.findMany({
      where: { day: { gte: from, lte: to } },
      select: { termKey: true, display: true },
      distinct: ['termKey'],
      orderBy: { day: 'desc' },
    });
    const displayFor = new Map(displays.map((row) => [row.termKey, row.display]));

    return new Map(
      rows.map((row) => [
        row.termKey,
        {
          display: displayFor.get(row.termKey) ?? row.termKey,
          searches: row._sum.searches ?? 0,
          zeroResults: row._sum.zeroResults ?? 0,
          clicks: row._sum.clicks ?? 0,
          orders: row._sum.orders ?? 0,
        },
      ]),
    );
  }

  // ── Rules over sellers ─────────────────────────────────────────────────

  private async sellerFindings(
    generatedOn: Date,
    window: TrendWindow,
  ): Promise<InsightFinding[]> {
    const days = windowDays(window);
    const currentFrom = addDays(generatedOn, -(days - 1));
    const previousFrom = addDays(currentFrom, -days);

    const [current, previous] = await Promise.all([
      this.sellerTotals(currentFrom, generatedOn),
      this.sellerTotals(previousFrom, addDays(currentFrom, -1)),
    ]);
    if (!current.size) return [];

    const stages = await this.prisma.$queryRaw<
      Array<{ seller_id: string; stage: TrendStage; count: bigint }>
    >`
      SELECT s.seller_id, p.stage, COUNT(DISTINCT p.product_id) AS count
      FROM product_trend_scores p
      JOIN (
        SELECT DISTINCT seller_id, product_id
        FROM seller_demand_daily
        WHERE day >= ${currentFrom} AND day <= ${generatedOn}
      ) s ON s.product_id = p.product_id
      WHERE p."window" = ${window}::"TrendWindow" AND p.captured_on = ${generatedOn}
      GROUP BY s.seller_id, p.stage
    `;
    const rising = new Map<string, number>();
    const declining = new Map<string, number>();
    for (const row of stages) {
      const count = Number(row.count);
      if (row.stage === TrendStage.RISING || row.stage === TrendStage.EMERGING) {
        rising.set(row.seller_id, (rising.get(row.seller_id) ?? 0) + count);
      }
      if (row.stage === TrendStage.DECLINING || row.stage === TrendStage.COOLING) {
        declining.set(row.seller_id, (declining.get(row.seller_id) ?? 0) + count);
      }
    }

    const names = await this.prisma.user.findMany({
      where: { id: { in: [...current.keys()] } },
      select: { id: true, name: true },
    });
    const nameFor = new Map(names.map((row) => [row.id, row.name]));

    const findings: InsightFinding[] = [];
    for (const [sellerId, row] of current) {
      const before = previous.get(sellerId);
      const settled = row.units + row.cancels;
      findings.push(
        ...sellerFindings({
          sellerId,
          displayName: nameFor.get(sellerId) ?? 'بائعة',
          windowDays: days,
          units: row.units,
          previousUnits: before?.units ?? 0,
          revenueSyp: row.revenueSyp,
          previousRevenueSyp: before?.revenueSyp ?? 0,
          cancelRate: settled > 0 ? row.cancels / settled : 0,
          returnRate: row.units > 0 ? row.returns / row.units : 0,
          risingProducts: rising.get(sellerId) ?? 0,
          decliningProducts: declining.get(sellerId) ?? 0,
        }),
      );
    }
    return findings;
  }

  private async sellerTotals(from: Date, to: Date) {
    const rows = await this.prisma.sellerDemandDaily.groupBy({
      by: ['sellerId'],
      where: { day: { gte: from, lte: to } },
      _sum: {
        units: true,
        revenueSyp: true,
        cancels: true,
        returns: true,
      },
    });
    return new Map(
      rows.map((row) => [
        row.sellerId,
        {
          units: row._sum.units ?? 0,
          revenueSyp: Number(row._sum.revenueSyp ?? 0),
          cancels: row._sum.cancels ?? 0,
          returns: row._sum.returns ?? 0,
        },
      ]),
    );
  }

  // ── Prioritise, phrase, write ──────────────────────────────────────────

  /**
   * Keep the ones worth reading.
   *
   * Per-seller and platform-wide caps, highest priority first. This is the
   * difference between a feature people use and a notification bell they turn
   * off in week two.
   */
  private prioritise(findings: readonly InsightFinding[]): InsightFinding[] {
    const sorted = [...findings].sort((a, b) => b.priority - a.priority);
    const perSeller = new Map<string, number>();
    let adminCount = 0;
    const kept: InsightFinding[] = [];

    for (const finding of sorted) {
      if (finding.audience === TrendInsightAudience.SELLER && finding.sellerId) {
        const used = perSeller.get(finding.sellerId) ?? 0;
        if (used >= MAX_INSIGHTS_PER_SELLER) continue;
        perSeller.set(finding.sellerId, used + 1);
      } else {
        if (adminCount >= MAX_ADMIN_INSIGHTS) continue;
        adminCount += 1;
      }
      kept.push(finding);
    }
    return kept;
  }

  private async write(
    findings: readonly InsightFinding[],
    generatedOn: Date,
  ): Promise<number> {
    if (!findings.length) return 0;

    // Templates first, always. Everything after this point is an improvement
    // on text that is already correct and already shippable.
    const rendered = new Map(
      findings.map((finding) => [finding.dedupeKey, render(finding)]),
    );

    let narrator = TEMPLATE_NARRATOR;
    let phrased = new Map<string, { titleAr: string; bodyAr: string; actionAr: string | null }>();
    if (this.llm.enabled) {
      const requests: PhrasingRequest[] = findings.map((finding) => ({
        dedupeKey: finding.dedupeKey,
        kind: finding.kind,
        severity: finding.severity,
        subjectLabel: finding.subjectLabel,
        metrics: finding.metrics,
        fallback: rendered.get(finding.dedupeKey)!,
        audience:
          finding.audience === TrendInsightAudience.SELLER ? 'SELLER' : 'ADMIN',
      }));
      phrased = await this.llm.phrase(requests);
      if (phrased.size) narrator = this.llm.name;
    }

    const expiresAt = addDays(generatedOn, INSIGHT_TTL_DAYS);
    let written = 0;

    for (const finding of findings) {
      const template = rendered.get(finding.dedupeKey)!;
      const model = phrased.get(finding.dedupeKey);
      const copy = model ?? template;

      const data = {
        audience: finding.audience,
        sellerId: finding.sellerId ?? null,
        kind: finding.kind,
        severity: finding.severity,
        subjectKind: finding.subjectKind,
        subjectKey: finding.subjectKey,
        productId: finding.productId ?? null,
        categoryId: finding.categoryId ?? null,
        titleAr: copy.titleAr,
        bodyAr: copy.bodyAr,
        actionAr: copy.actionAr,
        actionTarget: finding.actionTarget ?? null,
        metrics: finding.metrics as unknown as Prisma.InputJsonValue,
        confidence: round(clamp(finding.confidence), 4),
        priority: finding.priority,
        // Per row, not per run: a row the model skipped is honestly a template.
        narrator: model ? narrator : TEMPLATE_NARRATOR,
        expiresAt,
      };

      await this.prisma.trendInsight.upsert({
        where: {
          dedupeKey_generatedOn: {
            dedupeKey: finding.dedupeKey,
            generatedOn,
          },
        },
        // A refresh must not silently reopen something a seller dismissed this
        // morning, so `status` is only set on insert.
        create: { ...data, dedupeKey: finding.dedupeKey, generatedOn },
        update: data,
      });
      written += 1;
    }
    return written;
  }

  /** Close out anything past its shelf life. */
  private async expireStale(generatedOn: Date): Promise<number> {
    const result = await this.prisma.trendInsight.updateMany({
      where: {
        status: { in: [TrendInsightStatus.OPEN, TrendInsightStatus.ACKNOWLEDGED] },
        expiresAt: { lt: generatedOn },
      },
      data: { status: TrendInsightStatus.EXPIRED },
    });
    return result.count;
  }

  // ── Read side ──────────────────────────────────────────────────────────

  async feed(options: {
    audience: TrendInsightAudience;
    sellerId?: string | null;
    statuses?: TrendInsightStatus[];
    kinds?: string[];
    limit?: number;
    offset?: number;
  }) {
    const where: Prisma.TrendInsightWhereInput = {
      audience: options.audience,
      status: {
        in: options.statuses ?? [
          TrendInsightStatus.OPEN,
          TrendInsightStatus.ACKNOWLEDGED,
        ],
      },
      expiresAt: { gte: new Date() },
      ...(options.audience === TrendInsightAudience.SELLER
        ? { sellerId: options.sellerId ?? '' }
        : {}),
      ...(options.kinds?.length
        ? { kind: { in: options.kinds as never[] } }
        : {}),
    };

    const take = Math.min(Math.max(options.limit ?? 25, 1), 100);
    const [rows, total] = await Promise.all([
      this.prisma.trendInsight.findMany({
        where,
        orderBy: [{ priority: 'desc' }, { generatedOn: 'desc' }],
        skip: Math.max(options.offset ?? 0, 0),
        take,
        include: {
          product: { select: { id: true, title: true, slug: true } },
          category: { select: { id: true, nameAr: true, slug: true } },
        },
      }),
      this.prisma.trendInsight.count({ where }),
    ]);
    return { rows, total };
  }

  /**
   * A reader acts on an insight.
   *
   * Scoped: a seller may only touch her own rows, and the check is a `where`
   * clause rather than a fetch-then-compare, so there is no window in which
   * the wrong row is loaded.
   */
  async updateStatus(
    id: string,
    status: TrendInsightStatus,
    actor: { id: string; sellerId?: string | null },
  ) {
    const existing = await this.prisma.trendInsight.findFirst({
      where: {
        id,
        ...(actor.sellerId ? { sellerId: actor.sellerId } : {}),
      },
    });
    if (!existing) throw new NotFoundException('Insight not found');

    return this.prisma.trendInsight.update({
      where: { id },
      data: {
        status,
        acknowledgedAt: new Date(),
        acknowledgedBy: actor.id,
      },
      include: {
        product: { select: { id: true, title: true, slug: true } },
        category: { select: { id: true, nameAr: true, slug: true } },
      },
    });
  }

  private async categoryNames(ids: readonly string[]): Promise<Map<string, string>> {
    const unique = [...new Set(ids)];
    if (!unique.length) return new Map();
    const rows = await this.prisma.category.findMany({
      where: { id: { in: unique } },
      select: { id: true, nameAr: true },
    });
    return new Map(rows.map((row) => [row.id, row.nameAr]));
  }
}

export { windowEnum };
