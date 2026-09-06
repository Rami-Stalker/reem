import { Injectable } from '@nestjs/common';
import { OutfitSlot, Prisma } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import {
  LIVE_OFFER_WHERE,
  PRODUCT_CARD_INCLUDE,
  PURCHASABLE_PRODUCT_WHERE,
} from '../../../common/catalog/product-include';
import { StyleBrief, formatSyp } from '../understanding/style-brief';
import { categorySlugsForSlots, colourEntry } from '../understanding/stylist-lexicon';

export type StylistCandidate = Prisma.ProductGetPayload<{
  include: typeof PRODUCT_CARD_INCLUDE;
}>;

/** A constraint the search had to give up on, and how to say so in Arabic. */
export interface Relaxation {
  code: RelaxationCode;
  message: string;
}

export type RelaxationCode =
  | 'BUDGET_RAISED'
  | 'BUDGET_DROPPED'
  | 'SIZE_DROPPED'
  | 'COLOUR_DROPPED'
  | 'CATEGORY_WIDENED'
  | 'KEYWORDS_DROPPED';

export interface RetrievalResult {
  candidates: StylistCandidate[];
  relaxations: Relaxation[];
  /** How many rows matched everything she asked for, before any relaxing. */
  strictCount: number;
}

/**
 * Finds the real rows a brief could be answered with.
 *
 * This is the layer that makes the whole feature honest. It never generates,
 * never guesses, and never returns anything that is not live: every query
 * starts from `PURCHASABLE_PRODUCT_WHERE`, which is the same predicate the
 * catalog, search and discovery use for "a customer can buy this right now".
 *
 * The other half of its job is the relaxation ladder. A fully specified brief —
 * black, midi, size M, under 500k, modest, by Thursday — can easily match
 * nothing, and an assistant that answers a paragraph with "لا يوجد" has failed
 * at the one thing it exists for. So constraints are dropped in a fixed order,
 * least painful first, and every drop is recorded so the reply can admit it.
 */
@Injectable()
export class ProductRetrievalService {
  /** Candidates fetched per pass. Wide enough for the ranker to have a real
   *  choice, bounded so one turn stays one indexed page. */
  private static readonly POOL = 120;

  constructor(private readonly prisma: PrismaService) {}

  async retrieve(
    brief: StyleBrief,
    options: { slot?: OutfitSlot; pool?: number } = {},
  ): Promise<RetrievalResult> {
    const pool = options.pool ?? ProductRetrievalService.POOL;

    // The ladder, in the order a person would give ground. Keywords first
    // because they are the softest thing she said; budget last but one,
    // because being shown things she cannot afford is worse than being shown
    // the wrong colour; category never — that is the request itself.
    const ladder: Array<{ relax: RelaxedConstraints; code: RelaxationCode | null }> = [
      { relax: {}, code: null },
      { relax: { keywords: true }, code: 'KEYWORDS_DROPPED' },
      { relax: { keywords: true, colours: true }, code: 'COLOUR_DROPPED' },
      { relax: { keywords: true, colours: true, sizes: true }, code: 'SIZE_DROPPED' },
      {
        relax: { keywords: true, colours: true, sizes: true, budget: 1.25 },
        code: 'BUDGET_RAISED',
      },
      // Over budget in the category she asked for comes BEFORE a different
      // category inside it, and the order is the whole judgement.
      //
      // A whole category can sit above what she named — the cheapest dress in
      // this shop is over a million lira against a 500k budget. Answering that
      // with skirts is a shop assistant quietly handing her a different
      // garment; answering "الفساتين بتبدا من مليون" is one telling her what
      // her budget actually buys. The ranker still sorts the cheapest first
      // and the reply still says the band was missed.
      {
        relax: { keywords: true, colours: true, sizes: true, dropBudget: true },
        code: 'BUDGET_DROPPED',
      },
      {
        relax: {
          keywords: true,
          colours: true,
          sizes: true,
          budget: 1.25,
          widenCategories: true,
        },
        code: 'CATEGORY_WIDENED',
      },
    ];

    const relaxations: Relaxation[] = [];
    let strictCount = 0;

    for (const [index, rung] of ladder.entries()) {
      const where = await this.buildWhere(brief, rung.relax, options.slot);
      const candidates = await this.prisma.product.findMany({
        where,
        include: PRODUCT_CARD_INCLUDE,
        take: pool,
        // Ordering here is only about *which* slice of a large match set we
        // pull; the ranker decides the order she sees. Popular-and-well-rated
        // is the slice most likely to contain the good answer.
        orderBy: [
          { rating: 'desc' },
          { ordersCount: 'desc' },
          { favoritesCount: 'desc' },
          { createdAt: 'desc' },
        ],
      });

      if (index === 0) strictCount = candidates.length;

      // Enough to rank, or the last rung. Four is the point below which the
      // ranker has no real choice and diversity rules cannot apply.
      const enough = candidates.length >= 4 || index === ladder.length - 1;
      if (!enough) continue;

      // Record every rung we passed through, not just the one that answered.
      for (const passed of ladder.slice(1, index + 1)) {
        if (passed.code) {
          relaxations.push({
            code: passed.code,
            message: this.explain(passed.code, brief),
          });
        }
      }
      return { candidates, relaxations, strictCount };
    }

    return { candidates: [], relaxations, strictCount };
  }

