import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';
import 'package:ohara/core/location/syria_governorates.dart';

/// Where she dropped the pin, and what the map could say about it.
///
/// Only [point] is certain. Every named part comes from a reverse geocoder
/// reading OpenStreetMap, which knows Damascus street by street and a village
/// in the Ghab plain by little more than its name — so each is nullable, and a
/// form that receives one treats it as a suggestion she can correct, never as
/// the address itself.
@immutable
class PickedPlace {
  const PickedPlace({
    required this.point,
    this.governorate,
    this.city,
    this.district,
    this.neighbourhood,
    this.road,
    this.houseNumber,
    this.displayName,
    this.isRural = false,
    this.countryCode,
  });

  final LatLng point;

  /// One of the fourteen governorates, already in the platform's own spelling
  /// («ريف دمشق», not «محافظة ريف دمشق») when it could be matched.
  final String? governorate;

  /// The town or city — «دمشق», «جرمانا», «السلمية».
  final String? city;

  /// The quarter or suburb a courier would ask for — «المزة», «باب توما».
  final String? district;

  /// A smaller part of the [district] when the map knows one.
  final String? neighbourhood;

  final String? road;
  final String? houseNumber;

  /// The geocoder's whole sentence, used when nothing finer was found.
  final String? displayName;

  /// A village or hamlet rather than a town. Q53 prices these separately, so
  /// it pre-selects the rural tier; she can still switch it.
  final bool isRural;

  /// ISO 3166 code in lower case, when the geocoder answered.
  final String? countryCode;

  /// Dropped outside the country the platform delivers in. Null-safe: a pin
  /// the geocoder could not read is given the benefit of the doubt.
  bool get isOutsideSyria => countryCode != null && countryCode != 'sy';

  double get latitude => point.latitude;
  double get longitude => point.longitude;

  /// «شارع الجلاء، بناء 12، المزة» — the line a courier reads at the door.
  ///
  /// Falls back to the neighbourhood, then the geocoder's sentence, so a pin
  /// dropped on a field still produces something she can edit rather than an
  /// empty required field.
  String? get addressLine {
    final parts = _distinct([
      if (road != null) houseNumber == null ? road : '${road!} $houseNumber',
      neighbourhood,
      district,
    ], exclude: [city, governorate]);
    if (parts.isNotEmpty) return parts.join('، ');
    final sentence = displayName;
    if (sentence == null) return null;
    // The sentence ends with the governorate and the country; the form already
    // has those, so only the first, most specific pieces are kept.
    final pieces = sentence.split(RegExp(r'[,،]\s*'));
    return pieces.take(3).join('، ');
  }

  /// The whole address on one line, street first and governorate last —
  /// for a form that has a single address box rather than separate fields.
  String? get fullAddress {
    final parts = _distinct([addressLine, city, governorate]);
    return parts.isEmpty ? null : parts.join('، ');
  }

  /// [parts] in order, without the ones an earlier part already says.
  ///
  /// OpenStreetMap repeats itself: at Bab Touma it answers «ساحة باب توما»,
  /// «باب توما» and «حي باب توما» for road, neighbourhood and district. Read
  /// out in full that is the same place three times, so a part whose name is
  /// already inside an earlier one — or inside [exclude] — is dropped.
  static List<String> _distinct(
    List<String?> parts, {
    List<String?> exclude = const [],
  }) {
    final kept = <String>[];
    final seen = [
      for (final other in exclude)
        if (other != null && other.trim().isNotEmpty) normalizePlaceName(other),
    ];
    for (final part in parts) {
      if (part == null || part.trim().isEmpty) continue;
      final key = normalizePlaceName(part);
      if (seen.any((other) => other.contains(key))) continue;
      seen.add(key);
      kept.add(part.trim());
    }
    return kept;
  }

  /// What the confirmation card shows as its headline.
  String get headline =>
      road ?? neighbourhood ?? district ?? city ?? governorate ?? '';

  /// What it shows underneath: the larger places this one sits in.
  String get subtitle => [
    if (district != null && district != headline) district!,
    if (city != null && city != headline) city!,
    if (governorate != null && governorate != city) governorate!,
  ].join('، ');

  /// «33.51380, 36.27650» — five places is about a metre.
  String get coordinatesLabel =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  PickedPlace copyWith({String? governorate}) => PickedPlace(
    point: point,
    governorate: governorate ?? this.governorate,
    city: city,
    district: district,
    neighbourhood: neighbourhood,
    road: road,
    houseNumber: houseNumber,
    displayName: displayName,
    isRural: isRural,
    countryCode: countryCode,
  );
}

/// A place the search box found.
@immutable
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.point,
    required this.title,
    required this.subtitle,
    this.kind,
  });

  final LatLng point;
  final String title;
  final String subtitle;

  /// OSM's class for it — `amenity`, `shop`, `highway`, `place`… — so the
  /// list can draw a fitting icon.
  final String? kind;
}
