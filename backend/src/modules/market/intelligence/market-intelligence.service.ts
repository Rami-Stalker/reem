import { Injectable } from '@nestjs/common';
import {
  MarketFinding,
  MarketSignal,
  MarketSubject,
  OfferStatus,
  ProductStatus,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { MarketEconomicsService } from '../economics/market-economics.service';

/**
 * How sure we have to be before saying it out loud.
 *
 * The economics layer records every reading, including the ones resting on
 * nine views. Publishing those as "opportunities" would be the fastest way to
 * make the whole surface untrustworthy, so the interpretation layer is where
 * the confidence gate lives.
 */
const MIN_CONFIDENCE = 0.25;

/** Below this a finding is arithmetic, not an opportunity. */
const MIN_STRENGTH = 30;

/**
 * Which kind of finding leads.
 *
 * Strength is not comparable across codes — RISING saturates at 100 by design,
 * while a SUPPLY_GAP's strength *is* its tension and rarely passes 40 — so
 * ranking on strength alone systematically buries the findings this layer
 * exists for beneath the ones the trend engine already reports. On real seller
 * data that showed up immediately: four direction findings above the one
 * supply gap, which was the only sentence on the screen the trend dashboard
 * could not already have said.
 *
 * So: supply against demand first, then what a listing is doing, then
 * direction. Strength orders within a tier, where it is comparable.
 */
const FINDING_PRIORITY: Record<string, number> = {
  STOCKED_OUT: 0,
  SUPPLY_GAP: 1,
  WEAK_CONVERSION: 2,
  CROWDED: 3,
  OVERSUPPLIED: 4,
  RISING: 5,
  COOLING: 6,
};

const priorityOf = (code: string): number => FINDING_PRIORITY[code] ?? 9;

export type Audience = 'SELLER' | 'ADMIN';

export interface Opportunity {
  code: MarketFinding;
  subjectType: MarketSubject;
  subjectId: string;
  subjectName: string;
  /** 0-100 — the finding's own strength, gated by the reading's confidence. */
  strength: number;
  confidence: number;
  /** What the market is doing, in her language. */
  headline: string;
  /** What to do about it. Empty when the honest answer is "watch it". */
  action: string;
  /** The counts the sentence was written from, so it can be checked. */
  evidence: Record<string, number | null>;
}

/**
 * Ohara Market Intelligence.
 *
 * ── What this is not ─────────────────────────────────────────────────────
 *
 * It is not a second trend engine. `trends/admin/*` already answers rising
 * categories, unmet search demand, price movement and seller performance, and
 * rebuilding any of that here would give Ohara two numbers for one question —
 * which in practice means the wrong one gets quoted.
 *
 * What was genuinely missing is *interpretation*: the trend engine says demand
 * for evening dresses is up 40%, and stops. It does not say that nobody is
 * stocking them, that the four shops who do sold out last week, or that a
 * fifth shop entering would be walking into a crowd. Those are statements
 * about supply against demand, which is what the economics layer computes and
 * what this file turns into sentences somebody can act on.
 *
 * So: no facts are collected here, no scores are computed here. This reads
 * `MarketSignal`, filters by who is asking, and writes Arabic beside the
 * arithmetic that produced it.
 */
@Injectable()
export class MarketIntelligenceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly economics: MarketEconomicsService,
  ) {}

  /**
   * Opportunities across the whole platform.
   *
   * The admin's question is a recruiting question — which corners of the
   * market are short of shops — so supply gaps and stock-outs lead, and
   * crowding is included because knowing where *not* to recruit is the same
   * decision seen from the other side.
   */
  async platform(limit = 12): Promise<Opportunity[]> {
    // No RISING or COOLING here, deliberately. Direction is the trend
    // engine's question and `trends/admin/*` already answers it — including it
    // was the first thing tried, and on real data seven of the top eight
    // "opportunities" came back as rising categories with nothing to do about
    // them, which is exactly the duplication this layer exists to avoid. What
    // is left is supply read against demand, which nothing else computes.
    const wanted: MarketFinding[] = [
      MarketFinding.SUPPLY_GAP,
      MarketFinding.STOCKED_OUT,
      MarketFinding.CROWDED,
      MarketFinding.OVERSUPPLIED,
    ];

    const found: Array<{
      signal: MarketSignal;
      finding: { code: string; strength: number; evidence: Record<string, number | null> };
    }> = [];

    for (const code of wanted) {
      const categories = await this.economics.withFinding(
        MarketSubject.CATEGORY,
        code,
        limit,
      );
      found.push(...categories);
      // Product-level stock-outs are the one product finding the admin needs:
      // demand arriving at something nobody can buy is revenue leaving today.
      if (code === MarketFinding.STOCKED_OUT) {
        const products = await this.economics.withFinding(
          MarketSubject.PRODUCT,
          code,
          limit,
        );
        found.push(...products);
      }
    }

    return this.render(found, 'ADMIN', limit);
  }

  /**
   * Opportunities one seller can actually act on.
   *
   * Filtered to the categories she already sells in and the products she
   * lists. An opportunity in a category she has never touched is a business
   * plan, not an opportunity, and putting it on her dashboard is how these
   * screens become wallpaper.
   */
  async forSeller(sellerId: string, limit = 8): Promise<Opportunity[]> {
    const [categoryIds, productIds] = await Promise.all([
      this.sellerCategories(sellerId),
      this.sellerProducts(sellerId),
    ]);

    if (!categoryIds.length && !productIds.length) return [];

    const categorySet = new Set(categoryIds);
    const productSet = new Set(productIds);

    const found: Array<{
      signal: MarketSignal;
      finding: { code: string; strength: number; evidence: Record<string, number | null> };
    }> = [];

    // Category findings: where her market is going.
    for (const code of [
      MarketFinding.SUPPLY_GAP,
      MarketFinding.RISING,
      MarketFinding.CROWDED,
      MarketFinding.OVERSUPPLIED,
      MarketFinding.COOLING,
    ]) {
      const rows = await this.economics.withFinding(
        MarketSubject.CATEGORY,
        code,
        40,
      );
      found.push(...rows.filter((row) => categorySet.has(row.signal.subjectId)));
    }

    // Product findings: what her own listings are doing.
    for (const code of [
      MarketFinding.STOCKED_OUT,
      MarketFinding.WEAK_CONVERSION,
      MarketFinding.RISING,
    ]) {
      const rows = await this.economics.withFinding(
        MarketSubject.PRODUCT,
        code,
        60,
      );
      found.push(...rows.filter((row) => productSet.has(row.signal.subjectId)));
    }

    return this.render(found, 'SELLER', limit);
  }

  /** The categories she has live offers in. */
  private async sellerCategories(sellerId: string): Promise<string[]> {
    const rows = await this.prisma.product.findMany({
      where: {
        status: ProductStatus.ACTIVE,
        offers: { some: { sellerId, status: OfferStatus.ACTIVE } },
      },
      select: { categoryId: true },
      distinct: ['categoryId'],
      take: 60,
    });
    return rows.map((row) => row.categoryId);
  }

  private async sellerProducts(sellerId: string): Promise<string[]> {
    const rows = await this.prisma.product.findMany({
      where: { offers: { some: { sellerId, status: OfferStatus.ACTIVE } } },
      select: { id: true },
      take: 300,
    });
    return rows.map((row) => row.id);
  }

  // ── Rendering ─────────────────────────────────────────────────────────

  /**
   * Signals into sentences.
   *
   * The gate comes first: a low-confidence reading is dropped entirely rather
   * than hedged, because a hedged opportunity still occupies the slot a real
   * one would have used.
   */
  private async render(
    rows: Array<{
      signal: MarketSignal;
      finding: { code: string; strength: number; evidence: Record<string, number | null> };
    }>,
    audience: Audience,
    limit: number,
  ): Promise<Opportunity[]> {
    const kept = rows.filter(
      (row) =>
        row.signal.confidence >= MIN_CONFIDENCE &&
        row.finding.strength >= MIN_STRENGTH,
    );

    // One opportunity per subject: the strongest thing true about it. Three
    // findings on one category reads as three problems and is one.
    const best = new Map<string, (typeof kept)[number]>();
    for (const row of kept) {
      const key = `${row.signal.subjectType}:${row.signal.subjectId}`;
      const held = best.get(key);
      if (!held) {
        best.set(key, row);
        continue;
      }
      const tier = priorityOf(row.finding.code) - priorityOf(held.finding.code);
      if (tier < 0 || (tier === 0 && row.finding.strength > held.finding.strength)) {
        best.set(key, row);
      }
    }

    const chosen = [...best.values()]
      .sort((a, b) => {
        const tier = priorityOf(a.finding.code) - priorityOf(b.finding.code);
        if (tier !== 0) return tier;
        return b.finding.strength - a.finding.strength;
      })
      .slice(0, limit);

    const names = await this.namesFor(chosen.map((row) => row.signal));

    return chosen.map((row) => {
      const evidence = row.finding.evidence ?? {};
      const name =
        names.get(`${row.signal.subjectType}:${row.signal.subjectId}`) ?? '—';
      const { headline, action } = phrase(
        row.finding.code as MarketFinding,
        row.signal.subjectType,
        name,
        evidence,
        audience,
      );

      return {
        code: row.finding.code as MarketFinding,
        subjectType: row.signal.subjectType,
        subjectId: row.signal.subjectId,
        subjectName: name,
        strength: row.finding.strength,
        confidence: row.signal.confidence,
        headline,
        action,
        evidence,
      };
    })
      // An "opportunity" with nothing to do about it is an observation, and
      // this surface is the one place in Ohara that promises otherwise. If a
      // finding has no action for *this* audience, it does not belong on
      // their screen — it belongs on the trend engine's.
      .filter((opportunity) => opportunity.action.length > 0);
  }

  /** Category and product names, in two queries rather than per row. */
  private async namesFor(signals: MarketSignal[]): Promise<Map<string, string>> {
    const categoryIds = signals
      .filter((s) => s.subjectType === MarketSubject.CATEGORY)
      .map((s) => s.subjectId);
    const productIds = signals
      .filter((s) => s.subjectType === MarketSubject.PRODUCT)
      .map((s) => s.subjectId);

    const out = new Map<string, string>();

    if (categoryIds.length) {
      const rows = await this.prisma.category.findMany({
        where: { id: { in: categoryIds } },
        select: { id: true, nameAr: true },
      });
      for (const row of rows) {
        out.set(`${MarketSubject.CATEGORY}:${row.id}`, row.nameAr);
      }
    }
    if (productIds.length) {
      const rows = await this.prisma.product.findMany({
        where: { id: { in: productIds } },
        select: { id: true, title: true },
      });
      for (const row of rows) {
        out.set(`${MarketSubject.PRODUCT}:${row.id}`, row.title);
      }
    }

    return out;
  }
}