  /**
   * Retrieval for one slot of an outfit.
   *
   * The brief is narrowed to that slot's categories and its share of the
   * budget before the same machinery runs, so the shoes are searched for as
   * shoes rather than filtered out of a pool of dresses.
   */
  async retrieveForSlot(
    brief: StyleBrief,
    slot: OutfitSlot,
    budget: { min: number | null; max: number | null },
  ): Promise<RetrievalResult> {
    const slotBrief: StyleBrief = {
      ...brief,
      slots: [slot],
      categorySlugs: categorySlugsForSlots([slot]),
      budgetMin: budget.min,
      budgetMax: budget.max,
      // A slot search should not also insist on the free text of the original
      // sentence — "فستان أسود" must not be required of the handbag.
      keywords: [],
    };
    return this.retrieve(slotBrief, { slot, pool: 60 });
  }

  /**
   * Builds the `WHERE`.
   *
   * Only genuinely hard constraints live here — availability, category,
   * budget, size, and an explicit colour refusal. Everything softer (taste,
   * modesty preference, materials, personalization) is a *score*, because
   * expressing a preference as a filter is how a search ends up empty for
   * reasons nobody can explain.
   */
  private async buildWhere(
    brief: StyleBrief,
    relax: RelaxedConstraints,
    slot?: OutfitSlot,
  ): Promise<Prisma.ProductWhereInput> {
    const and: Prisma.ProductWhereInput[] = [PURCHASABLE_PRODUCT_WHERE];

    // ── Category ────────────────────────────────────────────────────────
    const slugs = brief.categorySlugs.length
      ? brief.categorySlugs
      : categorySlugsForSlots(brief.slots);

    if (slugs.length && !relax.widenCategories) {
      and.push({ category: { slug: { in: slugs } } });
    } else if (slugs.length && relax.widenCategories) {
      // One step up the tree: siblings of what she asked for, which is what a
      // shop assistant would reach for next.
      const parents = await this.prisma.category.findMany({
        where: { slug: { in: slugs } },
        select: { parentId: true },
      });
      const parentIds = [
        ...new Set(parents.map((row) => row.parentId).filter((id): id is string => !!id)),
      ];
      if (parentIds.length) {
        and.push({ category: { parentId: { in: parentIds } } });
      }
    }

    // ── Budget ──────────────────────────────────────────────────────────
    // Compared against the product's SYP roll-ups, which already carry every
    // seller's price normalised through the frozen FX rate (Q45/Q46).
    const headroom = relax.budget ?? 1;
    if (brief.budgetMax !== null && !relax.dropBudget) {
      and.push({ minPriceSyp: { lte: new Prisma.Decimal(brief.budgetMax * headroom) } });
    }
    if (brief.budgetMin !== null && !relax.dropBudget) {
      and.push({ maxPriceSyp: { gte: new Prisma.Decimal(brief.budgetMin) } });
    }

    // ── Size ────────────────────────────────────────────────────────────
    // Not "the product comes in M" but "somebody has an M in stock" — the
    // stock is on the offer's variant, not on the canonical variant, so an
    // in-stock check has to reach all the way through.
    if (!relax.sizes) {
      const size = this.sizeFor(brief, slot);
      if (size) {
        and.push({
          offers: {
            some: {
              ...LIVE_OFFER_WHERE,
              variants: {
                some: {
                  stock: { gt: 0 },
                  variant: { attributes: { path: ['size'], equals: size } },
                },
              },
            },
          },
        });
      }
    }

    // ── Colour ──────────────────────────────────────────────────────────
    if (!relax.colours && brief.colours.length) {
      const clauses = brief.colours.flatMap((key) => this.colourClauses(key));
      if (clauses.length) and.push({ OR: clauses });
    }

    // A colour she ruled out is not a preference to be scored down; it is a
    // refusal, and it holds at every rung of the ladder.
    for (const key of brief.avoidColours) {
      const clauses = this.colourClauses(key);
      if (clauses.length) and.push({ NOT: { OR: clauses } });
    }

    // ── Free text ───────────────────────────────────────────────────────
    if (!relax.keywords && brief.keywords.length) {
      and.push({
        OR: brief.keywords.flatMap((keyword) => [
          { title: { contains: keyword, mode: Prisma.QueryMode.insensitive } },
          { description: { contains: keyword, mode: Prisma.QueryMode.insensitive } },
        ]),
      });
    }

    // ── Deadline ────────────────────────────────────────────────────────
    // A seller who needs four days to hand the parcel over cannot serve a
    // "بعد يومين". Made-to-order goods are excluded outright at short notice.
    if (brief.deadlineDays !== null && brief.deadlineDays <= 3) {
      and.push({
        offers: {
          some: {
            ...LIVE_OFFER_WHERE,
            isMadeToOrder: false,
            handlingDays: { lte: Math.max(1, brief.deadlineDays) },
          },
        },
      });
    }

    return { AND: and };
  }

