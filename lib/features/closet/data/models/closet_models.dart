import 'package:reem/core/shared/models/product_model.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/closet/domain/entities/closet_gap.dart';
import 'package:reem/features/closet/domain/entities/closet_item.dart';
import 'package:reem/features/closet/domain/entities/closet_look.dart';
import 'package:reem/features/closet/domain/entities/closet_overview.dart';

/// Wire decoding for the closet.
///
/// Free functions rather than model subclasses, matching the stylist: these
/// entities are read-only view data with no behaviour to inherit. Every decoder
/// is total — a missing or misshapen field yields the empty value rather than
/// throwing — because one malformed garment must not take down a wardrobe of
/// two hundred.

// ── Primitives ──────────────────────────────────────────────────────────

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

List<String> _strings(Object? value) => value is List
    ? value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
    : const [];

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

double _double(Object? value) => switch (value) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s) ?? 0,
      _ => 0,
    };

int _int(Object? value) => switch (value) {
      final num n => n.toInt(),
      final String s => int.tryParse(s) ?? 0,
      _ => 0,
    };

ClosetTerm termFromJson(Map<String, dynamic> json) => ClosetTerm(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? json['key']?.toString() ?? '',
    );

List<ClosetTerm> _terms(Object? value) =>
    _maps(value).map(termFromJson).toList(growable: false);

// ── Items ───────────────────────────────────────────────────────────────

ClosetItem closetItemFromJson(Map<String, dynamic> json) => ClosetItem(
      id: json['id']?.toString() ?? '',
      source: ClosetItemSource.fromWire(json['source'] as String?),
      sourceLabel: json['source_label']?.toString() ?? '',
      status: ClosetItemStatus.fromWire(json['status'] as String?),
      title: json['title']?.toString() ?? '',
      imageUrl: json['image_url'] as String?,
      blurHash: json['blur_hash'] as String?,
      slot: json['slot']?.toString() ?? '',
      slotLabel: json['slot_label']?.toString() ?? '',
      colours: _terms(json['colours']),
      materials: _strings(json['materials']),
      modesty: json['modesty']?.toString() ?? 'UNSPECIFIED',
      modestyLabel: json['modesty_label']?.toString() ?? '',
      seasons: _terms(json['seasons']),
      occasions: _terms(json['occasions']),
      size: json['size'] as String?,
      brandName: json['brand_name'] as String? ??
          (_map(json['brand'])['name_ar'] as String?),
      productId: json['product_id'] as String?,
      offerId: json['offer_id'] as String?,
      variantId: json['variant_id'] as String?,
      purchasePrice: Money.tryFromJson(json['purchase_price']),
      costPerWear: Money.tryFromJson(json['cost_per_wear']),
      wearCount: _int(json['wear_count']),
      lastWornAt: _date(json['last_worn_at']),
      isFavourite: json['is_favourite'] == true,
      note: json['note'] as String?,
      acquiredAt: _date(json['acquired_at']),
    );

List<ClosetItem> closetItemsFromJson(Object? value) =>
    _maps(value).map(closetItemFromJson).toList(growable: false);

ClosetItemPage closetItemPageFromJson(Map<String, dynamic> json) => ClosetItemPage(
      items: closetItemsFromJson(json['items']),
      nextCursor: json['next_cursor'] as String?,
    );

// ── Looks ───────────────────────────────────────────────────────────────

LookPiece lookPieceFromJson(Map<String, dynamic> json) {
  final owned = json['owned'];
  final product = json['product'];
  return LookPiece(
    id: json['id']?.toString() ?? '',
    slot: json['slot']?.toString() ?? '',
    slotLabel: json['slot_label']?.toString() ?? '',
    position: _int(json['position']),
    note: json['note'] as String?,
    owned: owned is Map ? closetItemFromJson(Map<String, dynamic>.from(owned)) : null,
    // Null when the catalogue entry has since been withdrawn — the slot renders
    // as unavailable rather than disappearing, so a saved look does not quietly
    // change shape.
    product: product is Map
        ? ProductModel.fromJson(Map<String, dynamic>.from(product))
        : null,
    offerId: json['offer_id'] as String?,
    variantId: json['variant_id'] as String?,
  );
}

ClosetLook closetLookFromJson(Map<String, dynamic> json) => ClosetLook(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      note: json['note'] as String?,
      occasion: json['occasion'] as String?,
      occasionLabel: json['occasion_label'] as String?,
      seasons: _terms(json['seasons']),
      palette: _terms(json['palette']),
      isComplete: json['is_complete'] == true,
      isFavourite: json['is_favourite'] == true,
      isArchived: json['is_archived'] == true,
      missingSlots: _maps(json['missing_slots'])
          .map((slot) => ClosetTerm(
                key: slot['slot']?.toString() ?? '',
                label: slot['label']?.toString() ?? '',
              ))
          .toList(growable: false),
      wearCount: _int(json['wear_count']),
      lastWornAt: _date(json['last_worn_at']),
      sourceOutfitId: json['source_outfit_id'] as String?,
      pieces: _maps(json['items']).map(lookPieceFromJson).toList(growable: false),
    );

List<ClosetLook> closetLooksFromJson(Object? value) =>
    _maps(value).map(closetLookFromJson).toList(growable: false);

// ── Gaps ────────────────────────────────────────────────────────────────

