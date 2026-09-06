import { Injectable, Logger } from '@nestjs/common';
import { AnalyticsEventType, Prisma } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { normaliseQuery } from '../kernel/query-normalizer';

/**
 * The seam the rest of the application writes signals through.
 *
 * Every method here is **fire-and-forget and cannot fail its caller**. A
 * search that 500s because the analytics insert timed out is a worse product
 * than a trend chart with a gap in it, and the moment instrumentation can
 * break a checkout is the moment someone quite rightly rips it out. So each
 * method returns `void`, swallows its own errors into a debug log, and never
 * awaits anything on the request path.
 *
 * What is recorded is deliberately thin: a type, a product id, a session, and
 * for a search the *query text and how many rows came back*. No filters, no
 * scroll depth, no dwell time, nothing that would make a row interesting to
 * read about one person. The query text is the one sensitive field, and it
 * lives only until the collector has folded it into `search_term_daily` and
 * the retention sweep has removed the raw row.
 */
@Injectable()
export class TrendSignalService {
  private readonly logger = new Logger(TrendSignalService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * A search happened: what was asked, how many rows answered, and which
   * products were on the first page.
   *
   * The product ids are what turn a search from a term-level fact into a
   * product-level one — they are the `searchHits` denominator that makes
   * "high search exposure, no clicks" a finding a seller can act on. Only the
   * first page is recorded; a result nobody scrolled to is not exposure.
   */
  recordSearch(input: {
    query: string | null | undefined;
    resultCount: number;
    productIds?: readonly string[];
    userId?: string | null;
    sessionId?: string | null;
    source?: string;
  }): void {
    const query = (input.query ?? '').trim();
    if (!query) return;
    // A query the normaliser cannot make a term out of is noise, and storing
    // it would keep raw text around for no analytical gain.
    if (!normaliseQuery(query).termKey) return;

    const zero = input.resultCount <= 0;
    this.emit({
      type: zero
        ? AnalyticsEventType.SEARCH_ZERO_RESULT
        : AnalyticsEventType.PRODUCT_SEARCH,
      userId: input.userId ?? null,
      sessionId: input.sessionId ?? null,
      source: input.source ?? 'search',
      metadata: {
        q: query.slice(0, 200),
        results: Math.max(0, Math.trunc(input.resultCount)),
        product_ids: (input.productIds ?? []).slice(0, 24),
      },
    });
  }

  /** She tapped a result. The click-through half of Search Intelligence. */
  recordSearchClick(input: {
    query: string | null | undefined;
    productId: string;
    userId?: string | null;
    sessionId?: string | null;
  }): void {
    const query = (input.query ?? '').trim();
    if (!query) return;
    this.emit({
      type: AnalyticsEventType.SEARCH_RESULT_CLICK,
      productId: input.productId,
      userId: input.userId ?? null,
      sessionId: input.sessionId ?? null,
      source: 'search',
      metadata: { q: query.slice(0, 200) },
    });
  }

  /** A product page was opened. */
  recordProductView(input: {
    productId: string;
    userId?: string | null;
    sessionId?: string | null;
    source?: string;
  }): void {
    this.emit({
      type: AnalyticsEventType.PRODUCT_VIEW,
      productId: input.productId,
      userId: input.userId ?? null,
      sessionId: input.sessionId ?? null,
      source: input.source ?? 'product',
    });
  }

  recordCartAdd(input: {
    productId: string;
    sellerId?: string | null;
    userId?: string | null;
    quantity?: number;
  }): void {
    this.emit({
      type: AnalyticsEventType.CART_ADD,
      productId: input.productId,
      sellerId: input.sellerId ?? null,
      userId: input.userId ?? null,
      source: 'cart',
      metadata: { quantity: Math.max(1, Math.trunc(input.quantity ?? 1)) },
    });
  }

  recordCartRemove(input: {
    productId: string;
    sellerId?: string | null;
    userId?: string | null;
  }): void {
    this.emit({
      type: AnalyticsEventType.CART_REMOVE,
      productId: input.productId,
      sellerId: input.sellerId ?? null,
      userId: input.userId ?? null,
      source: 'cart',
    });
  }

  recordFavorite(input: {
    productId: string;
    userId?: string | null;
    added: boolean;
  }): void {
    this.emit({
      type: input.added
        ? AnalyticsEventType.PRODUCT_FAVORITE
        : AnalyticsEventType.PRODUCT_UNFAVORITE,
      productId: input.productId,
      userId: input.userId ?? null,
      source: 'favorites',
    });
  }

  recordShare(input: {
    productId: string;
    userId?: string | null;
    channel?: string;
  }): void {
    this.emit({
      type: AnalyticsEventType.PRODUCT_SHARE,
      productId: input.productId,
      userId: input.userId ?? null,
      source: input.channel ?? 'share',
    });
  }

  /** A post or story that carries a product was engaged with. */
  recordContentEngagement(input: {
    productId: string;
    kind: 'story' | 'post';
    userId?: string | null;
  }): void {
    this.emit({
      type:
        input.kind === 'story'
          ? AnalyticsEventType.STORY_VIEW
          : AnalyticsEventType.POST_ENGAGEMENT,
      productId: input.productId,
      userId: input.userId ?? null,
      source: input.kind,
    });
  }

  /** A cart aged out without a checkout. Emitted by the abandonment sweep. */
  recordCartAbandoned(input: {
    productId: string;
    sellerId?: string | null;
    userId?: string | null;
  }): void {
    this.emit({
      type: AnalyticsEventType.CART_ABANDONED,
      productId: input.productId,
      sellerId: input.sellerId ?? null,
      userId: input.userId ?? null,
      source: 'cart',
    });
  }

  // ── The one write ──────────────────────────────────────────────────────

  private emit(input: {
    type: AnalyticsEventType;
    productId?: string | null;
    sellerId?: string | null;
    userId?: string | null;
    sessionId?: string | null;
    source?: string | null;
    metadata?: Record<string, unknown>;
  }): void {
    void this.prisma.analyticsEvent
      .create({
        data: {
          type: input.type,
          productId: input.productId ?? null,
          sellerId: input.sellerId ?? null,
          userId: input.userId ?? null,
          sessionId: input.sessionId ?? null,
          source: input.source ?? null,
          metadata: (input.metadata ?? undefined) as
            | Prisma.InputJsonValue
            | undefined,
        },
      })
      .catch((error: unknown) => {
        // Debug, not warn: a dropped signal is a rounding error in a daily
        // aggregate, and an operator paged at 3am for one would be right to be
        // annoyed. A sustained outage shows up as a flat line on the charts,
        // which is the signal that actually matters.
        this.logger.debug(
          `Trend signal ${input.type} not recorded: ${
            error instanceof Error ? error.message : String(error)
          }`,
        );
      });
  }
}