  /**
   * Where a colour can be found on a row.
   *
   * Three places, because sellers record colour in three ways and all of them
   * are legitimate: as a variant attribute (`{ colour: "أسود" }`), inside the
   * title ("بلون الأسود اللامع"), and in the description. Matching only the
   * structured field would miss most of the catalog.
   */
  private colourClauses(key: string): Prisma.ProductWhereInput[] {
    const entry = colourEntry(key);
    if (!entry) return [];

    // Arabic forms only for text matching: a bare "gold" or "red" would hit
    // English words in a description that are not about colour at all.
    const arabicForms = entry.forms.filter((form) => /[؀-ۿ]/.test(form));

    return [
      {
        variants: {
          some: {
            OR: entry.forms.map((form) => ({
              attributes: { path: ['colour'], equals: form },
            })),
          },
        },
      },
      ...arabicForms.map(
        (form): Prisma.ProductWhereInput => ({
          title: { contains: form, mode: Prisma.QueryMode.insensitive },
        }),
      ),
      ...arabicForms.map(
        (form): Prisma.ProductWhereInput => ({
          description: { contains: form, mode: Prisma.QueryMode.insensitive },
        }),
      ),
    ];
  }

  /** Which of her sizes applies to what is being searched for. */
  private sizeFor(brief: StyleBrief, slot?: OutfitSlot): string | null {
    const slots = slot ? [slot] : brief.slots;
    const wantsShoes = slots.includes(OutfitSlot.SHOES);
    const wantsClothing = slots.some((candidate) =>
      SIZED_AS_CLOTHING.includes(candidate),
    );

    if (wantsShoes && !wantsClothing) return brief.sizes.shoes ?? null;
    if (wantsClothing) return brief.sizes.clothing ?? null;
    // Mixed or unstated: filtering on a size we are not sure applies would
    // silently exclude every bag and every perfume.
    return null;
  }

  private explain(code: RelaxationCode, brief: StyleBrief): string {
    switch (code) {
      case 'BUDGET_RAISED':
        return brief.budgetMax !== null
          ? `ما لقيت خيارات كافية تحت ${formatSyp(brief.budgetMax)}، فوسّعت الميزانية شوي.`
          : 'وسّعت نطاق السعر شوي حتى ألاقي خيارات مناسبة.';
      case 'BUDGET_DROPPED':
        return brief.budgetMax !== null
          ? `ما في ولا قطعة بهالقسم تحت ${formatSyp(brief.budgetMax)} — هي أرخص الخيارات المتوفرة، حتى تكوني بالصورة.`
          : 'عرضتلك أرخص المتوفر بهالقسم.';
      case 'SIZE_DROPPED':
        return 'المقاس اللي طلبتيه مو متوفر بكل القطع، فعرضت قطع قريبة كمان.';
      case 'COLOUR_DROPPED':
        return 'اللون المطلوب محدود حاليًا، فضفت ألوان بتنسّق معه.';
      case 'CATEGORY_WIDENED':
        return 'وسّعت البحث لأقسام قريبة حتى يكون عندك خيارات أكتر.';
      case 'KEYWORDS_DROPPED':
        return 'خفّفت التفاصيل الدقيقة شوي حتى ما تضيع عليكِ خيارات حلوة.';
    }
  }
}

/** The slots measured by the clothing chart rather than the shoe one. */
const SIZED_AS_CLOTHING: readonly OutfitSlot[] = [
  OutfitSlot.DRESS,
  OutfitSlot.ABAYA,
  OutfitSlot.TOP,
  OutfitSlot.BOTTOM,
  OutfitSlot.OUTERWEAR,
];

interface RelaxedConstraints {
  keywords?: boolean;
  colours?: boolean;
  sizes?: boolean;
  /** Multiplier applied to the budget ceiling; 1.25 = 25% headroom. */
  budget?: number;
  /** Ignores the budget entirely — the last rung, and always reported. */
  dropBudget?: boolean;
  widenCategories?: boolean;
}
