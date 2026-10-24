import 'package:ohara/core/shared/models/product_model.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/ai_stylist/data/models/stylist_models.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:ohara/features/visual_search/domain/entities/visual_match.dart';
import 'package:ohara/features/visual_search/domain/entities/visual_search_session.dart';
import 'package:ohara/features/visual_search/domain/entities/visual_understanding.dart';

/// Wire decoding for Ohara Visual Shopping.
///
/// Free functions rather than `…Model extends …` subclasses, matching the
/// stylist's decoders next door: these entities are read-only view data with
/// no behaviour to inherit. Every decoder is total — a missing or misshapen
/// field yields the empty value rather than throwing, because a results screen
/// that dies on one malformed card loses the whole search.

// ── Primitives ──────────────────────────────────────────────────────────

List<String> _strings(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

double _double(Object? value) => (value as num?)?.toDouble() ?? 0;

DateTime? _dateOrNull(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal();

DateTime _date(Object? value) => _dateOrNull(value) ?? DateTime.now();

/// Prefers the labelled form, falling back to bare slugs so a response from an
/// older server still renders something rather than nothing.
List<VisualCategory> _categories(Map<String, dynamic> json) {
  final labelled = json['categories'];
  if (labelled is List) {
    return labelled
        .whereType<Map>()
        .map(
          (item) => VisualCategory(
            slug: (item['slug'] ?? '').toString(),
            label: (item['label'] ?? item['slug'] ?? '').toString(),
          ),
        )
        .where((category) => category.slug.isNotEmpty)
        .toList(growable: false);
  }
  return _strings(json['category_slugs'])
      .map((slug) => VisualCategory(slug: slug, label: slug))
      .toList(growable: false);
}

List<VisualChip> _chips(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(
        (item) => VisualChip(
          key: (item['key'] ?? '').toString(),
          label: (item['label'] ?? '').toString(),
        ),
      )
      .where((chip) => chip.label.isNotEmpty)
      .toList(growable: false);
}

// ── Understanding ───────────────────────────────────────────────────────

VisualUnderstanding understandingFromJson(Map<String, dynamic>? json) {
  if (json == null) return VisualUnderstanding.empty;

  final provenance = <String, AttributeProvenance>{};
  final rawProvenance = _map(json['provenance']);
  if (rawProvenance != null) {
    for (final entry in rawProvenance.entries) {
      provenance[entry.key] = AttributeProvenance.fromWire(
        entry.value?.toString(),
      );
    }
  }

  final colours = (json['colours'] is List ? json['colours'] as List : const [])
      .whereType<Map>()
      .map(
        (item) => VisualColour(
          key: (item['key'] ?? '').toString(),
          label: (item['label'] ?? '').toString(),
          share: _double(item['share']),
        ),
      )
      .where((colour) => colour.key.isNotEmpty)
      .toList(growable: false);

  return VisualUnderstanding(
    colours: colours,
    pattern: (json['pattern'] ?? 'plain').toString(),
    patternLabel: (json['pattern_label'] ?? '').toString(),
    tone: (json['tone'] ?? 'mid').toString(),
    toneLabel: (json['tone_label'] ?? '').toString(),
    framing: (json['framing'] ?? 'product').toString(),
    framingLabel: (json['framing_label'] ?? '').toString(),
    categories: _categories(json),
    chips: _chips(json['chips']),
    confidence: _double(json['confidence']),
    provenance: provenance,
  );
}

// ── Match ───────────────────────────────────────────────────────────────

VisualMatch? matchFromJson(Map<String, dynamic> json) {
  final productJson = _map(json['product']);
  if (productJson == null) return null;

  return VisualMatch(
    id: (json['id'] ?? '').toString(),
    product: ProductModel.fromJson(productJson),
    offerId: json['offer_id']?.toString(),
    matchedMediaUrl: json['matched_media_url']?.toString(),
    similarity: _double(json['similarity']),
    // Falls back to rounding the float rather than showing nothing: an older
    // server without the field is a worse badge, not a missing card.
    similarityPercent:
        (json['similarity_percent'] as num?)?.round() ??
        (_double(json['similarity']) * 100).round(),
    visualScore: _double(json['visual_score']),
    attributeScore: _double(json['attribute_score']),
    reason: (json['reason'] ?? '').toString(),
    reasonCodes: _strings(json['reason_codes']),
    quotedPrice: Money.tryFromJson(json['quoted_price']),
    feedback: StylistFeedback.fromWire(json['feedback']?.toString()),
  );
}

List<VisualMatch> matchesFromJson(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => matchFromJson(Map<String, dynamic>.from(item)))
      .whereType<VisualMatch>()
      .toList(growable: false);
}

// ── Region ──────────────────────────────────────────────────────────────

VisualBox boxFromJson(Object? value) {
  final json = _map(value);
  if (json == null) return VisualBox.full;
  return VisualBox(
    x: _double(json['x']),
    y: _double(json['y']),
    w: _double(json['w']),
    h: _double(json['h']),
  );
}

VisualRegion regionFromJson(Map<String, dynamic> json) => VisualRegion(
  id: (json['id'] ?? '').toString(),
  detector: VisualRegionDetector.fromWire(json['detector']?.toString()),
  label: (json['label'] ?? '').toString(),
  box: boxFromJson(json['box']),
  confidence: _double(json['confidence']),
  slot: json['slot']?.toString(),
  slotLabel: json['slot_label']?.toString(),
  matches: matchesFromJson(json['matches']),
);

// ── Session ─────────────────────────────────────────────────────────────

VisualSearchSession sessionFromJson(Map<String, dynamic> json) {
  final regions = (json['regions'] is List ? json['regions'] as List : const [])
      .whereType<Map>()
      .map((item) => regionFromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);

  final refinements =
      (json['refinements'] is List ? json['refinements'] as List : const [])
          .whereType<Map>()
          .map(
            (item) => VisualRefinement(
              text: (item['text'] ?? '').toString(),
              at: _dateOrNull(item['at']),
            ),
          )
          .where((entry) => entry.text.isNotEmpty)
          .toList(growable: false);

  return VisualSearchSession(
    id: (json['id'] ?? '').toString(),
    status: (json['status'] ?? 'PENDING').toString(),
    source: (json['source'] ?? 'GALLERY').toString(),
    queryImageUrl: json['query_image_url']?.toString(),
    imageExpiresAt: _dateOrNull(json['image_expires_at']),
    understanding: understandingFromJson(_map(json['understanding'])),
    brief: briefFromJson(_map(json['brief'])),
    regions: regions,
    refinements: refinements,
    engine: json['engine']?.toString(),
    notice: json['notice']?.toString(),
    createdAt: _date(json['created_at']),
  );
}

// ── Bootstrap ───────────────────────────────────────────────────────────

TryOnCapability tryOnCapabilityFromJson(Map<String, dynamic>? json) {
  if (json == null) return TryOnCapability.unavailable;
  return TryOnCapability(
    available: json['available'] as bool? ?? false,
    provider: (json['provider'] ?? 'none').toString(),
    retentionHours: (json['retention_hours'] as num?)?.round() ?? 2,
    message: json['message']?.toString(),
  );
}

VisualSearchBootstrap bootstrapFromJson(Map<String, dynamic> json) {
  final coverage = _map(json['coverage']) ?? const {};
  final limits = _map(json['limits']) ?? const {};
  final privacy = _map(json['privacy']) ?? const {};

  return VisualSearchBootstrap(
    ready: json['ready'] as bool? ?? false,
    engine: (json['engine'] ?? '').toString(),
    indexedProducts: (coverage['indexed_products'] as num?)?.round() ?? 0,
    activeProducts: (coverage['active_products'] as num?)?.round() ?? 0,
    maxImageBytes:
        (limits['max_image_bytes'] as num?)?.round() ?? 8 * 1024 * 1024,
    uploadMaxEdge: (limits['upload_max_edge'] as num?)?.round() ?? 1024,
    imageRetentionHours:
        (privacy['image_retention_hours'] as num?)?.round() ?? 24,
    privacyNote: (privacy['note'] ?? '').toString(),
    tryOn: tryOnCapabilityFromJson(_map(json['try_on'])),
    recent: (json['recent'] is List ? json['recent'] as List : const [])
        .whereType<Map>()
        .map((item) => sessionFromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
    prompts: _strings(json['prompts']),
  );
}
