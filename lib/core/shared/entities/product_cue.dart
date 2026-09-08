// shared/entities/product_cue.dart

import 'package:equatable/equatable.dart';

/// One honest thing the marketplace can say about a listing.
///
/// The server sends these only when the claim is true — real scarcity across
/// the whole product rather than one boutique's shelf, an anchor against a
/// price that was genuinely charged, social proof above the count at which it
/// actually informs. When there is nothing true to say the list is empty, and
/// an empty list renders as nothing at all.
///
/// So the client's job here is small and strict: show what arrived, invent
/// nothing, and never soften an absent badge into a present one.
enum ProductCueKind { socialProof, scarcity, anchor, quality, unknown }

class ProductCue extends Equatable {
  const ProductCue({
    required this.kind,
    required this.label,
    required this.value,
  });

  final ProductCueKind kind;

  /// Ready to render, in Arabic, exactly as the server worded it. The client
  /// does not compose these: a badge assembled on the phone from a raw number
  /// is a badge that can drift from what the server was willing to claim.
  final String label;

  /// The figure behind it, so a card can style by magnitude without parsing
  /// the sentence.
  final num value;

  static ProductCueKind kindFrom(String? raw) => switch (raw) {
        'social_proof' => ProductCueKind.socialProof,
        'scarcity' => ProductCueKind.scarcity,
        'anchor' => ProductCueKind.anchor,
        'quality' => ProductCueKind.quality,
        _ => ProductCueKind.unknown,
      };

  @override
  List<Object?> get props => [kind, label, value];
}
