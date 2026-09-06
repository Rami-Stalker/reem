import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import {
  Prisma,
  ProductStatus,
  TrendRunKind,
  UnmetDemandStatus,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { TrendRunRecorder } from '../collection/trend-run.recorder';
import { addDays, utcToday } from '../collection/day';
import { clamp, logGrowth, round, saturate } from '../kernel/trend-math';
import {
  QueryFacets,
  describeFacets,
  facetsAreActionable,
  normaliseQuery,
} from '../kernel/query-normalizer';
import { UNMET_DEMAND } from '../trend.constants';

/**
 * Search Intelligence: what she asked for, and whether the catalogue could
 * answer.
 *
 * The valuable half of a search log is not the searches that worked. It is the
 * ones that did not — the woman who typed «فستان سهرة أخضر طويل», scrolled
 * past nothing, and left. That search is the clearest purchase intent the
 * platform will ever see, and today it produces no order, no signal and no
 * record that anyone wanted it.
 *
 * Two kinds of miss are detected, and they are genuinely different:
 *
 *  - **Nothing came back.** `zeroResults / searches` above the threshold. The
 *    assortment has a hole in it.
 *  - **Something came back and nobody wanted it.** High volume, results
 *    returned, click-through near zero. This is the harder one and the more
 *    interesting: the catalogue *thinks* it has an answer, and she disagrees.
 *
 * The output is not a list of strings. It is a facet set — a garment, an
 * occasion, a colour, a price band — resolved to a category, which is what
 * makes it a buying instruction rather than a curiosity.
 */
@Injectable()
export class SearchIntelligenceService {
  private readonly logger = new Logger(SearchIntelligenceService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly runs: TrendRunRecorder,
  ) {}

  /**
   * Refresh every unmet-demand signal from the rolling window.
   *
   * Recomputes the whole set rather than appending, so a gap that has since
   * been filled stops being reported — a buyer who sources the green evening
   * dresses should see the row's demand score fall on its own, not have to
   * remember to close it.
   */
  async refresh(
    options: { asOf?: Date; triggeredBy?: string | null } = {},
  ): Promise<{ signals: number; resolved: number }> {
    const asOf = options.asOf ?? utcToday();
    const run = await this.runs.start(TrendRunKind.SEARCH_INTELLIGENCE, {
      fromDay: addDays(asOf, -UNMET_DEMAND.window),
      toDay: asOf,
      triggeredBy: options.triggeredBy ?? null,
    });

    try {
      const window = UNMET_DEMAND.window;
      const currentFrom = addDays(asOf, -(window - 1));
      const previousFrom = addDays(currentFrom, -window);

      const [current, previous] = await Promise.all([
        this.aggregate(currentFrom, asOf),
        this.aggregate(previousFrom, addDays(currentFrom, -1)),
      ]);

      const slugToCategory = await this.categorySlugIndex();

      let signals = 0;
      const seen = new Set<string>();

      for (const [termKey, row] of current) {
        const missRate = row.searches > 0 ? row.zeroResults / row.searches : 0;
        const clickRate = row.searches > 0 ? row.clicks / row.searches : 0;

        const emptyShelf =
          row.searches >= UNMET_DEMAND.minSearches &&
          missRate >= UNMET_DEMAND.minMissRate;
        // The subtler miss: results existed and she wanted none of them.
        const wrongShelf =
          row.searches >= UNMET_DEMAND.minSearchesForWeakClick &&
          clickRate <= UNMET_DEMAND.weakClickRate &&
          row.orders === 0;

        if (!emptyShelf && !wrongShelf) continue;

        const facets = normaliseQuery(row.display).facets;
        const previousSearches = previous.get(termKey)?.searches ?? 0;
        const growth = round(logGrowth(row.searches, previousSearches), 4);
        const demandScore = this.demandScore({
          searches: row.searches,
          missRate: emptyShelf ? missRate : 1 - clickRate,
          growth,
          actionable: facetsAreActionable(facets),
        });

        const categoryId = this.resolveCategory(facets, slugToCategory);
        const data = {
          display: row.display,
          facets: facets as unknown as Prisma.InputJsonValue,
          searches: row.searches,
          zeroResults: row.zeroResults,
          clicks: row.clicks,
          orders: row.orders,
          missRate: round(missRate, 4),
          demandScore,
          growth,
          suggestedCategoryId: categoryId,
          suggestionAr: this.suggestion(row.display, facets, emptyShelf),
          lastSeenAt: new Date(),
        };

        await this.prisma.unmetDemandSignal.upsert({
          where: { termKey },
          create: { termKey, ...data },
          update: data,
        });
        seen.add(termKey);
        signals += 1;
      }

      // A signal that no longer clears the bar is closed as addressed rather
      // than deleted: the history of what the assortment was missing is worth
      // keeping, and a buyer wants to see that her sourcing worked.
      const resolved = await this.prisma.unmetDemandSignal.updateMany({
        where: {
          status: { in: [UnmetDemandStatus.OPEN, UnmetDemandStatus.ACKNOWLEDGED, UnmetDemandStatus.SOURCING] },
          termKey: { notIn: [...seen] },
          lastSeenAt: { lt: addDays(asOf, -window) },
        },
        data: { status: UnmetDemandStatus.ADDRESSED, demandScore: 0 },
      });

      await this.runs.succeed(run, signals, {
        signals,
        resolved: resolved.count,
      });
      return { signals, resolved: resolved.count };
    } catch (error) {
      await this.runs.fail(run, error);
      throw error;
    }
  }

  // ── Read side ──────────────────────────────────────────────────────────

  /** Rising search terms, whether or not the catalogue can answer them. */
  async topTerms(options: { windowDays?: number; limit?: number } = {}) {
    const asOf = utcToday();
    const window = options.windowDays ?? 30;
    const currentFrom = addDays(asOf, -(window - 1));
    const previousFrom = addDays(currentFrom, -window);

    const [current, previous] = await Promise.all([
      this.aggregate(currentFrom, asOf),
      this.aggregate(previousFrom, addDays(currentFrom, -1)),
    ]);

    const rows = [...current.entries()].map(([termKey, row]) => {
      const previousSearches = previous.get(termKey)?.searches ?? 0;
      const facets = normaliseQuery(row.display).facets;
      return {
        termKey,
        display: row.display,
        facetSummary: describeFacets(facets),
        searches: row.searches,
        previousSearches,
        growth: round(logGrowth(row.searches, previousSearches), 4),
        zeroResults: row.zeroResults,
        missRate: row.searches > 0 ? round(row.zeroResults / row.searches, 4) : 0,
        averageResults:
          row.searches > 0 ? round(row.resultsSum / row.searches, 2) : 0,
        clicks: row.clicks,
        clickRate: row.searches > 0 ? round(row.clicks / row.searches, 4) : 0,
        orders: row.orders,
        windowDays: window,
      };
    });

    rows.sort((a, b) => b.searches - a.searches);
    return rows.slice(0, Math.min(Math.max(options.limit ?? 50, 1), 200));
  }

  /** Rising terms — sorted by growth rather than volume, with a volume floor. */
  async risingTerms(options: { windowDays?: number; limit?: number } = {}) {
    const terms = await this.topTerms({
      windowDays: options.windowDays,
      limit: 200,
    });
    return terms
      .filter((term) => term.searches >= 5)
      .sort((a, b) => b.growth - a.growth)
      .slice(0, Math.min(Math.max(options.limit ?? 20, 1), 100));
  }

  async unmetDemand(options: {
    status?: UnmetDemandStatus;
    limit?: number;
    offset?: number;
  } = {}) {
    const where: Prisma.UnmetDemandSignalWhereInput = options.status
      ? { status: options.status }
      : {
          status: {
            in: [
              UnmetDemandStatus.OPEN,
              UnmetDemandStatus.ACKNOWLEDGED,
              UnmetDemandStatus.SOURCING,
            ],
          },
        };
    const take = Math.min(Math.max(options.limit ?? 50, 1), 200);
    const [rows, total] = await Promise.all([
      this.prisma.unmetDemandSignal.findMany({
        where,
        orderBy: { demandScore: 'desc' },
        skip: Math.max(options.offset ?? 0, 0),
        take,
        include: { suggestedCategory: true },
      }),
      this.prisma.unmetDemandSignal.count({ where }),
    ]);
    return { rows, total };
  }

  /** A buyer moves a signal along her own workflow. */
  async review(
    id: string,
    input: { status: UnmetDemandStatus; note?: string | null },
    reviewerId: string,
  ) {
    const existing = await this.prisma.unmetDemandSignal.findUnique({
      where: { id },
    });
    if (!existing) throw new NotFoundException('Unmet demand signal not found');

    return this.prisma.unmetDemandSignal.update({
      where: { id },
      data: {
        status: input.status,
        note: input.note ?? existing.note,
        reviewedBy: reviewerId,
        reviewedAt: new Date(),
      },
      include: { suggestedCategory: true },
    });
  }

  // ── Internals ──────────────────────────────────────────────────────────

  private async aggregate(from: Date, to: Date) {
    const rows = await this.prisma.searchTermDaily.groupBy({
      by: ['termKey'],
      where: { day: { gte: from, lte: to } },
      _sum: {
        searches: true,
        zeroResults: true,
        resultsSum: true,
        clicks: true,
        orders: true,
      },
    });
    if (!rows.length) {
      return new Map<
        string,
        {
          display: string;
          searches: number;
          zeroResults: number;
          resultsSum: number;
          clicks: number;
          orders: number;
        }
      >();
    }

    // The display spelling comes from the most recent day the term appeared,
    // so a term that changes how it is usually typed follows along.
    const latest = await this.prisma.searchTermDaily.findMany({
      where: { day: { gte: from, lte: to }, termKey: { in: rows.map((r) => r.termKey) } },
      select: { termKey: true, display: true, day: true },
      orderBy: { day: 'asc' },
    });
    const displays = new Map<string, string>();
    for (const row of latest) displays.set(row.termKey, row.display);

    return new Map(
      rows.map((row) => [
        row.termKey,
        {
          display: displays.get(row.termKey) ?? row.termKey,
          searches: row._sum.searches ?? 0,
          zeroResults: row._sum.zeroResults ?? 0,
          resultsSum: row._sum.resultsSum ?? 0,
          clicks: row._sum.clicks ?? 0,
          orders: row._sum.orders ?? 0,
        },
      ]),
    );
  }

  /**
   * 0–100. Volume × miss × growth, with a penalty for a term nobody can act
   * on yet.
   *
   * Volume saturates rather than scaling: the difference between forty
   * searches and eighty is real, the difference between four hundred and eight
   * hundred is not a different decision. Miss rate is the multiplier because a
   * heavily-searched term the catalogue *does* answer is not a gap, however
   * popular. Growth is a modest bonus rather than a factor — a small, steady,
   * completely unmet demand is still worth sourcing.
   */
  private demandScore(input: {
    searches: number;
    missRate: number;
    growth: number;
    actionable: boolean;
  }): number {
    const volume = saturate(input.searches, 40);
    const miss = clamp(input.missRate);
    const momentum = 1 + clamp(input.growth / Math.log(4)) * 0.5;
    // A term with no recognised facets is real demand nobody can source
    // against yet, so it is reported — below the ones that can be.
    const actionability = input.actionable ? 1 : 0.6;
    return round(clamp(volume * miss * momentum * actionability) * 100, 2);
  }

  private async categorySlugIndex(): Promise<Map<string, string>> {
    const rows = await this.prisma.category.findMany({
      where: { isActive: true },
      select: { id: true, slug: true },
    });
    return new Map(rows.map((row) => [row.slug, row.id]));
  }

  private resolveCategory(
    facets: QueryFacets,
    slugToCategory: Map<string, string>,
  ): string | null {
    for (const slug of facets.categorySlugs) {
      const id = slugToCategory.get(slug);
      if (id) return id;
    }
    return null;
  }

  /**
   * The sentence the buying team reads.
   *
   * Written from the facets rather than the raw query, so it reads as a
   * specification — "فساتين · سهرة · أخضر" — instead of quoting somebody's
   * typing back at them. The two shapes are genuinely different findings and
   * are worded differently: an empty shelf is a sourcing job, a full shelf
   * nobody wants is a merchandising one.
   */
  private suggestion(
    display: string,
    facets: QueryFacets,
    emptyShelf: boolean,
  ): string {
    const summary = describeFacets(facets);
    if (emptyShelf) {
      return summary
        ? `طلب واضح على ${summary} ولا توجد نتائج مناسبة في التشكيلة الحالية.`
        : `طلب متكرر على «${display}» دون نتائج مناسبة.`;
    }
    return summary
      ? `تظهر نتائج لـ${summary} لكن العميلات لا يفتحن أيًّا منها — التشكيلة موجودة والمعروض لا يناسب الطلب.`
      : `«${display}» يُبحث عنه كثيرًا وتُتجاهل نتائجه.`;
  }

  /**
   * Products that would answer a term today, for the "is this really unmet?"
   * check a buyer makes before sourcing anything.
   */
  async matchesFor(termKey: string, limit = 12) {
    const signal = await this.prisma.unmetDemandSignal.findUnique({
      where: { termKey },
    });
    if (!signal) throw new NotFoundException('Unmet demand signal not found');

    const facets = normaliseQuery(signal.display).facets;
    const where: Prisma.ProductWhereInput = {
      status: ProductStatus.ACTIVE,
      ...(signal.suggestedCategoryId
        ? { categoryId: signal.suggestedCategoryId }
        : {}),
    };

    const products = await this.prisma.product.findMany({
      where,
      orderBy: [{ ordersCount: 'desc' }],
      take: Math.min(Math.max(limit, 1), 50),
      select: {
        id: true,
        title: true,
        minPriceSyp: true,
        rating: true,
        offersCount: true,
      },
    });
    return { signal, facets, products };
  }
}
