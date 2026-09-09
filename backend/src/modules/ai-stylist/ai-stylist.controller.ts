import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AiStylistOutfitStatus, ModestyLevel } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { PRODUCT_CARD_INCLUDE } from '../../common/catalog/product-include';
import { PrismaService } from '../../prisma/prisma.service';
import {
  serializeConversation,
  serializeOutfit,
  serializePreferences,
  serializeRecommendation,
  serializeStylistBrief,
  serializeStylistMessage,
} from './ai-stylist.serializer';
import {
  BuildOutfitDto,
  ConversationListDto,
  ListOutfitsDto,
  RecommendationFeedbackDto,
  RecommendationHistoryDto,
  OutfitStatusDto,
  SendStylistMessageDto,
  StartConversationDto,
  UpdatePreferencesDto,
} from './dto/ai-stylist.dto';
import { StylePreferenceService } from './preferences/style-preference.service';
import { StylistConversationService } from './stylist-conversation.service';
import { starterPrompts } from './reply/reply-composer';
import { emptyBrief, sanitiseBrief } from './understanding/style-brief';
import { COLOURS, OCCASIONS, SLOTS, slotLabel } from './understanding/stylist-lexicon';

/**
 * `/ai/stylist` — the conversational shopping assistant.
 *
 * Every route is authenticated. A stylist conversation is a record of what
 * someone told an assistant about her body, her budget and her occasions, and
 * that is not a thing to hang off an anonymous session token.
 */
@SelfScoped(
  "every conversation, outfit and recommendation is read and written through the caller's own id",
)
@Controller('ai/stylist')
export class AiStylistController {
  constructor(
    private readonly stylist: StylistConversationService,
    private readonly preferences: StylePreferenceService,
    private readonly prisma: PrismaService,
  ) {}

  // ── Conversations ─────────────────────────────────────────────────────

  @Get('conversations')
  async conversations(
    @CurrentUser('id') userId: string,
    @Query() dto: ConversationListDto,
  ) {
    const rows = await this.stylist.listConversations(userId, dto.limit);
    return rows.map((row) => serializeConversation(row));
  }

  @Post('conversations')
  async startConversation(
    @CurrentUser('id') userId: string,
    @Body() dto: StartConversationDto,
  ) {
    const conversation = await this.stylist.startConversation(userId, dto.title);
    if (!dto.message?.trim()) return serializeConversation(conversation);

    // "Open a thread and ask" is one action for her, so it is one request.
    const turn = await this.stylist.sendMessage({
      userId,
      conversationId: conversation.id,
      content: dto.message,
    });
    return this.renderTurn(turn);
  }

