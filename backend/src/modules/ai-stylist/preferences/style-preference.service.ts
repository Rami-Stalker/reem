import { Injectable, Logger } from '@nestjs/common';
import {
  AiStylistFeedback,
  AnalyticsEventType,
  ModestyLevel,
  Prisma,
  StylePersona,
  UserStylePreference,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { detectColours } from '../understanding/stylist-lexicon';
import {
  StyleProfile,
  emptyStyleProfile,
  normaliseAffinity,
} from './style-profile';

/** How much one act of each kind says about her taste. */
const WEIGHTS = {
  purchase: 6,
  save: 3.5,
  favourite: 3,
  cartAdd: 2.5,
  view: 1,
  dismiss: -4,
} as const;

/** Rows read per signal source. Enough to be representative, bounded so the
 *  profile refresh stays a handful of indexed reads. */
const SAMPLE = 200;

@Injectable()
export class StylePreferenceService {
  private readonly logger = new Logger(StylePreferenceService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ── The stated half ───────────────────────────────────────────────────

  async findOrCreate(userId: string): Promise<UserStylePreference> {
    const existing = await this.prisma.userStylePreference.findUnique({
      where: { userId },
    });
    if (existing) return existing;
    return this.prisma.userStylePreference.create({ data: { userId } });
  }

  async update(
    userId: string,
    patch: {
      modesty?: ModestyLevel;
      personas?: StylePersona[];
      favouriteColours?: string[];
      avoidedColours?: string[];
      preferredCategorySlugs?: string[];
      avoidedCategorySlugs?: string[];
      sizes?: { clothing?: string; shoes?: string };
      budgetMinSyp?: number | null;
      budgetMaxSyp?: number | null;
    },
  ): Promise<UserStylePreference> {
    await this.findOrCreate(userId);
    return this.prisma.userStylePreference.update({
      where: { userId },
      data: {
        ...(patch.modesty !== undefined ? { modesty: patch.modesty } : {}),
        ...(patch.personas ? { personas: patch.personas } : {}),
        ...(patch.favouriteColours ? { favouriteColours: patch.favouriteColours } : {}),
        ...(patch.avoidedColours ? { avoidedColours: patch.avoidedColours } : {}),
        ...(patch.preferredCategorySlugs
          ? { preferredCategorySlugs: patch.preferredCategorySlugs }
          : {}),
        ...(patch.avoidedCategorySlugs
          ? { avoidedCategorySlugs: patch.avoidedCategorySlugs }
          : {}),
        ...(patch.sizes ? { sizes: patch.sizes as Prisma.InputJsonValue } : {}),
        ...(patch.budgetMinSyp !== undefined
          ? { budgetMinSyp: patch.budgetMinSyp }
          : {}),
        ...(patch.budgetMaxSyp !== undefined
          ? { budgetMaxSyp: patch.budgetMaxSyp }
          : {}),
      },
    });
  }

  /**
   * Records what she learned about herself while talking to the stylist.
   *
   * Called after every turn with whatever the brief newly established. It only
   * fills blanks: saying "أسود" once in one conversation is not a declaration
   * that black is her favourite colour, so a stated preference is never
   * overwritten by an inferred one.
   */
  async learnFromBrief(
    userId: string,
    brief: {
      modesty: ModestyLevel;
      sizes: { clothing?: string; shoes?: string };
      personas: StylePersona[];
    },
  ): Promise<void> {
    const current = await this.findOrCreate(userId);
    const data: Prisma.UserStylePreferenceUpdateInput = {};

    if (
      current.modesty === ModestyLevel.UNSPECIFIED &&
      brief.modesty !== ModestyLevel.UNSPECIFIED
    ) {
      data.modesty = brief.modesty;
    }

    const storedSizes = (current.sizes as { clothing?: string; shoes?: string } | null) ?? {};
    const mergedSizes = {
      clothing: storedSizes.clothing ?? brief.sizes.clothing,
      shoes: storedSizes.shoes ?? brief.sizes.shoes,
    };
    if (
      mergedSizes.clothing !== storedSizes.clothing ||
      mergedSizes.shoes !== storedSizes.shoes
    ) {
      data.sizes = mergedSizes as Prisma.InputJsonValue;
    }

    if (!current.personas.length && brief.personas.length) {
      data.personas = brief.personas.slice(0, 3);
    }

    if (!Object.keys(data).length) return;
    await this.prisma.userStylePreference.update({ where: { userId }, data });
  }

  // ── Feedback ──────────────────────────────────────────────────────────

  /**
   * Stores one act of feedback on a card.
   *
   * Upserted on `(user, product, feedback)` so tapping "أعجبني" twice is one
   * fact rather than two votes.
   */
  async recordFeedback(input: {
    userId: string;
    productId: string;
    feedback: AiStylistFeedback;
    recommendationId?: string;
  }): Promise<void> {
    const weight = this.feedbackWeight(input.feedback);
    await this.prisma.userStyleSignal.upsert({
      where: {
        userId_productId_feedback: {
          userId: input.userId,
          productId: input.productId,
          feedback: input.feedback,
        },
      },
      create: {
        userId: input.userId,
        productId: input.productId,
        feedback: input.feedback,
        weight,
        sourceId: input.recommendationId,
      },
      update: { weight, sourceId: input.recommendationId },
    });
  }

  private feedbackWeight(feedback: AiStylistFeedback): number {
    switch (feedback) {
      case AiStylistFeedback.PURCHASED:
        return WEIGHTS.purchase;
      case AiStylistFeedback.ADDED_TO_CART:
        return WEIGHTS.cartAdd;
      case AiStylistFeedback.SAVED:
        return WEIGHTS.save;
      case AiStylistFeedback.LIKED:
        return WEIGHTS.favourite;
      case AiStylistFeedback.DISMISSED:
        return WEIGHTS.dismiss;
      case AiStylistFeedback.NONE:
        return 0;
    }
  }

  // ── The derived half ──────────────────────────────────────────────────

  /**
   * Builds the profile the ranker scores against.
   *
   * Reads the behaviour tables live rather than trusting the cached
   * `derivedSignals` column, because the cache is a convenience for the
   * preferences *screen* and this is the thing a recommendation is built on —
   * a stale affinity map is a wrong recommendation, and the reads are all
   * indexed and bounded.
   */
  async buildProfile(userId: string | null): Promise<StyleProfile> {
    const profile = emptyStyleProfile(userId);
    if (!userId) return profile;

    const [stored, orders, favourites, wishlist, views, searches, signals] =
      await Promise.all([
        this.prisma.userStylePreference.findUnique({ where: { userId } }),
        this.prisma.orderItem.findMany({
          where: { sellerOrder: { order: { userId } } },
          select: {
            productId: true,
            quantity: true,
            // Not `unitPrice`: that is in the order's currency, whereas
            // `minPriceSyp` is already normalised — and the budget band this
            // feeds has to compare against other SYP figures.
            sellerOrder: { select: { sellerId: true } },
            product: {
              select: {
                id: true,
                title: true,
                brandId: true,
                minPriceSyp: true,
                category: { select: { slug: true } },
              },
            },
          },
          take: SAMPLE,
          orderBy: { sellerOrder: { createdAt: 'desc' } },
        }),
        this.prisma.favorite.findMany({
          where: { userId },
          select: { product: { select: PRODUCT_SIGNAL_SELECT } },
          take: SAMPLE,
          orderBy: { createdAt: 'desc' },
        }),
        this.prisma.wishlistCollectionItem.findMany({
          where: { collection: { userId }, productId: { not: null } },
          select: { product: { select: PRODUCT_SIGNAL_SELECT } },
          take: SAMPLE,
          orderBy: { createdAt: 'desc' },
        }),
        this.prisma.analyticsEvent.findMany({
          where: { userId, type: AnalyticsEventType.PRODUCT_VIEW },
          select: {
            sellerId: true,
            product: { select: PRODUCT_SIGNAL_SELECT },
          },
          take: SAMPLE,
          orderBy: { createdAt: 'desc' },
        }),
        this.prisma.searchHistory.findMany({
          where: { userId },
          select: { query: true },
          take: 40,
          orderBy: { createdAt: 'desc' },
        }),
        this.prisma.userStyleSignal.findMany({
          where: { userId },
          select: {
            productId: true,
            feedback: true,
            weight: true,
            product: { select: PRODUCT_SIGNAL_SELECT },
          },
          take: SAMPLE,
          orderBy: { createdAt: 'desc' },
        }),
      ]);

    if (stored) this.applyStated(profile, stored);

    const purchasePrices: number[] = [];

    for (const item of orders) {
      if (item.productId) profile.purchasedProductIds.add(item.productId);
      const weight = WEIGHTS.purchase * Math.min(item.quantity, 3);
      if (item.product) {
        bump(profile.categoryAffinity, item.product.category.slug, weight);
        bump(profile.brandAffinity, item.product.brandId, weight);
        for (const colour of detectColours(item.product.title)) {
          bump(profile.colourAffinity, colour, weight);
        }
        if (item.product.minPriceSyp) {
          purchasePrices.push(Number(item.product.minPriceSyp));
        }
      }
      bump(profile.sellerAffinity, item.sellerOrder.sellerId, weight);
    }

    for (const row of favourites) {
      this.applyProductSignal(profile, row.product, WEIGHTS.favourite);
      if (row.product) profile.savedProductIds.add(row.product.id);
    }

    for (const row of wishlist) {
      this.applyProductSignal(profile, row.product, WEIGHTS.save);
      if (row.product) profile.savedProductIds.add(row.product.id);
    }

    for (const row of views) {
      this.applyProductSignal(profile, row.product, WEIGHTS.view);
      if (row.product) profile.viewedProductIds.add(row.product.id);
      if (row.sellerId) bump(profile.sellerAffinity, row.sellerId, WEIGHTS.view * 0.8);
    }

    for (const signal of signals) {
      if (signal.feedback === AiStylistFeedback.DISMISSED) {
        profile.dismissedProductIds.add(signal.productId);
      }
      if (
        signal.feedback === AiStylistFeedback.SAVED ||
        signal.feedback === AiStylistFeedback.LIKED
      ) {
        profile.savedProductIds.add(signal.productId);
      }
      this.applyProductSignal(profile, signal.product, signal.weight);
    }

    profile.recentQueries = [...new Set(searches.map((row) => row.query))].slice(0, 10);

    // The band she actually buys in — the interquartile range, so one
    // celebratory purchase does not redefine her budget.
    if (purchasePrices.length >= 3) {
      const sorted = [...purchasePrices].sort((a, b) => a - b);
      profile.typicalMinSyp = percentile(sorted, 0.25);
      profile.typicalMaxSyp = percentile(sorted, 0.75);
    } else if (purchasePrices.length) {
      profile.typicalMinSyp = Math.min(...purchasePrices);
      profile.typicalMaxSyp = Math.max(...purchasePrices);
    }

    profile.categoryAffinity = normaliseAffinity(profile.categoryAffinity);
    profile.sellerAffinity = normaliseAffinity(profile.sellerAffinity);
    profile.colourAffinity = normaliseAffinity(profile.colourAffinity);
    profile.brandAffinity = normaliseAffinity(profile.brandAffinity);
    profile.maturity = this.maturity(profile);

    return profile;
  }

  private applyStated(profile: StyleProfile, stored: UserStylePreference): void {
    profile.modesty = stored.modesty;
    profile.personas = [...stored.personas];
    profile.favouriteColours = [...stored.favouriteColours];
    profile.avoidedColours = [...stored.avoidedColours];
    profile.preferredCategorySlugs = [...stored.preferredCategorySlugs];
    profile.avoidedCategorySlugs = [...stored.avoidedCategorySlugs];
    const sizes = (stored.sizes as { clothing?: string; shoes?: string } | null) ?? {};
    profile.sizes = { clothing: sizes.clothing, shoes: sizes.shoes };
    profile.budgetMinSyp = stored.budgetMinSyp ? Number(stored.budgetMinSyp) : null;
    profile.budgetMaxSyp = stored.budgetMaxSyp ? Number(stored.budgetMaxSyp) : null;
  }

  private applyProductSignal(
    profile: StyleProfile,
    product: ProductSignal | null,
    weight: number,
  ): void {
    if (!product || weight === 0) return;
    bump(profile.categoryAffinity, product.category.slug, weight);
    bump(profile.brandAffinity, product.brandId, weight);
    for (const colour of detectColours(product.title)) {
      bump(profile.colourAffinity, colour, weight);
    }
    for (const offer of product.offers) {
      bump(profile.sellerAffinity, offer.sellerId, weight * 0.6);
    }
  }

  private maturity(profile: StyleProfile): StyleProfile['maturity'] {
    if (profile.purchasedProductIds.size >= 5) return 'loyal';
    if (profile.purchasedProductIds.size >= 1 || profile.savedProductIds.size >= 5) {
      return 'engaged';
    }
    if (profile.viewedProductIds.size >= 8) return 'browsing';
    return 'new';
  }

  /**
   * Writes the derived half back onto the row.
   *
   * Purely so the preferences screen can show "استنتجنا أنك تحبين…" without
   * recomputing, and so an analyst can see what the ranker saw. Nothing reads
   * it back into a recommendation.
   */
  async refreshDerived(userId: string): Promise<UserStylePreference> {
    const profile = await this.buildProfile(userId);
    await this.findOrCreate(userId);

    return this.prisma.userStylePreference.update({
      where: { userId },
      data: {
        typicalMinSyp: profile.typicalMinSyp,
        typicalMaxSyp: profile.typicalMaxSyp,
        derivedSignals: {
          categories: topEntries(profile.categoryAffinity),
          sellers: topEntries(profile.sellerAffinity),
          colours: topEntries(profile.colourAffinity),
          brands: topEntries(profile.brandAffinity),
          counts: {
            purchased: profile.purchasedProductIds.size,
            saved: profile.savedProductIds.size,
            viewed: profile.viewedProductIds.size,
            dismissed: profile.dismissedProductIds.size,
          },
          maturity: profile.maturity,
          recent_queries: profile.recentQueries,
        } satisfies Prisma.InputJsonObject,
        computedAt: new Date(),
      },
    });
  }
}

const PRODUCT_SIGNAL_SELECT = {
  id: true,
  title: true,
  brandId: true,
  minPriceSyp: true,
  category: { select: { slug: true } },
  offers: { select: { sellerId: true }, take: 3 },
} satisfies Prisma.ProductSelect;

type ProductSignal = Prisma.ProductGetPayload<{
  select: typeof PRODUCT_SIGNAL_SELECT;
}>;

function bump(map: Map<string, number>, key: string | null | undefined, weight: number): void {
  if (!key) return;
  map.set(key, (map.get(key) ?? 0) + weight);
}

function percentile(sorted: number[], fraction: number): number {
  const index = Math.min(sorted.length - 1, Math.floor(sorted.length * fraction));
  return sorted[index] ?? sorted[0] ?? 0;
}

function topEntries(map: Map<string, number>, limit = 12) {
  return [...map.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([key, weight]) => ({ key, weight: Math.round(weight * 1000) / 1000 }));
}