/**
 * The Arabic, written beside the arithmetic that produced it.
 *
 * Two audiences, because the same finding is a different sentence depending on
 * who can act on it: a supply gap tells a seller to stock, and tells the admin
 * to find someone who will. Written here rather than in the client for the
 * same reason every other engine in Ohara does it — the numbers and the words
 * describing them have to change together or one of them starts lying.
 */
function phrase(
  code: MarketFinding,
  subjectType: MarketSubject,
  name: string,
  evidence: Record<string, number | null>,
  audience: Audience,
): { headline: string; action: string } {
  const growthPct = evidence['growth'] !== null && evidence['growth'] !== undefined
    ? Math.round((evidence['growth'] as number) * 100)
    : null;
  const sellers = evidence['sellers'];
  // A count of one is a person, not a segment. Ohara applies a k-anonymity
  // floor of three to every other aggregate it shows about shoppers, and an
  // opportunity screen is not the place to make an exception — «وحدة عندها
  // نقص» in a category with five products names somebody.
  const openNeeds =
    typeof evidence['openNeeds'] === 'number' && evidence['openNeeds'] >= 3
      ? evidence['openNeeds']
      : null;
  const views = evidence['views'];
  const orders = evidence['orders'];

  switch (code) {
    case MarketFinding.SUPPLY_GAP:
      return {
        headline: openNeeds
          ? `الطلب على «${name}» أعلى من المعروض، و${openNeeds} نساء ينقصهن شيء في هذه الخانة.`
          : `الطلب على «${name}» أعلى من المعروض حاليًا.`,
        action:
          audience === 'SELLER'
            ? 'إن كانت لديكِ قطع في هذا القسم، فهذا وقت طرحها.'
            : 'قسم يستحق استقطاب بائعات جديدات.',
      };

    case MarketFinding.STOCKED_OUT:
      return {
        headline:
          subjectType === MarketSubject.PRODUCT
            ? `«${name}» عليه طلب ومخزونه صفر.`
            : `هناك طلب على «${name}» ولا مخزون متاح.`,
        action:
          audience === 'SELLER'
            ? 'أعيدي ملء المخزون — الطلب موجود اليوم لا غداً.'
            : 'طلب على شيء لا يُباع؛ يستحق المتابعة مع البائعات.',
      };

    case MarketFinding.RISING:
      return {
        headline:
          growthPct !== null
            ? `«${name}» صاعد ${growthPct}% عن النصف الأول من الفترة.`
            : `الطلب على «${name}» يزداد.`,
        action:
          audience === 'SELLER'
            ? 'وقت جيد لطرح جديد أو إطلاق في هذه الخانة.'
            : '',
      };

    case MarketFinding.COOLING:
      return {
        headline:
          growthPct !== null
            ? `«${name}» نازل ${Math.abs(growthPct)}% عن النصف الأول من الفترة.`
            : `الطلب على «${name}» يهدأ.`,
        action: audience === 'SELLER' ? 'لا توسّعي المخزون هنا الآن.' : '',
      };

    case MarketFinding.WEAK_CONVERSION:
      return {
        headline:
          views && orders !== null && orders !== undefined
            ? `«${name}» فُتح ${views} مرة ولم يُطلب إلا ${orders} مرة.`
            : `«${name}» يُفتح كثيراً ولا يُباع.`,
        action:
          audience === 'SELLER'
            ? 'غالباً الصور أو السعر أو تفاصيل المقاس — لا الطلب.'
            : '',
      };

    case MarketFinding.CROWDED:
      return {
        headline: sellers
          ? `«${name}» فيه ${sellers} بائعات والمعروض أكثر من الطلب.`
          : `«${name}» مزدحم بالبائعات.`,
        action:
          audience === 'SELLER'
            ? 'الدخول هنا يحتاج تميّزاً واضحاً لا سعراً أرخص فقط.'
            : 'لا يُنصح باستقطاب بائعات إضافيات لهذا القسم.',
      };

    case MarketFinding.OVERSUPPLIED:
      return {
        headline: `المعروض من «${name}» أكثر من الطلب عليه.`,
        action:
          audience === 'SELLER'
            ? 'خفّفي التوسّع هنا ووجّهي الجديد إلى خانة أخرى.'
            : 'قسم مشبع — استقطاب بائعات إضافيات له لا يزيد المبيعات.',
      };

    default:
      return { headline: `«${name}»`, action: '' };
  }
}
