import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AiStylistController } from './ai-stylist.controller';
import { AnthropicStylistLlm } from './llm/anthropic-stylist-llm';
import { DisabledStylistLlm, STYLIST_LLM, StylistLlm } from './llm/stylist-llm';
import { OutfitBuilderService } from './outfit/outfit-builder.service';
import { StylePreferenceService } from './preferences/style-preference.service';
import { ProductRetrievalService } from './retrieval/product-retrieval.service';
import { StylistConversationService } from './stylist-conversation.service';
import { BriefExtractorService } from './understanding/brief-extractor.service';

/**
 * Ohara AI Stylist.
 *
 * Sits beside the existing `AiAssistantModule` rather than replacing it: that
 * one answers "what should this rail show" for feeds and product pages, this
 * one answers a sentence. They share the catalog helpers and the product
 * serializer, so a card looks the same wherever it came from.
 *
 * The provider binding below is the whole configuration story. With
 * `AI_STYLIST_PROVIDER` unset — the default — `STYLIST_LLM` resolves to the
 * disabled implementation and every path runs deterministically. Setting it to
 * `anthropic` with a key swaps in the HTTP client, and nothing else in the
 * module changes.
 *
 * ── Where the next four features attach ──────────────────────────────────
 *
 * All of them are new ways to *produce a brief*, which is why the brief is a
 * type and not a parse of a sentence. None of them touch retrieval or ranking.
 *
 *  - **Voice.** `AiStylistModality.VOICE` and `ai_stylist_messages.attachments`
 *    already exist. Transcribe, put the text in `content`, the clip id in
 *    `attachments`, and the same extractor runs.
 *  - **Image search.** `MODALITY.IMAGE`, plus a vision step that fills the
 *    colour, category and persona fields of a `Partial<StyleBrief>` — the same
 *    slot `StylistLlm.extractBrief` occupies, behind the same `sanitiseBrief`
 *    gate, so a vision model cannot name a colour the catalogue lacks either.
 *  - **Virtual try-on.** Reads an existing `AiStylistOutfit`: the pieces are
 *    already resolved to products, variants and images.
 *  - **Shopping automation.** Consumes the outfit's `offerId`s, which are the
 *    same identifiers the cart takes.
 */
@Module({
  controllers: [AiStylistController],
  providers: [
    StylistConversationService,
    BriefExtractorService,
    ProductRetrievalService,
    OutfitBuilderService,
    StylePreferenceService,
    {
      provide: STYLIST_LLM,
      inject: [ConfigService],
      useFactory: (config: ConfigService): StylistLlm => {
        const provider = config.get<string>('stylist.provider') ?? 'none';
        const apiKey = config.get<string>('stylist.apiKey') ?? '';

        // A provider named without a key is a misconfiguration, not a request
        // to fail: the deterministic path is a complete implementation, so the
        // stylist stays up and the operator sees an unconfigured provider.
        if (provider !== 'anthropic' || !apiKey) return new DisabledStylistLlm();

        return new AnthropicStylistLlm({
          apiKey,
          baseUrl: config.get<string>('stylist.baseUrl') ?? 'https://api.anthropic.com',
          model: config.get<string>('stylist.model') ?? 'claude-sonnet-5',
          timeoutMs: config.get<number>('stylist.timeoutMs') ?? 8000,
          maxOutputTokens: config.get<number>('stylist.maxOutputTokens') ?? 1024,
          composeReplies: config.get<boolean>('stylist.composeReplies') ?? true,
        });
      },
    },
  ],
  // `BriefExtractorService` is exported for Ohara Visual Shopping: refining a
  // photo search in words must use *this* parser and *this* vocabulary, not a
  // second one that will drift from it.
  //
  // `ProductRetrievalService` is exported for Ohara Closet, which turns a
  // wardrobe gap into a `StyleBrief` and answers it here. That is the whole
  // integration between the two features, and it means a closet suggestion
  // cannot reach a product the stylist would refuse to show — the modesty
  // filter, the purchasable predicate and the relaxation ladder are enforced
  // once, for both.
  exports: [
    StylistConversationService,
    StylePreferenceService,
    BriefExtractorService,
    ProductRetrievalService,
  ],
})
export class AiStylistModule {}
