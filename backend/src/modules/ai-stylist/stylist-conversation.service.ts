import {
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  AiStylistConversation,
  AiStylistConversationStatus,
  AiStylistFeedback,
  AiStylistMessage,
  AiStylistModality,
  AiStylistOutfitStatus,
  AiStylistRole,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  PRODUCT_CARD_INCLUDE,
  ProductRecord,
  defaultOffer,
} from '../../common/catalog/product-include';
import { Inject } from '@nestjs/common';
import { STYLIST_LLM, StylistLlm } from './llm/stylist-llm';
import { BuiltOutfit, OutfitBuilderService } from './outfit/outfit-builder.service';
import { StylePreferenceService } from './preferences/style-preference.service';
import { StyleProfile } from './preferences/style-profile';
import { ProductRetrievalService, Relaxation } from './retrieval/product-retrieval.service';
import { ScoredProduct, rankProducts, renderReason } from './retrieval/stylist-ranker';
import {
  ComposedReply,
  composeConversationalReply,
  composeOutfitReply,
  composeProductReply,
} from './reply/reply-composer';
import { BriefExtractorService } from './understanding/brief-extractor.service';
import {
  StyleBrief,
  briefFromJson,
  briefIsActionable,
  briefToJson,
  emptyBrief,
  missingSlotQuestion,
} from './understanding/style-brief';
import { formatSyp } from './understanding/style-brief';
import { applyPriceRefinement, detectRefinement } from './understanding/refinement';
import { adviceFor } from './reply/style-advice';

export interface StylistTurn {
  conversation: AiStylistConversation;
  userMessage: AiStylistMessage;
  assistantMessage: AiStylistMessage;
  brief: StyleBrief;
  recommendations: Array<{
    row: Prisma.AiStylistRecommendationGetPayload<object>;
    product: ProductRecord;
  }>;
  outfitId: string | null;
  followUps: string[];
}

/**
 * One turn of conversation, end to end.
 *
 * The pipeline is fixed and each stage has exactly one job:
 *
 *   understand → retrieve → rank → assemble → persist → phrase
 *
 * Note where phrasing sits: last, after the products are already chosen and
 * written down. Nothing downstream of retrieval can change which goods she is
 * shown, which is the property that makes this an assistant over a real
 * catalog rather than a chatbot that talks about shopping.
 */
@Injectable()
export class StylistConversationService {
  private readonly logger = new Logger(StylistConversationService.name);

  /** Cards per answer. Enough to choose from, few enough to read. */
  private static readonly RESULT_LIMIT = 6;
  /** Turns of history handed to the extractor for follow-up resolution. */
  private static readonly HISTORY_TURNS = 6;

  constructor(
    private readonly prisma: PrismaService,
    private readonly extractor: BriefExtractorService,
    private readonly retrieval: ProductRetrievalService,
    private readonly outfits: OutfitBuilderService,
    private readonly preferences: StylePreferenceService,
    @Inject(STYLIST_LLM) private readonly llm: StylistLlm,
  ) {}

  // ── Conversations ─────────────────────────────────────────────────────

  async startConversation(userId: string, title?: string): Promise<AiStylistConversation> {
    return this.prisma.aiStylistConversation.create({
      data: { userId, title: title?.trim() || null },
    });
  }

  async listConversations(userId: string, limit = 20) {
    return this.prisma.aiStylistConversation.findMany({
      where: { userId, status: AiStylistConversationStatus.ACTIVE },
      orderBy: [{ lastMessageAt: 'desc' }, { createdAt: 'desc' }],
      take: limit,
    });
  }

