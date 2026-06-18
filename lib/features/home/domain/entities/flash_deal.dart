import 'package:equatable/equatable.dart';

import '../../../../core/shared/entities/product.dart';

/// A time-boxed, limited-quantity offer. The price/discount live on [product];
/// this adds the urgency layer — a deadline and a stock-claimed meter.
class FlashDeal extends Equatable {
  const FlashDeal({
    required this.product,
    required this.endsAt,
    required this.soldCount,
    required this.totalQuantity,
  });

  final Product product;
  final DateTime endsAt;
  final int soldCount;
  final int totalQuantity;

  /// Fraction of stock already claimed, clamped 0..1.
  double get claimedFraction =>
      totalQuantity <= 0 ? 0 : (soldCount / totalQuantity).clamp(0.0, 1.0);

  int get remainingQuantity =>
      (totalQuantity - soldCount).clamp(0, totalQuantity);

  /// Drives the "Almost gone!" urgency treatment.
  bool get isAlmostGone => claimedFraction >= 0.7;

  bool get hasEnded => DateTime.now().isAfter(endsAt);

  @override
  List<Object?> get props => [product, endsAt, soldCount, totalQuantity];
}
