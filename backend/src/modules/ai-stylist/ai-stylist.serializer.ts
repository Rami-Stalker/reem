import {
  AiStylistConversation,
  AiStylistMessage,
  AiStylistOutfit,
  AiStylistOutfitItem,
  AiStylistRecommendation,
  UserStylePreference,
} from '@prisma/client';
import { Money } from '../../common/money';
import { serializeProduct } from '../../common/serializers';
import { ProductRecord, defaultOffer } from '../../common/catalog/product-include';
import { StyleBrief, briefFromJson, briefToChips } from './understanding/style-brief';
import {
  colourLabel,
  modestyLabel,
  occasionLabel,
  personaLabel,
  slotLabel,
} from './understanding/stylist-lexicon';

/**
 * The wire shape of the stylist.
 *
 * Products go out through `serializeProduct`, the same function the catalog,
 * search and discovery use — so a recommendation card is the *same* object as
 * a search-result card, and the Flutter client can render it with the widget
 * it already has. The stylist adds only what is stylist-specific: the reason,
 * the score, the slot.
 */

export function serializeStylistBrief(brief: StyleBrief) {
  return {
    intent: brief.intent,
    occasion: brief.occasion,
    occasion_label: occasionLabel(brief.occasion),
    slots: brief.slots,
    slot_labels: brief.slots.map(slotLabel),
    category_slugs: brief.categorySlugs,
    budget_min: brief.budgetMin,
    budget_max: brief.budgetMax,
    colours: brief.colours.map((key) => ({ key, label: colourLabel(key) })),
    avoid_colours: brief.avoidColours.map((key) => ({ key, label: colourLabel(key) })),
    sizes: brief.sizes,
    modesty: brief.modesty,
    modesty_label: modestyLabel(brief.modesty),
    personas: brief.personas.map((persona) => ({
      key: persona,
      label: personaLabel(persona),
    })),
    materials: brief.materials,
    recipient_age: brief.recipientAge,
    for_self: brief.forSelf,
    deadline_days: brief.deadlineDays,
    keywords: brief.keywords,
    confidence: Math.round(brief.confidence * 100) / 100,
    /// Ready-to-render summary of what the assistant understood, so the client
    /// does not have to reimplement the labelling rules.
    chips: briefToChips(brief),
  };
}

export interface RecommendationView {
  row: AiStylistRecommendation;
  product: ProductRecord;
  isLiked?: boolean;
}

export function serializeRecommendation(view: RecommendationView) {
  const { row, product } = view;
  const offer = defaultOffer(product);

  return {
    id: row.id,
    product: serializeProduct(product, { isLiked: view.isLiked ?? false }),
    offer_id: row.offerId ?? offer?.id ?? null,
    slot: row.slot,
    slot_label: row.slot ? slotLabel(row.slot) : null,
    score: Math.round(row.score * 100) / 100,
    position: row.position,
    reason: row.reason,
    reason_codes: row.reasonCodes,
    /// Frozen when the card was produced, so a later price change does not
    /// silently rewrite the recommendation she was actually given.
    quoted_price: row.quotedPriceSyp
      ? Money.of(row.quotedPriceSyp, 'SYP').toJSON()
      : null,
    feedback: row.feedback,
    created_at: row.createdAt.toISOString(),
  };
}

export interface OutfitView {
  row: AiStylistOutfit & { items: AiStylistOutfitItem[] };
  products: Map<string, ProductRecord>;
}

