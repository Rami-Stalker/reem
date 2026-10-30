import 'package:equatable/equatable.dart';

import 'package:ohara/core/shared/entities/product.dart';

/// «مختارات مميزة» — a boutique's paid HOME_SPOTLIGHT slot.
///
/// Kept apart from every organic list on the page: it is drawn under its own
/// «إعلان» label, and it carries the offer that paid so a tap is credited to
/// that boutique and not to another that lists the same piece.
class SponsoredSpotlight extends Equatable {
  const SponsoredSpotlight({
    required this.product,
    required this.offerId,
    required this.storeId,
    required this.storeName,
    this.storeLogoUrl = '',
    this.storeTier,
  });

  final Product product;
  final String offerId;
  final String storeId;
  final String storeName;
  final String storeLogoUrl;

  /// `silver`, `gold`, `diamond` — or null for a free boutique.
  final String? storeTier;

  @override
  List<Object?> get props => [product.id, offerId, storeTier];
}
