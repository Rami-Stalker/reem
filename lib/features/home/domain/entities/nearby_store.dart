import 'package:equatable/equatable.dart';

/// A boutique near the customer, surfaced only when location is available.
class NearbyStore extends Equatable {
  const NearbyStore({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.area,
    required this.distanceKm,
    this.rating = 0,
    this.isOpen = true,
  });

  final String id;
  final String name;
  final String logoUrl;

  /// Human-readable locality, e.g. "Riyadh · Al Olaya".
  final String area;
  final double distanceKm;
  final double rating;
  final bool isOpen;

  @override
  List<Object?> get props => [id, name, logoUrl, area, distanceKm, rating, isOpen];
}
