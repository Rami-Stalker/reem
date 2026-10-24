import 'package:ohara/core/shared/models/product_model.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/ai_stylist/domain/entities/style_brief.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_conversation.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_message.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_recommendation.dart';

/// Wire decoding for the stylist.
///
/// Free functions rather than `…Model extends …` subclasses: the entities here
/// are read-only view data with no behaviour to inherit, and a subclass per
/// type would double the file for nothing. Every decoder is total — a missing
/// or misshapen field yields the empty value rather than an exception, because
/// a chat screen that throws on one malformed card loses the whole thread.

// ── Primitives ──────────────────────────────────────────────────────────

List<String> _strings(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<StyleTerm> _terms(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(
        (item) => StyleTerm(
          key: (item['key'] ?? '').toString(),
          label: (item['label'] ?? item['key'] ?? '').toString(),
        ),
      )
      .where((term) => term.key.isNotEmpty)
      .toList(growable: false);
}

DateTime _date(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

// ── Brief ───────────────────────────────────────────────────────────────

StyleBrief briefFromJson(Map<String, dynamic>? json) {
  if (json == null) return StyleBrief.empty;
  final sizes = _map(json['sizes']) ?? const {};

  return StyleBrief(
    intent: (json['intent'] ?? 'FIND_PRODUCT').toString(),
    occasion: json['occasion']?.toString(),
    occasionLabel: json['occasion_label']?.toString(),
    slots: _strings(json['slots']),
    slotLabels: _strings(json['slot_labels']),
    categorySlugs: _strings(json['category_slugs']),
    budgetMin: json['budget_min'] as num?,
    budgetMax: json['budget_max'] as num?,
    colours: _terms(json['colours']),
    avoidColours: _terms(json['avoid_colours']),
    clothingSize: sizes['clothing']?.toString(),
    shoeSize: sizes['shoes']?.toString(),
    modesty: (json['modesty'] ?? 'UNSPECIFIED').toString(),
    modestyLabel: (json['modesty_label'] ?? '').toString(),
    personas: _terms(json['personas']),
    materials: _strings(json['materials']),
    recipientAge: json['recipient_age'] as int?,
    forSelf: json['for_self'] as bool? ?? true,
    deadlineDays: json['deadline_days'] as int?,
    keywords: _strings(json['keywords']),
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    chips: _terms(json['chips']),
  );
}

// ── Recommendation ──────────────────────────────────────────────────────

StylistRecommendation? recommendationFromJson(Map<String, dynamic> json) {
  final productJson = _map(json['product']);
  if (productJson == null) return null;

  return StylistRecommendation(
    id: (json['id'] ?? '').toString(),
    product: ProductModel.fromJson(productJson),
    reason: (json['reason'] ?? '').toString(),
    createdAt: _date(json['created_at']),
    offerId: json['offer_id']?.toString(),
    slot: json['slot']?.toString(),
    slotLabel: json['slot_label']?.toString(),
    score: (json['score'] as num?)?.toDouble() ?? 0,
    position: json['position'] as int? ?? 0,
    reasonCodes: _strings(json['reason_codes']),
    quotedPrice: Money.tryFromJson(json['quoted_price']),
    feedback: StylistFeedback.fromWire(json['feedback']?.toString()),
  );
}

List<StylistRecommendation> recommendationsFromJson(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => recommendationFromJson(Map<String, dynamic>.from(item)))
      .whereType<StylistRecommendation>()
      .toList(growable: false);
}

// ── Outfit ──────────────────────────────────────────────────────────────

OutfitPiece pieceFromJson(Map<String, dynamic> json) {
  final productJson = _map(json['product']);

  return OutfitPiece(
    id: (json['id'] ?? '').toString(),
    slot: (json['slot'] ?? '').toString(),
    slotLabel: (json['slot_label'] ?? '').toString(),
    // Null when the catalogue entry was withdrawn after the look was saved.
    product: productJson == null ? null : ProductModel.fromJson(productJson),
    offerId: json['offer_id']?.toString(),
    variantId: json['variant_id']?.toString(),
    price: Money.tryFromJson(json['price']),
    reason: json['reason']?.toString(),
    position: json['position'] as int? ?? 0,
  );
}

StylistOutfit outfitFromJson(Map<String, dynamic> json) {
  final items = (json['items'] as List? ?? const [])
      .whereType<Map>()
      .map((item) => pieceFromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);

  return StylistOutfit(
    id: (json['id'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    createdAt: _date(json['created_at']),
    conversationId: json['conversation_id']?.toString(),
    messageId: json['message_id']?.toString(),
    occasion: json['occasion']?.toString(),
    occasionLabel: json['occasion_label']?.toString(),
    note: json['note']?.toString(),
    palette: _terms(json['palette']),
    total: Money.tryFromJson(json['total']),
    status: StylistOutfitStatus.fromWire(json['status']?.toString()),
    items: items,
  );
}

// ── Message and conversation ────────────────────────────────────────────

StylistRole _role(Object? value) => switch (value?.toString()) {
      'USER' => StylistRole.user,
      'SYSTEM' => StylistRole.system,
      _ => StylistRole.assistant,
    };

StylistModality _modality(Object? value) => switch (value?.toString()) {
      'VOICE' => StylistModality.voice,
      'IMAGE' => StylistModality.image,
      _ => StylistModality.text,
    };

StylistMessage messageFromJson(Map<String, dynamic> json) {
  final outfitJson = _map(json['outfit']);

  return StylistMessage(
    id: (json['id'] ?? '').toString(),
    conversationId: (json['conversation_id'] ?? '').toString(),
    role: _role(json['role']),
    content: (json['content'] ?? '').toString(),
    createdAt: _date(json['created_at']),
    modality: _modality(json['modality']),
    brief: json['brief'] == null ? null : briefFromJson(_map(json['brief'])),
    engine: json['engine']?.toString(),
    latencyMs: json['latency_ms'] as int?,
    recommendations: recommendationsFromJson(json['recommendations']),
    outfit: outfitJson == null ? null : outfitFromJson(outfitJson),
    followUps: _strings(json['follow_ups']),
  );
}

StylistConversation conversationFromJson(Map<String, dynamic> json) {
  return StylistConversation(
    id: (json['id'] ?? '').toString(),
    createdAt: _date(json['created_at']),
    title: json['title']?.toString(),
    status: (json['status'] ?? 'ACTIVE').toString(),
    brief: json['brief'] == null ? null : briefFromJson(_map(json['brief'])),
    messagesCount: json['messages_count'] as int? ?? 0,
    lastMessageAt: json['last_message_at'] == null
        ? null
        : _date(json['last_message_at']),
    messages: (json['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => messageFromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
  );
}

StylistTurn turnFromJson(Map<String, dynamic> json) {
  return StylistTurn(
    conversation: conversationFromJson(_map(json['conversation']) ?? const {}),
    userMessage: messageFromJson(_map(json['user_message']) ?? const {}),
    assistantMessage: messageFromJson(_map(json['message']) ?? const {}),
    brief: briefFromJson(_map(json['brief'])),
  );
}

// ── Preferences ─────────────────────────────────────────────────────────

DerivedTaste? derivedFromJson(Object? value) {
  final json = _map(value);
  if (json == null) return null;
  final counts = _map(json['counts']) ?? const {};

  return DerivedTaste(
    topCategories: _weightedTerms(json['categories']),
    topColours: _weightedTerms(json['colours']),
    viewedCount: counts['viewed'] as int? ?? 0,
    savedCount: counts['saved'] as int? ?? 0,
    purchasedCount: counts['purchased'] as int? ?? 0,
    dismissedCount: counts['dismissed'] as int? ?? 0,
    maturity: (json['maturity'] ?? 'new').toString(),
  );
}

/// The derived half stores `{ key, weight }` rather than `{ key, label }` —
/// these are affinity scores, and the label is the key itself.
List<StyleTerm> _weightedTerms(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => StyleTerm(
            key: (item['key'] ?? '').toString(),
            label: (item['key'] ?? '').toString(),
          ))
      .where((term) => term.key.isNotEmpty)
      .toList(growable: false);
}

StylePreferences preferencesFromJson(Map<String, dynamic> json) {
  final sizes = _map(json['sizes']) ?? const {};

  return StylePreferences(
    modesty: (json['modesty'] ?? 'UNSPECIFIED').toString(),
    modestyLabel: (json['modesty_label'] ?? '').toString(),
    personas: _terms(json['personas']),
    favouriteColours: _terms(json['favourite_colours']),
    avoidedColours: _terms(json['avoided_colours']),
    preferredCategorySlugs: _strings(json['preferred_category_slugs']),
    avoidedCategorySlugs: _strings(json['avoided_category_slugs']),
    clothingSize: sizes['clothing']?.toString(),
    shoeSize: sizes['shoes']?.toString(),
    budgetMin: Money.tryFromJson(json['budget_min']),
    budgetMax: Money.tryFromJson(json['budget_max']),
    typicalMin: Money.tryFromJson(json['typical_min']),
    typicalMax: Money.tryFromJson(json['typical_max']),
    derived: derivedFromJson(json['derived']),
    computedAt: json['computed_at'] == null ? null : _date(json['computed_at']),
  );
}

StylistBootstrap bootstrapFromJson(Map<String, dynamic> json) {
  final vocabulary = _map(json['vocabulary']) ?? const {};

  return StylistBootstrap(
    prompts: _strings(json['prompts']),
    conversations: (json['conversations'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => conversationFromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
    preferences: preferencesFromJson(_map(json['preferences']) ?? const {}),
    occasions: _terms(vocabulary['occasions']),
    colours: _terms(vocabulary['colours']),
    slots: _terms(vocabulary['slots']),
    seedBrief: briefFromJson(_map(json['seed_brief'])),
  );
}
