import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/closet/domain/entities/closet_gap.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/entities/closet_look.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';

/// Filters for the item grid. All optional; an absent field is no constraint.
class ClosetItemQuery {
  final String? slot;
  final ClosetItemStatus? status;
  final String? season;
  final String? occasion;
  final String? colour;
  final bool? favouritesOnly;
  final String? search;
  final int? limit;
  final String? cursor;

  const ClosetItemQuery({
    this.slot,
    this.status,
    this.season,
    this.occasion,
    this.colour,
    this.favouritesOnly,
    this.search,
    this.limit,
    this.cursor,
  });

  ClosetItemQuery copyWith({
    String? slot,
    ClosetItemStatus? status,
    String? season,
    String? occasion,
    String? colour,
    bool? favouritesOnly,
    String? search,
    int? limit,
    String? cursor,
    bool clearSlot = false,
    bool clearOccasion = false,
    bool clearCursor = false,
  }) =>
      ClosetItemQuery(
        slot: clearSlot ? null : (slot ?? this.slot),
        status: status ?? this.status,
        season: season ?? this.season,
        occasion: clearOccasion ? null : (occasion ?? this.occasion),
        colour: colour ?? this.colour,
        favouritesOnly: favouritesOnly ?? this.favouritesOnly,
        search: search ?? this.search,
        limit: limit ?? this.limit,
        cursor: clearCursor ? null : (cursor ?? this.cursor),
      );

  Map<String, dynamic> toQuery() => {
        if (slot != null) 'slot': slot,
        if (status != null) 'status': status!.wire,
        if (season != null) 'season': season,
        if (occasion != null) 'occasion': occasion,
        if (colour != null) 'colour': colour,
        if (favouritesOnly == true) 'favourites_only': true,
        if (search != null && search!.isNotEmpty) 'search': search,
        if (limit != null) 'limit': limit,
        if (cursor != null) 'cursor': cursor,
      };
}

/// The descriptor fields she may correct.
///
/// A null field means "leave it alone"; an empty list means "none of them".
/// The distinction is load-bearing all the way to the server — see
/// `DescriptorOverrides` — so it must survive this class rather than being
/// flattened into a map of non-nulls.
class DescriptorPatch {
  final String? slot;
  final List<String>? colours;
  final List<String>? materials;
  final String? modesty;
  final List<String>? seasons;
  final List<String>? occasions;
  final String? size;

  const DescriptorPatch({
    this.slot,
    this.colours,
    this.materials,
    this.modesty,
    this.seasons,
    this.occasions,
    this.size,
  });

  bool get isEmpty =>
      slot == null &&
      colours == null &&
      materials == null &&
      modesty == null &&
      seasons == null &&
      occasions == null &&
      size == null;

  Map<String, dynamic> toJson() => {
        if (slot != null) 'slot': slot,
        if (colours != null) 'colours': colours,
        if (materials != null) 'materials': materials,
        if (modesty != null) 'modesty': modesty,
        if (seasons != null) 'seasons': seasons,
        if (occasions != null) 'occasions': occasions,
        if (size != null) 'size': size,
      };
}

/// A personal garment, as she describes it.
class PersonalItemDraft {
  final String title;

  /// Required, where a catalog piece derives it. A photograph has no category
  /// to fall back on, and a piece filed in the wrong slot distorts every gap
  /// and every outfit it touches.
  final String slot;

  final String? imageUrl;
  final String? brandName;
  final String? note;
  final DateTime? acquiredAt;
  final num? purchasePriceSyp;
  final DescriptorPatch descriptor;

  const PersonalItemDraft({
    required this.title,
    required this.slot,
    this.imageUrl,
    this.brandName,
    this.note,
    this.acquiredAt,
    this.purchasePriceSyp,
    this.descriptor = const DescriptorPatch(),
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'slot': slot,
        if (imageUrl != null) 'image_url': imageUrl,
        if (brandName != null && brandName!.isNotEmpty) 'brand_name': brandName,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (acquiredAt != null) 'acquired_at': acquiredAt!.toIso8601String(),
        if (purchasePriceSyp != null) 'purchase_price_syp': purchasePriceSyp,
        if (!descriptor.isEmpty) 'descriptor': descriptor.toJson(),
      };
}

/// An edit to a piece already in the closet.
class ClosetItemPatch {
  final String? title;
  final String? imageUrl;
  final String? brandName;
  final String? note;
  final bool? isFavourite;
  final DateTime? acquiredAt;
  final num? purchasePriceSyp;
  final DescriptorPatch? descriptor;

