import 'package:reem/core/design_system/components/badges/ds_badge.dart';
import 'package:reem/core/design_system/components/cards/product_card.dart';
import 'package:reem/core/shared/entities/product_cue.dart';

/// Turning what the server was willing to claim into what the card draws.
///
/// This lives in `patterns/` because it is the seam: the design system knows
/// nothing about a catalogue, and the catalogue knows nothing about badge
/// tones. Everything above it renders; everything below it decides what is
/// true.
///
/// The client's whole responsibility here is restraint. It does not compose a
/// badge, does not round a number up, and does not invent one when the list is
/// empty — an empty list is the server saying there was nothing honest to say,
/// and the correct rendering of that is nothing at all.
extension ProductCueBadges on List<ProductCue> {
  /// The cues as badges, strongest first.
  ///
  /// Tone carries meaning rather than decoration: scarcity is the only one
  /// that should feel urgent, because it is the only one with a deadline. An
  /// anchor is a saving, social proof is reassurance, quality is neutral
  /// information — and giving all four the same red pill would teach a shopper
  /// to stop reading any of them.
  List<DsProductCue> get asBadges => [
        for (final cue in this)
          DsProductCue(label: cue.label, tone: _toneFor(cue.kind)),
      ];

  /// The single most useful thing to say, for a card with room for one.
  ///
  /// The list already arrives ordered by the server, so this is the first —
  /// not a re-ranking on the phone, which could disagree with the ordering the
  /// server chose and did so for reasons the client cannot see.
  DsProductCue? get strongestBadge =>
      isEmpty ? null : asBadges.first;
}

DsBadgeTone _toneFor(ProductCueKind kind) => switch (kind) {
      ProductCueKind.scarcity => DsBadgeTone.warning,
      ProductCueKind.anchor => DsBadgeTone.sale,
      ProductCueKind.socialProof => DsBadgeTone.info,
      ProductCueKind.quality => DsBadgeTone.success,
      // A cue this build does not recognise still says something true — the
      // server sent it — so it is shown plainly rather than dropped. A client
      // that hides what it cannot categorise goes quiet exactly when the
      // platform starts saying something new.
      ProductCueKind.unknown => DsBadgeTone.neutral,
    };
