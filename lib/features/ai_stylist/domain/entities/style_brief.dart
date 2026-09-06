import 'package:equatable/equatable.dart';

/// What the stylist understood from a message.
///
/// The server does the reading and hands the structure back; this type exists
/// so the client can *show* the understanding — the chips above the composer —
/// and so a filter she taps produces the same shape a sentence would have.
/// That symmetry is the point: there is one brief, whether she typed it or
/// picked it.
class StyleBrief extends Equatable {
  final String intent;

  final String? occasion;
  final String? occasionLabel;

  /// Enum names as the server spells them: `DRESS`, `SHOES`, `BAG`…
  final List<String> slots;
  final List<String> slotLabels;
  final List<String> categorySlugs;

  /// In SYP, matching the catalogue's normalised price columns.
  final num? budgetMin;
  final num? budgetMax;

  final List<StyleTerm> colours;
  final List<StyleTerm> avoidColours;

  final String? clothingSize;
  final String? shoeSize;

  final String modesty;
  final String modestyLabel;
  final List<StyleTerm> personas;
  final List<String> materials;

  final int? recipientAge;
  final bool forSelf;
  final int? deadlineDays;

  final List<String> keywords;
  final double confidence;

  /// Ready-to-render summary, built server-side so the labelling rules live
  /// in one place rather than being reimplemented per platform.
  final List<StyleTerm> chips;

  const StyleBrief({
    this.intent = 'FIND_PRODUCT',
    this.occasion,
    this.occasionLabel,
    this.slots = const [],
    this.slotLabels = const [],
    this.categorySlugs = const [],
    this.budgetMin,
    this.budgetMax,
    this.colours = const [],
    this.avoidColours = const [],
    this.clothingSize,
    this.shoeSize,
    this.modesty = 'UNSPECIFIED',
    this.modestyLabel = '',
    this.personas = const [],
    this.materials = const [],
    this.recipientAge,
    this.forSelf = true,
    this.deadlineDays,
    this.keywords = const [],
    this.confidence = 0,
    this.chips = const [],
  });

  static const empty = StyleBrief();

  bool get isOutfitRequest => intent == 'BUILD_OUTFIT';
  bool get isGiftRequest => intent == 'FIND_GIFT' || !forSelf;

  /// True when the assistant read enough to have searched for something.
  bool get hasConstraints =>
      slots.isNotEmpty ||
      occasion != null ||
      colours.isNotEmpty ||
      budgetMax != null;

  StyleBrief copyWith({
    String? intent,
    String? occasion,
    List<String>? slots,
    num? budgetMin,
    num? budgetMax,
    List<StyleTerm>? colours,
    String? clothingSize,
    String? shoeSize,
    String? modesty,
    int? recipientAge,
    bool? forSelf,
  }) {
    return StyleBrief(
      intent: intent ?? this.intent,
      occasion: occasion ?? this.occasion,
      occasionLabel: occasion == null ? occasionLabel : null,
      slots: slots ?? this.slots,
      slotLabels: slots == null ? slotLabels : const [],
      categorySlugs: categorySlugs,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      colours: colours ?? this.colours,
      avoidColours: avoidColours,
      clothingSize: clothingSize ?? this.clothingSize,
      shoeSize: shoeSize ?? this.shoeSize,
      modesty: modesty ?? this.modesty,
      modestyLabel: modesty == null ? modestyLabel : '',
      personas: personas,
      materials: materials,
      recipientAge: recipientAge ?? this.recipientAge,
      forSelf: forSelf ?? this.forSelf,
      deadlineDays: deadlineDays,
      keywords: keywords,
      confidence: confidence,
      chips: chips,
    );
  }

  @override
  List<Object?> get props => [
        intent,
        occasion,
        slots,
        categorySlugs,
        budgetMin,
        budgetMax,
        colours,
        avoidColours,
        clothingSize,
        shoeSize,
        modesty,
        personas,
        materials,
        recipientAge,
        forSelf,
        deadlineDays,
        keywords,
        confidence,
      ];
}

/// A key/label pair from one of the server's closed vocabularies.
///
/// The key is what travels back in a request; the label is what she reads.
/// Keeping both means the UI never has to translate an enum, and a vocabulary
/// that grows on the server grows in the app without a release.
class StyleTerm extends Equatable {
  final String key;
  final String label;

  const StyleTerm({required this.key, required this.label});

  @override
  List<Object?> get props => [key, label];
}
