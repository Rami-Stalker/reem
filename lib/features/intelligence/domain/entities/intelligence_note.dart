import 'package:flutter/foundation.dart';

/// One thing Reem has to say about a product, to this shopper.
///
/// The client's whole model of phase three. Deliberately small: a code, a
/// tone, a sentence and the rows behind it. The sentence is written on the
/// server beside the arithmetic that produced it, so the two can never drift
/// apart — the client's job is to decide how a tone looks, not what is true.
enum NoteTone {
  /// Something she should weigh before buying. Only ever the strongest note.
  caution,

  /// A reason this suits her in particular.
  encourage,

  /// A fact about the product or the market.
  inform;

  static NoteTone parse(String? raw) => switch (raw) {
    'caution' => NoteTone.caution,
    'encourage' => NoteTone.encourage,
    _ => NoteTone.inform,
  };
}

@immutable
class IntelligenceNote {
  const IntelligenceNote({
    required this.code,
    required this.tone,
    required this.ar,
    this.evidence = const {},
  });

  /// Stable across languages — the client keys icons and routes off this,
  /// never off the sentence.
  final String code;
  final NoteTone tone;
  final String ar;

  /// Ids the note is about: her closet items, a look, a cheaper product.
  /// Present so a note can become a tap rather than only a sentence.
  final Map<String, dynamic> evidence;

  /// The one note that is about *not* buying.
  bool get isCaution => tone == NoteTone.caution;

  /// Where a note leads, when it leads anywhere.
  String? get relatedProductId => evidence['productId'] as String?;
}
