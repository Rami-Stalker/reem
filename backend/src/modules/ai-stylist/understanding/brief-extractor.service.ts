import { Inject, Injectable } from '@nestjs/common';
import { ModestyLevel, OutfitSlot } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { STYLIST_LLM, StylistLlm } from '../llm/stylist-llm';
import {
  StyleBrief,
  StylistIntent,
  emptyBrief,
  mergeBriefs,
  sanitiseBrief,
} from './style-brief';
import {
  categorySlugsForSlots,
  detectBudget,
  detectColourHits,
  detectColours,
  detectDeadlineDays,
  detectMaterials,
  detectModesty,
  detectOccasion,
  detectPersonas,
  detectRecipientAge,
  detectSizes,
  detectSlots,
  looksLikeGift,
  looksLikeOutfit,
  occasionEntry,
  residualKeywords,
  searchable,
  slotForCategorySlug,
} from './stylist-lexicon';

export interface ExtractionResult {
  /** The conversation's brief after this turn. */
  brief: StyleBrief;
  /** What this turn alone contributed — stored on the message row. */
  turnBrief: Partial<StyleBrief>;
  /** Which reader produced it: the rules, or the rules plus a model. */
  engine: string;
}

/**
 * Turns a sentence into a brief.
 *
 * The rules run first and always. When a model is configured it runs after,
 * and its proposals are layered *over* the rules result — but only after
 * `sanitiseBrief` has dropped everything outside the closed vocabularies, and
 * only for fields the model actually filled. So the model can improve a
 * reading; it cannot replace one with nonsense, and it cannot make the feature
 * stop working by being unavailable.
 */