  async requireConversation(
    userId: string,
    conversationId: string,
  ): Promise<AiStylistConversation> {
    const conversation = await this.prisma.aiStylistConversation.findUnique({
      where: { id: conversationId },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    if (conversation.userId !== userId) {
      // Not a 404: the row exists and the caller is authenticated, so the
      // honest answer is that it is not hers.
      throw new ForbiddenException('This conversation belongs to another account');
    }
    return conversation;
  }

  async archiveConversation(userId: string, conversationId: string): Promise<void> {
    await this.requireConversation(userId, conversationId);
    await this.prisma.aiStylistConversation.update({
      where: { id: conversationId },
      data: { status: AiStylistConversationStatus.ARCHIVED },
    });
  }

  async messages(userId: string, conversationId: string) {
    await this.requireConversation(userId, conversationId);
    return this.prisma.aiStylistMessage.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'asc' },
      take: 100,
    });
  }

  // ── The turn ──────────────────────────────────────────────────────────

  async sendMessage(input: {
    userId: string;
    conversationId?: string;
    content: string;
    modality?: AiStylistModality;
  }): Promise<StylistTurn> {
    const startedAt = Date.now();

    const conversation = input.conversationId
      ? await this.requireConversation(input.userId, input.conversationId)
      : await this.startConversation(input.userId);

    const [history, profile, shown] = await Promise.all([
      this.recentTurns(conversation.id),
      this.preferences.buildProfile(input.userId),
      this.shownSoFar(conversation.id),
    ]);

    const currentBrief = this.seedBrief(conversation, profile);

    // 1 — Understand.
    const extraction = await this.extractor.extract({
      message: input.content,
      currentBrief,
      history,
    });
    // "أرخص" and "كمان" only mean something against the last answer, so
    // they are read against it here rather than by the sentence parser.
    const refinement = detectRefinement(input.content);
    const brief = applyPriceRefinement(extraction.brief, refinement, shown.lastPrices);

    // 2 — Answer it out of the catalog.
    const answer = await this.answer(brief, profile, {
      exclude: refinement.more ? shown.productIds : new Set<string>(),
    });

    // 3 — Write everything down before phrasing anything, so the reply is
    //     rendered from what was actually stored.
    const userMessage = await this.prisma.aiStylistMessage.create({
      data: {
        conversationId: conversation.id,
        role: AiStylistRole.USER,
        modality: input.modality ?? AiStylistModality.TEXT,
        content: input.content.trim(),
        brief: briefToJson({ ...emptyBrief(), ...extraction.turnBrief }),
      },
    });

    // 4 — Phrase.
    const reply = await this.phrase(input.content, brief, answer, history);

    const assistantMessage = await this.prisma.aiStylistMessage.create({
      data: {
        conversationId: conversation.id,
        role: AiStylistRole.ASSISTANT,
        content: reply.text,
        brief: briefToJson(brief),
        engine: extraction.engine,
        latencyMs: Date.now() - startedAt,
      },
    });

    // 5 — Persist the cards and the look, bound to the assistant turn.
    const recommendations = await this.persistRecommendations({
      userId: input.userId,
      conversationId: conversation.id,
      messageId: assistantMessage.id,
      results: answer.results,
      brief,
    });

    const outfitId = answer.outfit
      ? await this.persistOutfit({
          userId: input.userId,
          conversationId: conversation.id,
          messageId: assistantMessage.id,
          outfit: answer.outfit,
        })
      : null;

    const updated = await this.prisma.aiStylistConversation.update({
      where: { id: conversation.id },
      data: {
        brief: briefToJson(brief),
        messagesCount: { increment: 2 },
        lastMessageAt: new Date(),
        // The first thing she said names the thread, trimmed to a line.
        ...(conversation.title ? {} : { title: this.titleFrom(input.content) }),
      },
    });

    // Learning is a side effect of the turn, never a condition of it: a
    // failure to remember must not cost her the answer she is waiting for.
    void this.preferences
      .learnFromBrief(input.userId, brief)
      .catch((error) =>
        this.logger.warn(`Could not update style preferences: ${String(error)}`),
      );

    return {
      conversation: updated,
      userMessage,
      assistantMessage,
      brief,
      recommendations,
      outfitId,
      followUps: reply.followUps,
    };
  }

  /**
   * Turns a brief into products — or into a look, when that is what she asked
   * for. The only place the two paths meet.
   */
  private async answer(
    brief: StyleBrief,
    profile: StyleProfile,
    options: { exclude: ReadonlySet<string> } = { exclude: new Set() },
  ): Promise<StylistAnswer> {
    if (brief.intent === 'SMALL_TALK' || !briefIsActionable(brief)) {
      return { kind: 'conversation', results: [], outfit: null, relaxations: [] };
    }

    if (brief.intent === 'BUILD_OUTFIT') {
      const outfit = await this.outfits.build(brief, profile);
      if (outfit) {
        return {
          kind: 'outfit',
          outfit,
          // The pieces are the cards. Rendering them through the same
          // recommendation rows means "أعجبني" works identically whether she
          // tapped a list item or a piece of a look.
          results: outfit.pieces.map((piece) => ({
            product: piece.product,
            score: piece.score,
            reasons: [],
            dominantColour: null,
            slot: piece.slot,
            reasonText: piece.reason,
            reasonCodes: piece.reasonCodes,
          })),
          relaxations: outfit.relaxations,
        };
      }
      // Nothing could be assembled; fall through to a plain product answer
      // rather than telling her the catalog is empty when it is not.
    }

    const retrieved = await this.retrieval.retrieve(brief);
    // "وريني المزيد": leave out what is already on her screen — unless that
    // would leave nothing, in which case the same rail beats an empty answer.
    const fresh = retrieved.candidates.filter(
      (candidate) => !options.exclude.has(candidate.id),
    );
    const ranked = rankProducts(
      fresh.length ? fresh : retrieved.candidates,
      { brief, profile, diversity: { perCategory: 3, perSeller: 2 } },
      StylistConversationService.RESULT_LIMIT,
    );

    return {
      kind: 'products',
      outfit: null,
      relaxations: retrieved.relaxations,
      results: ranked.map((entry) => ({
        ...entry,
        slot: brief.slots[0] ?? null,
        reasonText: renderReason(entry, brief),
        reasonCodes: entry.reasons,
      })),
    };
  }

  /**
   * Writes the sentence.
   *
   * The deterministic composer runs first and its output is the fallback, so
   * a model that is slow, down, or misconfigured costs her nothing. When one
   * does answer, it is given only the facts already fixed above.
   */
  private async phrase(
    message: string,
    brief: StyleBrief,
    answer: StylistAnswer,
    history: Array<{ role: 'user' | 'assistant'; content: string }> = [],
  ): Promise<ComposedReply> {
    const advice = adviceFor(brief, message);
    const deterministic =
      answer.kind === 'conversation'
        ? composeConversationalReply({
            brief,
            greeting: brief.intent === 'SMALL_TALK',
            message,
            advice,
          })
        : answer.kind === 'outfit' && answer.outfit
          ? composeOutfitReply({ brief, outfit: answer.outfit })
          : composeProductReply({
              brief,
              results: answer.results,
              relaxations: answer.relaxations,
              advice,
            });

    // Greetings and thanks are better from the templates; an opinion question
    // is where a model earns its place, even with no cards to talk about.
    const wantsAdvice = brief.intent === 'ADVICE';
    if (!this.llm.enabled) return deterministic;
    if (answer.kind === 'conversation' && !wantsAdvice) return deterministic;

    try {
      const text = await this.llm.composeReply({
        mode:
          answer.kind === 'conversation'
            ? 'advice'
            : answer.kind === 'outfit'
              ? 'outfit'
              : 'products',
        message,
        history,
        advice,
        brief,
        products: answer.results.map((entry) => {
          const offer = defaultOffer(entry.product);
          const price = entry.product.minPriceSyp
            ? formatSyp(Number(entry.product.minPriceSyp))
            : 'السعر غير محدد';
          return {
            title: entry.product.title,
            priceLabel: price,
            sellerName: offer?.seller.name ?? 'بائعة على أوهارا',
            reason: entry.reasonText,
            inStock: (offer?.stock ?? 0) > 0,
          };
        }),
        relaxations: answer.relaxations.map((relaxation) => relaxation.message),
        followUp: missingSlotQuestion(brief),
        outfitTitle: answer.outfit?.title ?? null,
      });

      return text ? { text, followUps: deterministic.followUps } : deterministic;
    } catch (error) {
      this.logger.warn(`Reply composition failed: ${String(error)}`);
      return deterministic;
    }
  }

  // ── Persistence ───────────────────────────────────────────────────────

  private async persistRecommendations(input: {
    userId: string;
    conversationId: string;
    messageId: string;
    results: AnsweredProduct[];
    brief: StyleBrief;
  }) {
    if (!input.results.length) return [];

    const rows = await this.prisma.$transaction(
      input.results.map((entry, position) =>
        this.prisma.aiStylistRecommendation.create({
          data: {
            userId: input.userId,
            conversationId: input.conversationId,
            messageId: input.messageId,
            productId: entry.product.id,
            offerId: defaultOffer(entry.product)?.id ?? null,
            slot: entry.slot,
            score: entry.score,
            position,
            reason: entry.reasonText,
            reasonCodes: entry.reasonCodes,
            quotedPriceSyp: entry.product.minPriceSyp ?? null,
          },
        }),
      ),
    );

    return rows.map((row, index) => ({
      row,
      product: input.results[index].product,
    }));
  }

  private async persistOutfit(input: {
    userId: string;
    conversationId: string;
    messageId: string;
    outfit: BuiltOutfit;
  }): Promise<string> {
    const created = await this.prisma.aiStylistOutfit.create({
      data: {
        userId: input.userId,
        conversationId: input.conversationId,
        messageId: input.messageId,
        title: input.outfit.title,
        occasion: input.outfit.occasion,
        note: input.outfit.note,
        palette: input.outfit.palette,
        totalSyp: input.outfit.totalSyp,
        items: {
          create: input.outfit.pieces.map((piece, position) => ({
            slot: piece.slot,
            productId: piece.product.id,
            offerId: piece.offerId,
            priceSyp: piece.priceSyp,
            reason: piece.reason,
            position,
          })),
        },
      },
    });
    return created.id;
  }

  // ── Outfits ───────────────────────────────────────────────────────────

  async buildOutfit(userId: string, brief: StyleBrief) {
    const profile = await this.preferences.buildProfile(userId);
    const outfit = await this.outfits.build(brief, profile);
    if (!outfit) return null;

    const id = await this.persistOutfitStandalone(userId, outfit);
    return this.findOutfit(userId, id);
  }

  private async persistOutfitStandalone(
    userId: string,
    outfit: BuiltOutfit,
  ): Promise<string> {
    const created = await this.prisma.aiStylistOutfit.create({
      data: {
        userId,
        title: outfit.title,
        occasion: outfit.occasion,
        note: outfit.note,
        palette: outfit.palette,
        totalSyp: outfit.totalSyp,
        items: {
          create: outfit.pieces.map((piece, position) => ({
            slot: piece.slot,
            productId: piece.product.id,
            offerId: piece.offerId,
            priceSyp: piece.priceSyp,
            reason: piece.reason,
            position,
          })),
        },
      },
    });
    return created.id;
  }

  async listOutfits(userId: string, status?: AiStylistOutfitStatus) {
    return this.prisma.aiStylistOutfit.findMany({
      where: { userId, ...(status ? { status } : {}) },
      include: { items: true },
      orderBy: { createdAt: 'desc' },
      take: 40,
    });
  }

  async findOutfit(userId: string, outfitId: string) {
    const outfit = await this.prisma.aiStylistOutfit.findUnique({
      where: { id: outfitId },
      include: { items: true },
    });
    if (!outfit) throw new NotFoundException('Outfit not found');
    if (outfit.userId !== userId) {
      throw new ForbiddenException('This outfit belongs to another account');
    }
    return outfit;
  }

  async setOutfitStatus(
    userId: string,
    outfitId: string,
    status: AiStylistOutfitStatus,
  ) {
    await this.findOutfit(userId, outfitId);
    return this.prisma.aiStylistOutfit.update({
      where: { id: outfitId },
      data: { status },
      include: { items: true },
    });
  }

  /** Loads the products behind a set of outfits, for the serializer. */
  async productsFor(productIds: string[]): Promise<Map<string, ProductRecord>> {
    if (!productIds.length) return new Map();
    const products = await this.prisma.product.findMany({
      where: { id: { in: [...new Set(productIds)] } },
      include: PRODUCT_CARD_INCLUDE,
    });
    return new Map(products.map((product) => [product.id, product]));
  }

  // ── Feedback ──────────────────────────────────────────────────────────

  /**
   * Records what she did with a card.
   *
   * Two writes, on purpose: the recommendation row remembers what happened to
   * *that card* (so the quality of a given answer can be measured later), and
   * the signal row feeds her profile (so the next answer is better). Collapsing
   * them would lose one of the two questions.
   */
  async recordFeedback(input: {
    userId: string;
    recommendationId: string;
    feedback: AiStylistFeedback;
  }) {
    const recommendation = await this.prisma.aiStylistRecommendation.findUnique({
      where: { id: input.recommendationId },
    });
    if (!recommendation) throw new NotFoundException('Recommendation not found');
    if (recommendation.userId !== input.userId) {
      throw new ForbiddenException('This recommendation belongs to another account');
    }

    const [updated] = await Promise.all([
      this.prisma.aiStylistRecommendation.update({
        where: { id: input.recommendationId },
        data: { feedback: input.feedback, feedbackAt: new Date() },
      }),
      this.preferences.recordFeedback({
        userId: input.userId,
        productId: recommendation.productId,
        feedback: input.feedback,
        recommendationId: recommendation.id,
      }),
    ]);

    return updated;
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /**
   * What this conversation has already put in front of her: every product id
   * (so "كمان" can leave them out) and the prices of the last answer (so
   * "أرخص" has something to be cheaper than).
   */
  private async shownSoFar(conversationId: string) {
    const rows = await this.prisma.aiStylistRecommendation.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'desc' },
      take: 60,
      select: { productId: true, messageId: true, quotedPriceSyp: true },
    });
    const lastMessageId = rows[0]?.messageId ?? null;
    return {
      productIds: new Set(rows.map((row) => row.productId)),
      lastPrices: rows
        .filter((row) => row.messageId === lastMessageId && row.quotedPriceSyp !== null)
        .map((row) => Number(row.quotedPriceSyp)),
    };
  }

  private async recentTurns(conversationId: string) {
    const rows = await this.prisma.aiStylistMessage.findMany({
      where: { conversationId, role: { in: [AiStylistRole.USER, AiStylistRole.ASSISTANT] } },
      orderBy: { createdAt: 'desc' },
      take: StylistConversationService.HISTORY_TURNS,
      select: { role: true, content: true },
    });
    return rows.reverse().map((row) => ({
      role: row.role === AiStylistRole.USER ? ('user' as const) : ('assistant' as const),
      content: row.content,
    }));
  }

  /**
   * The brief a turn starts from.
   *
   * A fresh conversation starts from what she has already told the app about
   * herself — her size, her modesty setting, her budget band — so the first
   * message does not have to restate them. An ongoing one continues from
   * where it left off.
   */
  private seedBrief(
    conversation: AiStylistConversation,
    profile: StyleProfile,
  ): StyleBrief {
    if (conversation.brief) return briefFromJson(conversation.brief);

    const brief = emptyBrief();
    // Not seeded from her saved preferences any more: the setting was taken
    // out of «ذوقك», and a value saved before then would otherwise go on
    // steering results with nothing on screen to change it. What she asks
    // for in the conversation itself still counts.
    brief.personas = profile.personas.slice(0, 2);
    brief.sizes = { ...profile.sizes };
    brief.budgetMin = profile.budgetMinSyp;
    brief.budgetMax = profile.budgetMaxSyp;
    return brief;
  }

  private titleFrom(message: string): string {
    const trimmed = message.trim().replace(/\s+/g, ' ');
    return trimmed.length > 60 ? `${trimmed.slice(0, 57)}…` : trimmed;
  }
}

interface AnsweredProduct extends Omit<ScoredProduct, 'reasons'> {
  reasons: ScoredProduct['reasons'];
  slot: import('@prisma/client').OutfitSlot | null;
  reasonText: string;
  reasonCodes: string[];
}

interface StylistAnswer {
  kind: 'products' | 'outfit' | 'conversation';
  results: AnsweredProduct[];
  outfit: BuiltOutfit | null;
  relaxations: Relaxation[];
}
