import 'package:equatable/equatable.dart';
import 'package:ohara/features/closet/domain/entities/closet_gap.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';

/// The closed vocabulary, served by the backend.
///
/// Slots, occasions and seasons come down with the overview rather than being
/// hard-coded here. The engine reasons in exactly these values, so a picker
/// built from a local copy could offer her a slot the gap engine has never
/// heard of — and the mismatch would only show up as suggestions that never
/// arrive.
class ClosetVocabulary extends Equatable {
  final List<ClosetTerm> slots;
  final List<ClosetTerm> occasions;
  final List<ClosetTerm> seasons;

  const ClosetVocabulary({
    this.slots = const [],
    this.occasions = const [],
    this.seasons = const [],
  });

  String labelForSlot(String key) =>
      slots.firstWhere((term) => term.key == key,
          orElse: () => ClosetTerm(key: key, label: key)).label;

  @override
  List<Object?> get props => [slots.length, occasions.length, seasons.length];
}

class ClosetSettings extends Equatable {
  final String id;
  final bool autoAddPurchases;
  final bool suggestionsEnabled;

  const ClosetSettings({
    required this.id,
    this.autoAddPurchases = true,
    this.suggestionsEnabled = true,
  });

  @override
  List<Object?> get props => [id, autoAddPurchases, suggestionsEnabled];
}

class SlotCount extends Equatable {
  final String slot;
  final String label;
  final int count;

  const SlotCount({required this.slot, required this.label, required this.count});

  @override
  List<Object?> get props => [slot, count];
}

/// The closet's front page.
class ClosetOverview extends Equatable {
  final ClosetSettings settings;
  final String season;
  final String seasonLabel;

  final int itemsCount;
  final int archivedCount;
  final int looksCount;
  final int completeLooksCount;
  final int wornThisMonth;

  /// How many complete outfits her wardrobe can produce, and how many of those
  /// work in the weather she is actually in. The gap between the two is the
  /// seasonal story, and it is the most useful thing the header can say.
  final int outfitCapacity;
  final int seasonOutfitCapacity;

  final List<SlotCount> slotCounts;
  final List<ClosetItem> neglected;
  final List<ClosetGap> gaps;
  final ClosetVocabulary vocabulary;

  const ClosetOverview({
    required this.settings,
    required this.season,
    required this.seasonLabel,
    this.itemsCount = 0,
    this.archivedCount = 0,
    this.looksCount = 0,
    this.completeLooksCount = 0,
    this.wornThisMonth = 0,
    this.outfitCapacity = 0,
    this.seasonOutfitCapacity = 0,
    this.slotCounts = const [],
    this.neglected = const [],
    this.gaps = const [],
    this.vocabulary = const ClosetVocabulary(),
  });

  bool get isEmpty => itemsCount == 0;

  /// She owns clothes but cannot make a single outfit from them — almost always
  /// one missing slot, and the closet should say which rather than congratulate
  /// her on the count.
  bool get cannotDress => itemsCount > 0 && seasonOutfitCapacity == 0;

  @override
  List<Object?> get props => [itemsCount, looksCount, outfitCapacity, gaps.length];
}

/// One answer to "شو بقدر ألبس اليوم؟".
class TodayOutfit extends Equatable {
  final String key;

  /// `SAVED` — a look she built. `COMPOSED` — assembled from her pieces just
  /// now, which is what makes the feature useful on day one.
  final String origin;
  final String? lookId;
  final String? lookTitle;
  final String? occasionLabel;
  final double score;

  final List<ClosetTerm> reasons;
  final List<ClosetTerm> missingSlots;
  final List<ClosetItem> pieces;

  const TodayOutfit({
    required this.key,
    required this.origin,
    required this.score,
    this.lookId,
    this.lookTitle,
    this.occasionLabel,
    this.reasons = const [],
    this.missingSlots = const [],
    this.pieces = const [],
  });

  bool get isSaved => origin == 'SAVED';
  bool get isWearable => missingSlots.isEmpty;

  String get title => lookTitle ?? _composedTitle();

  String _composedTitle() {
    if (pieces.isEmpty) return 'إطلالة';
    return pieces.take(2).map((piece) => piece.title).join(' + ');
  }

  @override
  List<Object?> get props => [key, origin, score, pieces.length];
}

class TodayOutfits extends Equatable {
  final String season;
  final List<TodayOutfit> outfits;

  const TodayOutfits({required this.season, this.outfits = const []});

  @override
  List<Object?> get props => [season, outfits.length];
}

/// A page of closet items with its cursor.
class ClosetItemPage extends Equatable {
  final List<ClosetItem> items;
  final String? nextCursor;

  const ClosetItemPage({this.items = const [], this.nextCursor});

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [items.length, nextCursor];
}
