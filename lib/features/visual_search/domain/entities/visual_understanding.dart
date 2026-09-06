import 'package:equatable/equatable.dart';

/// Where an attribute came from, as the server labelled it.
///
/// Carried into the UI rather than flattened away, because the three are not
/// equally true and pretending otherwise is the dishonest version of this
/// screen. A colour was **measured** off her photograph. A category was
/// **inferred** from which catalogue rows matched. Something a model proposed
/// is neither. The chip row shows measured facts plainly and marks the rest as
/// a reading.
enum AttributeProvenance {
  pixels,
  neighbours,
  vision,
  unknown;

  static AttributeProvenance fromWire(String? value) => switch (value) {
    'PIXELS' => AttributeProvenance.pixels,
    'NEIGHBOURS' => AttributeProvenance.neighbours,
    'VISION' => AttributeProvenance.vision,
    _ => AttributeProvenance.unknown,
  };

  /// True when this was read off the pixels and is not an interpretation.
  bool get isMeasured => this == AttributeProvenance.pixels;
}

/// One colour the server found in her photograph.
class VisualColour extends Equatable {
  const VisualColour({
    required this.key,
    required this.label,
    required this.share,
  });

  /// The lexicon key — the same string the AI Stylist uses for this colour.
  final String key;

  /// The Arabic name, as the server rendered it.
  final String label;

  /// 0–1 share of the frame.
  final double share;

  @override
  List<Object?> get props => [key, label, share];
}

/// What the server understood from the photograph.
class VisualUnderstanding extends Equatable {
  const VisualUnderstanding({
    required this.colours,
    required this.pattern,
    required this.patternLabel,
    required this.tone,
    required this.toneLabel,
    required this.framing,
    required this.framingLabel,
    required this.categories,
    required this.chips,
    required this.confidence,
    required this.provenance,
  });

  static const empty = VisualUnderstanding(
    colours: [],
    pattern: 'plain',
    patternLabel: '',
    tone: 'mid',
    toneLabel: '',
    framing: 'product',
    framingLabel: '',
    categories: [],
    chips: [],
    confidence: 0,
    provenance: {},
  );

  final List<VisualColour> colours;
  final String pattern;
  final String patternLabel;
  final String tone;
  final String toneLabel;
  final String framing;
  final String framingLabel;

  /// Inferred from the catalogue neighbours, not read off the pixels.
  ///
  /// Carries the Arabic name beside the slug, because a slug is an identifier
  /// and the chip row is Arabic: rendering "الأقرب: abayas" is what happens
  /// when a screen is handed nothing else to show.
  final List<VisualCategory> categories;

  /// Ready-made Arabic labels for the chip row under the photograph.
  final List<VisualChip> chips;

  /// 0–1. How much of the picture the reading actually accounts for.
  final double confidence;

  final Map<String, AttributeProvenance> provenance;

  AttributeProvenance provenanceOf(String field) =>
      provenance[field] ?? AttributeProvenance.unknown;

  bool get isEmpty => chips.isEmpty && colours.isEmpty;

  @override
  List<Object?> get props => [
    colours,
    pattern,
    tone,
    framing,
    categories,
    chips,
    confidence,
  ];
}

/// A catalogue category the search believes the photograph belongs to.
class VisualCategory extends Equatable {
  const VisualCategory({required this.slug, required this.label});

  final String slug;

  /// The Arabic name. Falls back to the slug only when the server sent no
  /// name, which should not happen and is better than an empty chip.
  final String label;

  @override
  List<Object?> get props => [slug, label];
}

class VisualChip extends Equatable {
  const VisualChip({required this.key, required this.label});

  final String key;
  final String label;

  @override
  List<Object?> get props => [key, label];
}
