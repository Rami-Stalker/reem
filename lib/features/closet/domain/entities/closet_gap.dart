import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';

enum ClosetGapKind {
  lookSlot,
  occasion,
  coverage,
  season,
  replacement;

  static ClosetGapKind fromWire(String? value) => switch (value) {
        'LOOK_SLOT' => ClosetGapKind.lookSlot,
        'OCCASION' => ClosetGapKind.occasion,
        'SEASON' => ClosetGapKind.season,
        'REPLACEMENT' => ClosetGapKind.replacement,
        _ => ClosetGapKind.coverage,
      };
}

/// Something her wardrobe is short of.
///
/// [headline] and [rationale] arrive pre-written from the server, rendered from
/// the same components that produced [priority]. The client does not compose
/// its own sentence: a phrase assembled here could claim something the
/// arithmetic never said, which is the one failure this feature cannot afford.
class ClosetGap extends Equatable {
  final String id;
  final ClosetGapKind kind;
  final String slot;
  final String slotLabel;
  final String? occasion;
  final String? occasionLabel;
  final String? seasonLabel;

  /// Set for a LOOK_SLOT gap: the outfit this would complete.
  final String? lookId;
  final String? lookTitle;

  final String headline;
  final String rationale;
  final double priority;

  /// The arithmetic, verbatim. Rendered by the "ليش؟" sheet so any number on a
  /// card can be taken apart back to the rows that produced it.
  final Map<String, num> components;

  final List<ClosetTerm> suggestedColours;
  final String? suggestedSize;
  final Money? suggestedBudgetMin;
  final Money? suggestedBudgetMax;

  const ClosetGap({
    required this.id,
    required this.kind,
    required this.slot,
    required this.slotLabel,
    required this.headline,
    required this.rationale,
    required this.priority,
    this.occasion,
    this.occasionLabel,
    this.seasonLabel,
    this.lookId,
    this.lookTitle,
    this.components = const {},
    this.suggestedColours = const [],
    this.suggestedSize,
    this.suggestedBudgetMin,
    this.suggestedBudgetMax,
  });

  /// How many extra outfits filling this would unlock. Only a coverage gap
  /// carries it.
  int? get outfitsUnlocked => components['outfits_unlocked']?.toInt();

  @override
  List<Object?> get props => [id, kind, slot, priority];
}

/// A product offered against a gap.
///
/// Two scores travel, and they answer different questions: [styleScore] is the
/// catalog's opinion — rating, seller, price, her stated taste — and
/// [pairingScore] is her wardrobe's. The UI shows the wardrobe's reasons,
/// because those are the ones no other screen in the app can give her.
class ClosetSuggestion extends Equatable {
  final Product product;
  final double score;
  final double styleScore;
  final double pairingScore;
  final List<String> styleReasons;
  final List<ClosetTerm> pairingReasons;
  final List<String> pairsWithItemIds;
  final List<String> completesLookIds;

  const ClosetSuggestion({
    required this.product,
    required this.score,
    this.styleScore = 0,
    this.pairingScore = 0,
    this.styleReasons = const [],
    this.pairingReasons = const [],
    this.pairsWithItemIds = const [],
    this.completesLookIds = const [],
  });

  bool get completesALook => completesLookIds.isNotEmpty;

  @override
  List<Object?> get props => [product.id, score];
}

/// A gap and what to buy for it.
class GapSuggestions extends Equatable {
  final ClosetGap gap;
  final List<ClosetSuggestion> suggestions;

  const GapSuggestions({required this.gap, this.suggestions = const []});

  @override
  List<Object?> get props => [gap.id, suggestions.length];
}

/// The product page's answer to "هل بتناسب خزانتي؟".
class ClosetPairing extends Equatable {
  final String slot;
  final double score;

  /// How many she already owns. Non-zero turns "أضيفي لخزانتك" into a warning
  /// worth reading before she buys a second one.
  final int alreadyOwned;

  final List<String> pairsWithItemIds;
  final List<String> completesLookIds;
  final List<String> reasons;

  const ClosetPairing({
    required this.slot,
    required this.score,
    this.alreadyOwned = 0,
    this.pairsWithItemIds = const [],
    this.completesLookIds = const [],
    this.reasons = const [],
  });

  bool get isOwned => alreadyOwned > 0;
  bool get pairsWithAnything => pairsWithItemIds.isNotEmpty;

  @override
  List<Object?> get props => [slot, score, alreadyOwned];
}
