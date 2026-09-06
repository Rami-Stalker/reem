import 'package:equatable/equatable.dart';

/// A boutique trading where she shops from.
///
/// "Near" is a locality, not a distance. No address on the platform carries
/// coordinates and no storefront carries opening hours, so the card that used
/// to promise a distance in kilometres and an open/closed light could only
/// have been inventing both. What the platform genuinely knows is her
/// governorate and her city -- which is also the line that decides same-day
/// delivery (Q61/Q62) -- so that is what this carries.
class NearbyStore extends Equatable {
  const NearbyStore({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.area,
    this.sameCity = false,
    this.rating,
  });

  final String id;
  final String name;
  final String logoUrl;

  /// The locality she matched on -- her city where they share one, otherwise
  /// the governorate.
  final String area;

  /// True when the boutique trades in her own city rather than merely inside
  /// her governorate.
  final bool sameCity;

  /// Null until customers have reviewed the boutique.
  final double? rating;

  @override
  List<Object?> get props => [id, name, logoUrl, area, sameCity, rating];
}
