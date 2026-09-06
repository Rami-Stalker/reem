import 'package:equatable/equatable.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_recommendation.dart';

/// One "٩٤٪ مشابه" card.
///
/// The [product] is the ordinary catalogue [Product] — the same entity search,
/// discovery and the stylist hand to their cards — so a visual match renders
/// with the widgets the app already has. Everything else is what the visual
/// search adds: the percentage, the two halves it was made of, and the reason.
///
/// [feedback] reuses the stylist's enum deliberately. "She dismissed this card"
/// means the same thing whichever surface produced it, and one vocabulary is
/// what lets both feed the same taste profile.
class VisualMatch extends Equatable {
  const VisualMatch({
    required this.id,
    required this.product,
    required this.similarity,
    required this.similarityPercent,
    required this.visualScore,
    required this.attributeScore,
    required this.reason,
    required this.reasonCodes,
    this.offerId,
    this.matchedMediaUrl,
    this.quotedPrice,
    this.feedback = StylistFeedback.none,
  });

  final String id;
  final Product product;
  final String? offerId;

  /// The image of this listing that actually matched — often not its first.
  /// Shown on the card in place of the primary photograph, because it is the
  /// one the percentage is about.
  final String? matchedMediaUrl;

  /// 0–1. What the list is ordered by.
  final double similarity;

  /// The badge. Rounded on the server so every surface shows the same number.
  final int similarityPercent;

  /// How much it *looks* alike, calibrated. 0–1.
  final double visualScore;

  /// How much it agrees on colour, category, price and the rest. 0–1.
  final double attributeScore;

  /// Rendered server-side from the score components that actually fired.
  final String reason;

  /// The machine-readable version of [reason].
  final List<String> reasonCodes;

  final Money? quotedPrice;
  final StylistFeedback feedback;

  VisualMatch withFeedback(StylistFeedback next) => VisualMatch(
    id: id,
    product: product,
    similarity: similarity,
    similarityPercent: similarityPercent,
    visualScore: visualScore,
    attributeScore: attributeScore,
    reason: reason,
    reasonCodes: reasonCodes,
    offerId: offerId,
    matchedMediaUrl: matchedMediaUrl,
    quotedPrice: quotedPrice,
    feedback: next,
  );

  @override
  List<Object?> get props => [id, product.id, similarity, feedback];
}