@Injectable()
export class BriefExtractorService {
  /** Leaf slugs, cached for the process — the taxonomy changes rarely. */
  private categorySlugCache: { slugs: Set<string>; at: number } | null = null;
  private static readonly CATEGORY_TTL_MS = 5 * 60 * 1000;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(STYLIST_LLM) private readonly llm: StylistLlm,
  ) {}

  async extract(input: {
    message: string;
    currentBrief: StyleBrief;
    history: Array<{ role: 'user' | 'assistant'; content: string }>;
  }): Promise<ExtractionResult> {
    const knownCategorySlugs = await this.knownCategorySlugs();
    const ruleBrief = this.readWithRules(input.message, input.currentBrief);

    let turnBrief = ruleBrief;
    let engine = this.llm.name;

    if (this.llm.enabled) {
      const proposal = await this.llm.extractBrief({
        message: input.message,
        history: input.history,
        currentBrief: input.currentBrief,
        ruleBrief,
      });
      const sanitised = sanitiseBrief(proposal, { knownCategorySlugs });
      if (Object.keys(sanitised).length) {
        turnBrief = this.combine(ruleBrief, sanitised);
      } else {
        // The model answered with nothing usable. Say so in the row rather
        // than claiming it contributed.
        engine = `${this.llm.name}+fallback`;
      }
    }

    // Slots and categories are two views of the same decision, and either one
    // may have been the one that got filled. Reconcile before merging so the
    // retrieval layer never has to.
    turnBrief = this.reconcileSlotsAndCategories(turnBrief, knownCategorySlugs);

    const brief = mergeBriefs(input.currentBrief, turnBrief);
    return { brief: this.applyOccasionDefaults(brief), turnBrief, engine };
  }

  /**
   * The deterministic reader.
   *
   * Every field comes from `stylist-lexicon`, so a value here is by
   * construction one the catalog can be queried for.
   */
  readWithRules(message: string, currentBrief: StyleBrief): Partial<StyleBrief> {
    const turn: Partial<StyleBrief> = {};
    let signals = 0;

    const occasion = detectOccasion(message);
    if (occasion) {
      turn.occasion = occasion;
      signals += 1;
    }

    const slots = detectSlots(message);
    if (slots.length) {
      turn.slots = slots;
      signals += 1;
    }

    const budget = detectBudget(message);
    if (budget) {
      if (budget.min !== undefined) turn.budgetMin = budget.min;
      if (budget.max !== undefined) turn.budgetMax = budget.max;
      signals += 1;
    }

    const colours = detectColours(message);
    if (colours.length) {
      // "بدون أسود" / "ما بحب الأحمر" — the same word, the opposite meaning.
      const [wanted, avoided] = this.splitNegatedColours(message);
      if (wanted.length) turn.colours = wanted;
      if (avoided.length) turn.avoidColours = avoided;
      signals += 1;
    }

    const sizes = detectSizes(message);
    if (Object.keys(sizes).length) {
      turn.sizes = sizes;
      signals += 1;
    }

    const modesty = detectModesty(message);
    if (modesty) {
      turn.modesty = modesty;
      signals += 1;
    }

    const personas = detectPersonas(message);
    if (personas.length) {
      turn.personas = personas;
      signals += 1;
    }

    const materials = detectMaterials(message);
    if (materials.length) {
      turn.materials = materials;
      signals += 1;
    }

    const age = detectRecipientAge(message);
    if (age !== null) {
      turn.recipientAge = age;
      signals += 1;
    }

    const deadline = detectDeadlineDays(message);
    if (deadline !== null) {
      turn.deadlineDays = deadline;
      signals += 1;
    }

    const gift = looksLikeGift(message);
    if (gift) {
      turn.forSelf = false;
      signals += 1;
    }

    turn.intent = this.readIntent(message, {
      gift,
      slots: slots.length ? slots : currentBrief.slots,
      signals,
    });

    turn.keywords = residualKeywords(message);

    // Confidence is the share of the message we can account for, not the
    // model's opinion of itself. Six signals is a fully specified request.
    turn.confidence = Math.min(1, signals / 6);

    return turn;
  }

  private readIntent(
    message: string,
    context: { gift: boolean; slots: OutfitSlot[]; signals: number },
  ): StylistIntent {
    if (context.gift) return 'FIND_GIFT';
    if (looksLikeOutfit(message)) return 'BUILD_OUTFIT';

    const advice =
      /شو رايك|شو رأيك|شو بتنصحي|انصحيني|نصيحة|نصيحه|ينفع|بليق|بيليق|يليق|بيلبق|يلبق|يناسب|بيناسب|يتناسق|بيمشي مع|شو بلبس|شو ألبس|شو البس|ماذا ألبس|هل تنصحين|what do you think|what goes with/i;
    // An opinion question is answered as one even mid-conversation; when the
    // brief is actionable the cards still come, under the advice.
    if (advice.test(message)) return 'ADVICE';

    // Not `\b`: in JavaScript a word boundary only exists next to an ASCII
    // letter, so `/^مرحبا\b/` never matched an Arabic greeting at all.
    const smallTalk =
      /^(?:مرحبا|مرحباً|هلا|هلو|اهلين|أهلين|السلام|سلام|صباح|مساء|شكرا|شكراً|مشكورة|يسلمو|hi|hello|hey|thanks)(?=[\s!.,،؟?]|$)/i;
    if (smallTalk.test(message.trim()) && context.signals === 0) return 'SMALL_TALK';

    const refine = /كمان|غير|بدل|ارخص|أرخص|اغلى|أغلى|ثاني|تانيه|شي تاني|بس/i;
    if (refine.test(message) && context.signals <= 2) return 'REFINE';

    return 'FIND_PRODUCT';
  }

  /**
   * Splits "بدي فستان أسود بدون أحمر" into wanted and avoided.
   *
   * Works off the colour's actual offset in the normalised text, because a
   * negation binds to the colour immediately after it and nothing else. The
   * window is deliberately short — widen it and "بدون أكمام… وأسود" starts
   * ruling out the colour she asked for.
   */
  private splitNegatedColours(message: string): [string[], string[]] {
    const hay = searchable(message);
    const wanted: string[] = [];
    const avoided: string[] = [];
    const negators = /(?:بدون|بلا|ما بحب|ما احب|مو|ليس|غير|except|without|no|not)\s*$/;

    for (const hit of detectColourHits(message)) {
      const prefix = hay.slice(Math.max(0, hit.index - 18), hit.index);
      if (negators.test(prefix)) avoided.push(hit.key);
      else wanted.push(hit.key);
    }
    return [wanted, avoided];
  }

  /**
   * Keeps `slots` and `categorySlugs` telling the same story.
   *
   * A turn may name a slot ("حقيبة"), a category ("handbags"), or both, and
   * the two are equivalent statements about what she wants. Deriving each from
   * the other here means retrieval reads one field and ranking reads the
   * other, without either having to know they are the same thing.
   */
  private reconcileSlotsAndCategories(
    turn: Partial<StyleBrief>,
    knownCategorySlugs: ReadonlySet<string>,
  ): Partial<StyleBrief> {
    const next = { ...turn };

    if (next.slots?.length && !next.categorySlugs?.length) {
      const slugs = categorySlugsForSlots(next.slots).filter((slug) =>
        knownCategorySlugs.has(slug),
      );
      if (slugs.length) next.categorySlugs = slugs;
    }

    if (next.categorySlugs?.length && !next.slots?.length) {
      const slots = next.categorySlugs
        .map(slotForCategorySlug)
        .filter((slot): slot is OutfitSlot => slot !== null);
      if (slots.length) next.slots = [...new Set(slots)];
    }

    return next;
  }

  /**
   * Fills what the occasion implies but she did not say.
   *
   * Only ever fills blanks — a stated modesty or an explicitly chosen slot is
   * never overwritten by an inference. Asking for a dress for رمضان and being
   * shown only abayas would be the assistant deciding it knows better.
   */
  private applyOccasionDefaults(brief: StyleBrief): StyleBrief {
    const occasion = occasionEntry(brief.occasion);
    if (!occasion) return brief;

    const next = { ...brief };

    if (!next.slots.length) {
      next.slots = [...occasion.slots];
      next.categorySlugs = next.categorySlugs.length
        ? next.categorySlugs
        : categorySlugsForSlots(next.slots);
    }

    if (next.modesty === ModestyLevel.UNSPECIFIED && occasion.modestyHint) {
      next.modesty = occasion.modestyHint;
    }

    if (!next.personas.length && occasion.personaHints.length) {
      next.personas = [...occasion.personaHints].slice(0, 2);
    }

    if (occasion.extraCategorySlugs?.length && next.intent === 'FIND_GIFT') {
      next.categorySlugs = [
        ...new Set([...occasion.extraCategorySlugs, ...next.categorySlugs]),
      ];
    }

    return next;
  }

  /**
   * Overlays a validated model proposal on the rules reading.
   *
   * The rules keep the fields they are simply better at — a number written in
   * Arabic words, a size, a deadline — because those are exact string
   * problems, and a model that "helpfully" rounds a budget to 500,000 has
   * changed what she asked for. The model keeps the fields that need
   * judgement: intent, occasion, what she is actually shopping for, and taste.
   */
  private combine(
    ruleBrief: Partial<StyleBrief>,
    modelBrief: Partial<StyleBrief>,
  ): Partial<StyleBrief> {
    const combined: Partial<StyleBrief> = { ...ruleBrief };

    if (modelBrief.intent) combined.intent = modelBrief.intent;
    if (modelBrief.occasion && !ruleBrief.occasion) {
      combined.occasion = modelBrief.occasion;
    }
    if (modelBrief.slots?.length && !ruleBrief.slots?.length) {
      combined.slots = modelBrief.slots;
    }
    if (modelBrief.categorySlugs?.length && !ruleBrief.categorySlugs?.length) {
      combined.categorySlugs = modelBrief.categorySlugs;
    }
    if (modelBrief.colours?.length && !ruleBrief.colours?.length) {
      combined.colours = modelBrief.colours;
    }
    if (modelBrief.avoidColours?.length && !ruleBrief.avoidColours?.length) {
      combined.avoidColours = modelBrief.avoidColours;
    }
    if (modelBrief.personas?.length) {
      combined.personas = [
        ...new Set([...(ruleBrief.personas ?? []), ...modelBrief.personas]),
      ].slice(0, 3);
    }
    if (modelBrief.materials?.length && !ruleBrief.materials?.length) {
      combined.materials = modelBrief.materials;
    }
    if (
      modelBrief.modesty &&
      modelBrief.modesty !== ModestyLevel.UNSPECIFIED &&
      (!ruleBrief.modesty || ruleBrief.modesty === ModestyLevel.UNSPECIFIED)
    ) {
      combined.modesty = modelBrief.modesty;
    }
    if (modelBrief.forSelf !== undefined && ruleBrief.forSelf === undefined) {
      combined.forSelf = modelBrief.forSelf;
    }
    if (
      modelBrief.recipientAge !== undefined &&
      ruleBrief.recipientAge === undefined
    ) {
      combined.recipientAge = modelBrief.recipientAge;
    }

    // Exact string reads stay with the rules: budget, sizes, deadline.
    if (ruleBrief.budgetMin === undefined && modelBrief.budgetMin !== undefined) {
      combined.budgetMin = modelBrief.budgetMin;
    }
    if (ruleBrief.budgetMax === undefined && modelBrief.budgetMax !== undefined) {
      combined.budgetMax = modelBrief.budgetMax;
    }
    if (!ruleBrief.sizes || !Object.keys(ruleBrief.sizes).length) {
      if (modelBrief.sizes && Object.keys(modelBrief.sizes).length) {
        combined.sizes = modelBrief.sizes;
      }
    }
    if (ruleBrief.deadlineDays === undefined && modelBrief.deadlineDays !== undefined) {
      combined.deadlineDays = modelBrief.deadlineDays;
    }

    if (modelBrief.keywords?.length) {
      combined.keywords = [
        ...new Set([...(ruleBrief.keywords ?? []), ...modelBrief.keywords]),
      ].slice(0, 10);
    }

    combined.confidence = Math.max(
      ruleBrief.confidence ?? 0,
      modelBrief.confidence ?? 0,
    );

    return combined;
  }

  /** The leaf slugs that actually exist, so a proposed one can be refused. */
  private async knownCategorySlugs(): Promise<Set<string>> {
    const cached = this.categorySlugCache;
    if (cached && Date.now() - cached.at < BriefExtractorService.CATEGORY_TTL_MS) {
      return cached.slugs;
    }
    const rows = await this.prisma.category.findMany({
      where: { isActive: true },
      select: { slug: true },
    });
    const slugs = new Set(rows.map((row) => row.slug));
    this.categorySlugCache = { slugs, at: Date.now() };
    return slugs;
  }

  /** A blank brief seeded with whatever her stored preferences already say. */
  static seedFromPreferences(preferences: {
    modesty: ModestyLevel;
    personas: StyleBrief['personas'];
    favouriteColours: string[];
    sizes: StyleBrief['sizes'];
    budgetMinSyp: number | null;
    budgetMaxSyp: number | null;
  }): StyleBrief {
    const brief = emptyBrief();
    brief.modesty = preferences.modesty;
    brief.personas = preferences.personas.slice(0, 2);
    brief.sizes = { ...preferences.sizes };
    brief.budgetMin = preferences.budgetMinSyp;
    brief.budgetMax = preferences.budgetMaxSyp;
    // Favourite colours seed the *profile* score, not the brief's colour
    // filter — she has not asked for them in this conversation, and filtering
    // on them would quietly hide the rest of the shop.
    return brief;
  }
}