export function serializeOutfit(view: OutfitView) {
  const { row, products } = view;

  const items = row.items
    .slice()
    .sort((a, b) => a.position - b.position)
    .map((item) => {
      const product = products.get(item.productId);
      return {
        id: item.id,
        slot: item.slot,
        slot_label: slotLabel(item.slot),
        offer_id: item.offerId,
        variant_id: item.variantId,
        price: item.priceSyp ? Money.of(item.priceSyp, 'SYP').toJSON() : null,
        reason: item.reason,
        position: item.position,
        // Null when the catalogue entry has since been withdrawn. The client
        // renders the slot as unavailable rather than dropping the piece, so a
        // saved look does not quietly change shape.
        product: product ? serializeProduct(product, { isLiked: false }) : null,
      };
    });

  return {
    id: row.id,
    conversation_id: row.conversationId,
    message_id: row.messageId,
    title: row.title,
    occasion: row.occasion,
    occasion_label: occasionLabel(row.occasion),
    note: row.note,
    palette: row.palette.map((key) => ({ key, label: colourLabel(key) })),
    total: row.totalSyp ? Money.of(row.totalSyp, 'SYP').toJSON() : null,
    status: row.status,
    items,
    created_at: row.createdAt.toISOString(),
  };
}

export function serializeStylistMessage(
  message: AiStylistMessage,
  extras: {
    recommendations?: ReturnType<typeof serializeRecommendation>[];
    outfit?: ReturnType<typeof serializeOutfit> | null;
    followUps?: string[];
  } = {},
) {
  return {
    id: message.id,
    conversation_id: message.conversationId,
    role: message.role,
    modality: message.modality,
    content: message.content,
    brief: message.brief ? serializeStylistBrief(briefFromJson(message.brief)) : null,
    engine: message.engine,
    latency_ms: message.latencyMs,
    created_at: message.createdAt.toISOString(),
    recommendations: extras.recommendations ?? [],
    outfit: extras.outfit ?? null,
    follow_ups: extras.followUps ?? [],
  };
}

export function serializeConversation(
  conversation: AiStylistConversation,
  extras: { messages?: ReturnType<typeof serializeStylistMessage>[] } = {},
) {
  return {
    id: conversation.id,
    title: conversation.title,
    status: conversation.status,
    brief: conversation.brief
      ? serializeStylistBrief(briefFromJson(conversation.brief))
      : null,
    messages_count: conversation.messagesCount,
    last_message_at: conversation.lastMessageAt?.toISOString() ?? null,
    created_at: conversation.createdAt.toISOString(),
    ...(extras.messages ? { messages: extras.messages } : {}),
  };
}

export function serializePreferences(
  preferences: UserStylePreference,
  extras: { derivedSummary?: unknown } = {},
) {
  const sizes = (preferences.sizes as { clothing?: string; shoes?: string } | null) ?? {};

  return {
    modesty: preferences.modesty,
    modesty_label: modestyLabel(preferences.modesty),
    personas: preferences.personas.map((persona) => ({
      key: persona,
      label: personaLabel(persona),
    })),
    favourite_colours: preferences.favouriteColours.map((key) => ({
      key,
      label: colourLabel(key),
    })),
    avoided_colours: preferences.avoidedColours.map((key) => ({
      key,
      label: colourLabel(key),
    })),
    preferred_category_slugs: preferences.preferredCategorySlugs,
    avoided_category_slugs: preferences.avoidedCategorySlugs,
    sizes: { clothing: sizes.clothing ?? null, shoes: sizes.shoes ?? null },
    budget_min: preferences.budgetMinSyp
      ? Money.of(preferences.budgetMinSyp, 'SYP').toJSON()
      : null,
    budget_max: preferences.budgetMaxSyp
      ? Money.of(preferences.budgetMaxSyp, 'SYP').toJSON()
      : null,
    typical_min: preferences.typicalMinSyp
      ? Money.of(preferences.typicalMinSyp, 'SYP').toJSON()
      : null,
    typical_max: preferences.typicalMaxSyp
      ? Money.of(preferences.typicalMaxSyp, 'SYP').toJSON()
      : null,
    /// What her behaviour says, as opposed to what she declared. Shown back to
    /// her so the personalization is inspectable rather than mysterious.
    derived: extras.derivedSummary ?? preferences.derivedSignals ?? null,
    computed_at: preferences.computedAt?.toISOString() ?? null,
    updated_at: preferences.updatedAt.toISOString(),
  };
}