ClosetGap closetGapFromJson(Map<String, dynamic> json) {
  final look = _map(json['look']);
  final components = _map(json['components']);
  return ClosetGap(
    id: json['id']?.toString() ?? '',
    kind: ClosetGapKind.fromWire(json['kind'] as String?),
    slot: json['slot']?.toString() ?? '',
    slotLabel: json['slot_label']?.toString() ?? '',
    occasion: json['occasion'] as String?,
    occasionLabel: json['occasion_label'] as String?,
    seasonLabel: json['season_label'] as String?,
    lookId: look['id'] as String?,
    lookTitle: look['title'] as String?,
    headline: json['headline']?.toString() ?? '',
    rationale: json['rationale']?.toString() ?? '',
    priority: _double(json['priority']),
    components: {
      for (final entry in components.entries)
        if (entry.value is num) entry.key: entry.value as num,
    },
    suggestedColours: _terms(json['suggested_colours']),
    suggestedSize: json['suggested_size'] as String?,
    suggestedBudgetMin: Money.tryFromJson(json['suggested_budget_min']),
    suggestedBudgetMax: Money.tryFromJson(json['suggested_budget_max']),
  );
}

List<ClosetGap> closetGapsFromJson(Object? value) =>
    _maps(value).map(closetGapFromJson).toList(growable: false);

ClosetSuggestion closetSuggestionFromJson(Map<String, dynamic> json) =>
    ClosetSuggestion(
      product: ProductModel.fromJson(_map(json['product'])),
      score: _double(json['score']),
      styleScore: _double(json['style_score']),
      pairingScore: _double(json['pairing_score']),
      styleReasons: _strings(json['style_reasons']),
      pairingReasons: _maps(json['pairing_reasons'])
          .map((reason) => ClosetTerm(
                key: reason['code']?.toString() ?? '',
                label: reason['label']?.toString() ?? '',
              ))
          .toList(growable: false),
      pairsWithItemIds: _strings(json['pairs_with_item_ids']),
      completesLookIds: _strings(json['completes_look_ids']),
    );

GapSuggestions gapSuggestionsFromJson(Map<String, dynamic> json) => GapSuggestions(
      gap: closetGapFromJson(_map(json['gap'])),
      suggestions: _maps(json['suggestions'])
          .map(closetSuggestionFromJson)
          .toList(growable: false),
    );

ClosetPairing closetPairingFromJson(Map<String, dynamic> json) => ClosetPairing(
      slot: json['slot']?.toString() ?? '',
      score: _double(json['score']),
      alreadyOwned: _int(json['already_owned']),
      pairsWithItemIds: _strings(json['pairs_with_item_ids']),
      completesLookIds: _strings(json['completes_look_ids']),
      reasons: _strings(json['reasons']),
    );

// ── Overview and today ──────────────────────────────────────────────────

ClosetSettings closetSettingsFromJson(Map<String, dynamic> json) => ClosetSettings(
      id: json['id']?.toString() ?? '',
      autoAddPurchases: json['auto_add_purchases'] != false,
      suggestionsEnabled: json['suggestions_enabled'] != false,
    );

ClosetVocabulary vocabularyFromJson(Map<String, dynamic> json) => ClosetVocabulary(
      slots: _terms(json['slots']),
      occasions: _terms(json['occasions']),
      seasons: _terms(json['seasons']),
    );

ClosetOverview closetOverviewFromJson(Map<String, dynamic> json) => ClosetOverview(
      settings: closetSettingsFromJson(_map(json['closet'])),
      season: json['season']?.toString() ?? 'ALL',
      seasonLabel: json['season_label']?.toString() ?? '',
      itemsCount: _int(json['items_count']),
      archivedCount: _int(json['archived_count']),
      looksCount: _int(json['looks_count']),
      completeLooksCount: _int(json['complete_looks_count']),
      wornThisMonth: _int(json['worn_this_month']),
      outfitCapacity: _int(json['outfit_capacity']),
      seasonOutfitCapacity: _int(json['season_outfit_capacity']),
      slotCounts: _maps(json['slot_counts'])
          .map((slot) => SlotCount(
                slot: slot['slot']?.toString() ?? '',
                label: slot['label']?.toString() ?? '',
                count: _int(slot['count']),
              ))
          .toList(growable: false),
      neglected: closetItemsFromJson(json['neglected']),
      gaps: closetGapsFromJson(json['gaps']),
      vocabulary: vocabularyFromJson(_map(json['vocabulary'])),
    );

TodayOutfit todayOutfitFromJson(Map<String, dynamic> json) => TodayOutfit(
      key: json['key']?.toString() ?? '',
      origin: json['origin']?.toString() ?? 'COMPOSED',
      score: _double(json['score']),
      lookId: json['look_id'] as String?,
      lookTitle: json['look_title'] as String?,
      occasionLabel: json['occasion_label'] as String?,
      reasons: _maps(json['reasons'])
          .map((reason) => ClosetTerm(
                key: reason['code']?.toString() ?? '',
                label: reason['label']?.toString() ?? '',
              ))
          .toList(growable: false),
      missingSlots: _maps(json['missing_slots'])
          .map((slot) => ClosetTerm(
                key: slot['slot']?.toString() ?? '',
                label: slot['label']?.toString() ?? '',
              ))
          .toList(growable: false),
      pieces: closetItemsFromJson(json['pieces']),
    );

TodayOutfits todayOutfitsFromJson(Map<String, dynamic> json) => TodayOutfits(
      season: json['season']?.toString() ?? 'ALL',
      outfits:
          _maps(json['outfits']).map(todayOutfitFromJson).toList(growable: false),
    );