  @Get('conversations/:id')
  async conversation(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) conversationId: string,
  ) {
    const conversation = await this.stylist.requireConversation(userId, conversationId);
    const messages = await this.stylist.messages(userId, conversationId);

    // The cards belong to the assistant turns that produced them, so a
    // reopened thread looks exactly as it did when she left it.
    const recommendations = await this.prisma.aiStylistRecommendation.findMany({
      where: { conversationId },
      include: { product: { include: PRODUCT_CARD_INCLUDE } },
      orderBy: { position: 'asc' },
    });
    const outfits = await this.prisma.aiStylistOutfit.findMany({
      where: { conversationId },
      include: { items: true },
    });
    const products = await this.stylist.productsFor(
      outfits.flatMap((outfit) => outfit.items.map((item) => item.productId)),
    );

    return serializeConversation(conversation, {
      messages: messages.map((message) =>
        serializeStylistMessage(message, {
          recommendations: recommendations
            .filter((row) => row.messageId === message.id)
            .map((row) => serializeRecommendation({ row, product: row.product })),
          outfit: (() => {
            const outfit = outfits.find((row) => row.messageId === message.id);
            return outfit ? serializeOutfit({ row: outfit, products }) : null;
          })(),
        }),
      ),
    });
  }

  @Delete('conversations/:id')
  async archive(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) conversationId: string,
  ) {
    await this.stylist.archiveConversation(userId, conversationId);
    return { archived: true };
  }

  /**
   * The turn.
   *
   * Throttled well below the global limit: a turn runs a handful of catalog
   * queries and may call a paid provider, so it is one of the few endpoints
   * where a stuck client retrying is worth stopping early.
   */
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post('conversations/:id/messages')
  async sendMessage(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) conversationId: string,
    @Body() dto: SendStylistMessageDto,
  ) {
    const turn = await this.stylist.sendMessage({
      userId,
      conversationId,
      content: dto.content,
      modality: dto.modality,
    });
    return this.renderTurn(turn);
  }

  // ── Outfits ───────────────────────────────────────────────────────────

  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post('outfits')
  async buildOutfit(@CurrentUser('id') userId: string, @Body() dto: BuildOutfitDto) {
    const brief = {
      ...emptyBrief(),
      intent: 'BUILD_OUTFIT' as const,
      ...sanitiseBrief(dto),
    };
    const outfit = await this.stylist.buildOutfit(userId, brief);
    if (!outfit) {
      return {
        outfit: null,
        message: 'ما قدرت أركّب إطلالة كاملة بهالمواصفات — جرّبي توسّعي الميزانية أو تغيّري المناسبة.',
      };
    }
    const products = await this.stylist.productsFor(
      outfit.items.map((item) => item.productId),
    );
    return { outfit: serializeOutfit({ row: outfit, products }) };
  }

  @Get('outfits')
  async outfits(@CurrentUser('id') userId: string, @Query() dto: ListOutfitsDto) {
    const rows = await this.stylist.listOutfits(userId, dto.status);
    const products = await this.stylist.productsFor(
      rows.flatMap((row) => row.items.map((item) => item.productId)),
    );
    return rows.map((row) => serializeOutfit({ row, products }));
  }

  @Get('outfits/:id')
  async outfit(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) outfitId: string,
  ) {
    const row = await this.stylist.findOutfit(userId, outfitId);
    const products = await this.stylist.productsFor(
      row.items.map((item) => item.productId),
    );
    return serializeOutfit({ row, products });
  }

  @Patch('outfits/:id')
  async setOutfitStatus(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) outfitId: string,
    @Body() dto: OutfitStatusDto,
  ) {
    const row = await this.stylist.setOutfitStatus(userId, outfitId, dto.status);
    const products = await this.stylist.productsFor(
      row.items.map((item) => item.productId),
    );
    return serializeOutfit({ row, products });
  }

  // ── Feedback ──────────────────────────────────────────────────────────

  @Post('recommendations/:id/feedback')
  async feedback(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) recommendationId: string,
    @Body() dto: RecommendationFeedbackDto,
  ) {
    const row = await this.stylist.recordFeedback({
      userId,
      recommendationId,
      feedback: dto.feedback,
    });
    return { id: row.id, feedback: row.feedback };
  }

  @Get('recommendations')
  async recommendations(
    @CurrentUser('id') userId: string,
    @Query() dto: RecommendationHistoryDto,
  ) {
    const rows = await this.prisma.aiStylistRecommendation.findMany({
      where: {
        userId,
        ...(dto.conversation_id ? { conversationId: dto.conversation_id } : {}),
      },
      include: { product: { include: PRODUCT_CARD_INCLUDE } },
      orderBy: { createdAt: 'desc' },
      take: dto.limit,
    });
    return rows.map((row) => serializeRecommendation({ row, product: row.product }));
  }

  // ── Preferences ───────────────────────────────────────────────────────

  @Get('preferences')
  async getPreferences(@CurrentUser('id') userId: string) {
    const row = await this.preferences.findOrCreate(userId);
    return serializePreferences(row);
  }

  @Patch('preferences')
  async updatePreferences(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdatePreferencesDto,
  ) {
    const row = await this.preferences.update(userId, {
      modesty: dto.modesty,
      personas: dto.personas,
      favouriteColours: dto.favourite_colours,
      avoidedColours: dto.avoided_colours,
      preferredCategorySlugs: dto.preferred_category_slugs,
      avoidedCategorySlugs: dto.avoided_category_slugs,
      sizes: dto.sizes,
      budgetMinSyp: dto.budget_min,
      budgetMaxSyp: dto.budget_max,
    });
    return serializePreferences(row);
  }

  /** Recomputes the behaviour-derived half and returns it. */
  @Throttle({ default: { limit: 6, ttl: 60_000 } })
  @Post('preferences/refresh')
  async refreshPreferences(@CurrentUser('id') userId: string) {
    const row = await this.preferences.refreshDerived(userId);
    return serializePreferences(row);
  }

  // ── Discovery surface ─────────────────────────────────────────────────

  /**
   * Everything an empty stylist screen needs: what to suggest she asks, and
   * the vocabularies her filter chips are drawn from — so the client never
   * hard-codes a colour list that could drift from the server's.
   */
  @Get('bootstrap')
  async bootstrap(@CurrentUser('id') userId: string) {
    const [conversations, preferences, profile] = await Promise.all([
      this.stylist.listConversations(userId, 5),
      this.preferences.findOrCreate(userId),
      this.preferences.buildProfile(userId),
    ]);

    const favouriteCategory = [...profile.categoryAffinity.entries()].sort(
      (a, b) => b[1] - a[1],
    )[0]?.[0];

    const favouriteCategoryName = favouriteCategory
      ? ((
          await this.prisma.category.findUnique({
            where: { slug: favouriteCategory },
            select: { nameAr: true },
          })
        )?.nameAr ?? null)
      : null;

    return {
      prompts: starterPrompts({
        hasHistory: conversations.length > 0,
        favouriteCategory: favouriteCategoryName,
      }),
      conversations: conversations.map((row) => serializeConversation(row)),
      preferences: serializePreferences(preferences),
      /// The closed vocabularies, so chips in the app and values on the server
      /// can never disagree.
      vocabulary: {
        occasions: OCCASIONS.map((occasion) => ({
          key: occasion.key,
          label: occasion.labelAr,
        })),
        colours: COLOURS.map((colour) => ({
          key: colour.key,
          label: colour.labelAr,
          neutral: colour.neutral,
        })),
        slots: SLOTS.map((slot) => ({
          key: slot.slot,
          label: slotLabel(slot.slot),
        })),
        modesty: Object.values(ModestyLevel),
      },
      /// Where a fresh conversation would start from, given what she has
      /// already told the app.
      seed_brief: serializeStylistBrief({
        ...emptyBrief(),
        modesty: preferences.modesty,
        personas: preferences.personas.slice(0, 2),
        sizes:
          (preferences.sizes as { clothing?: string; shoes?: string } | null) ?? {},
        budgetMin: preferences.budgetMinSyp ? Number(preferences.budgetMinSyp) : null,
        budgetMax: preferences.budgetMaxSyp ? Number(preferences.budgetMaxSyp) : null,
      }),
    };
  }

  // ── Rendering ─────────────────────────────────────────────────────────

  private async renderTurn(turn: Awaited<ReturnType<StylistConversationService['sendMessage']>>) {
    const outfit = turn.outfitId
      ? await this.prisma.aiStylistOutfit.findUnique({
          where: { id: turn.outfitId },
          include: { items: true },
        })
      : null;

    const products = outfit
      ? await this.stylist.productsFor(outfit.items.map((item) => item.productId))
      : new Map();

    return {
      conversation: serializeConversation(turn.conversation),
      user_message: serializeStylistMessage(turn.userMessage),
      message: serializeStylistMessage(turn.assistantMessage, {
        recommendations: turn.recommendations.map((entry) =>
          serializeRecommendation({ row: entry.row, product: entry.product }),
        ),
        outfit: outfit ? serializeOutfit({ row: outfit, products }) : null,
        followUps: turn.followUps,
      }),
      brief: serializeStylistBrief(turn.brief),
    };
  }
}