  const ClosetItemPatch({
    this.title,
    this.imageUrl,
    this.brandName,
    this.note,
    this.isFavourite,
    this.acquiredAt,
    this.purchasePriceSyp,
    this.descriptor,
  });

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (imageUrl != null) 'image_url': imageUrl,
        if (brandName != null) 'brand_name': brandName,
        if (note != null) 'note': note,
        if (isFavourite != null) 'is_favourite': isFavourite,
        if (acquiredAt != null) 'acquired_at': acquiredAt!.toIso8601String(),
        if (purchasePriceSyp != null) 'purchase_price_syp': purchasePriceSyp,
        if (descriptor != null && !descriptor!.isEmpty)
          'descriptor': descriptor!.toJson(),
      };
}

class LookDraft {
  final String title;
  final String? occasion;
  final String? note;
  final List<String> seasons;
  final List<LookSlotDraft> items;

  const LookDraft({
    required this.title,
    this.occasion,
    this.note,
    this.seasons = const [],
    this.items = const [],
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        if (occasion != null) 'occasion': occasion,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (seasons.isNotEmpty) 'seasons': seasons,
        if (items.isNotEmpty)
          'items': items.map((item) => item.toJson()).toList(growable: false),
      };
}

class LookPatch {
  final String? title;
  final String? occasion;
  final String? note;
  final List<String>? seasons;
  final bool? isFavourite;
  final bool? isArchived;

  const LookPatch({
    this.title,
    this.occasion,
    this.note,
    this.seasons,
    this.isFavourite,
    this.isArchived,
  });

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (occasion != null) 'occasion': occasion,
        if (note != null) 'note': note,
        if (seasons != null) 'seasons': seasons,
        if (isFavourite != null) 'is_favourite': isFavourite,
        if (isArchived != null) 'is_archived': isArchived,
      };
}

abstract interface class ClosetRepository {
  // ── Overview ──────────────────────────────────────────────────────────
  Future<Result<ClosetOverview>> overview();

  Future<Result<ClosetSettings>> updateSettings({
    bool? autoAddPurchases,
    bool? suggestionsEnabled,
  });

  /// Pull her delivered orders into the closet.
  Future<Result<int>> backfill({int? limit});

  // ── Items ─────────────────────────────────────────────────────────────
  Future<Result<ClosetItemPage>> items(ClosetItemQuery query);

  Future<Result<ClosetItem>> item(String id);

  Future<Result<ClosetItem>> addFromCatalog({
    required String productId,
    String? offerId,
    String? variantId,
    String? note,
    DescriptorPatch? descriptor,
  });

  Future<Result<ClosetItem>> addPersonal(PersonalItemDraft draft);

  Future<Result<ClosetItem>> updateItem(String id, ClosetItemPatch patch);

  Future<Result<ClosetItem>> setItemStatus(String id, ClosetItemStatus status);

  Future<Result<void>> removeItem(String id);

  Future<Result<ClosetItem>> logWear(String id, {DateTime? wornOn});

  Future<Result<ClosetItem>> removeWear(String id, {DateTime? wornOn});

  // ── Looks ─────────────────────────────────────────────────────────────
  Future<Result<List<ClosetLook>>> looks({String? occasion, bool includeArchived});

  Future<Result<ClosetLook>> look(String id);

  Future<Result<ClosetLook>> createLook(LookDraft draft);

  Future<Result<ClosetLook>> updateLook(String id, LookPatch patch);

  Future<Result<ClosetLook>> setLookItems(String id, List<LookSlotDraft> items);

  Future<Result<void>> removeLook(String id);

  Future<Result<ClosetLook>> logLookWear(
    String id, {
    DateTime? wornOn,
    String? occasionNote,
  });

  /// Save a stylist suggestion as a look of her own.
  Future<Result<ClosetLook>> promoteStylistOutfit(String outfitId);

  // ── Gaps ──────────────────────────────────────────────────────────────
  Future<Result<List<ClosetGap>>> gaps();

  Future<Result<List<ClosetGap>>> refreshGaps();

  Future<Result<GapSuggestions>> gapSuggestions(String gapId, {int? limit});

  Future<Result<ClosetGap>> dismissGap(String gapId);

  Future<Result<ClosetGap>> restoreGap(String gapId);

  /// "هل بتناسب خزانتي؟" — asked from a product page.
  Future<Result<ClosetPairing?>> pairing(String productId);

  // ── Today ─────────────────────────────────────────────────────────────
  Future<Result<TodayOutfits>> today({String? occasion, int? limit});
}
