import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';

/// The fourteen governorates, where the map flies to when she taps one.
///
/// The names are the platform's own spelling — the one the shipping zones,
/// the address book and every order already use — and the aliases are how
/// OpenStreetMap, in either language, tends to write the same place.
@immutable
class SyriaGovernorate {
  const SyriaGovernorate(
    this.name,
    this.center, {
    this.zoom = 11,
    this.aliases = const [],
  });

  final String name;
  final LatLng center;
  final double zoom;
  final List<String> aliases;
}

abstract final class SyriaGovernorates {
  /// Roughly the middle of the country, at a zoom that shows all of it.
  static const LatLng countryCenter = LatLng(34.8, 38.6);
  static const double countryZoom = 6.4;

  /// Damascus — where the map opens when nothing better is known.
  static const LatLng defaultCenter = LatLng(33.5138, 36.2765);

  static const List<SyriaGovernorate> all = [
    SyriaGovernorate(
      'دمشق',
      LatLng(33.5138, 36.2765),
      zoom: 12.5,
      aliases: ['Damascus', 'Dimashq', 'مدينة دمشق'],
    ),
    SyriaGovernorate(
      'ريف دمشق',
      LatLng(33.5700, 36.4000),
      zoom: 10,
      aliases: [
        'Rif Dimashq',
        'Rif Dimashq Governorate',
        'Damascus Countryside',
      ],
    ),
    SyriaGovernorate(
      'حلب',
      LatLng(36.2021, 37.1343),
      zoom: 12,
      aliases: ['Aleppo', 'Halab'],
    ),
    SyriaGovernorate(
      'حمص',
      LatLng(34.7324, 36.7137),
      zoom: 12.5,
      aliases: ['Homs'],
    ),
    SyriaGovernorate(
      'حماة',
      LatLng(35.1318, 36.7578),
      zoom: 12.5,
      aliases: ['Hama', 'Hamah', 'حماه'],
    ),
    SyriaGovernorate(
      'اللاذقية',
      LatLng(35.5317, 35.7915),
      zoom: 12.5,
      aliases: ['Latakia', 'Lattakia', 'Al-Ladhiqiyah'],
    ),
    SyriaGovernorate(
      'طرطوس',
      LatLng(34.8890, 35.8866),
      zoom: 13,
      aliases: ['Tartus', 'Tartous'],
    ),
    SyriaGovernorate(
      'إدلب',
      LatLng(35.9306, 36.6339),
      zoom: 12.5,
      aliases: ['Idlib', 'Idleb', 'ادلب'],
    ),
    SyriaGovernorate(
      'درعا',
      LatLng(32.6189, 36.1021),
      zoom: 12.5,
      aliases: ['Daraa', "Dar'a"],
    ),
    SyriaGovernorate(
      'السويداء',
      LatLng(32.7090, 36.5695),
      zoom: 13,
      aliases: ['As-Suwayda', 'Sweida', 'Suwayda'],
    ),
    SyriaGovernorate(
      'القنيطرة',
      LatLng(33.1260, 35.8240),
      zoom: 12,
      aliases: ['Quneitra', 'Al-Qunaytirah'],
    ),
    SyriaGovernorate(
      'دير الزور',
      LatLng(35.3359, 40.1408),
      zoom: 12.5,
      aliases: ['Deir ez-Zor', 'Deir Ezzor', 'Dayr az Zawr'],
    ),
    SyriaGovernorate(
      'الرقة',
      LatLng(35.9594, 39.0079),
      zoom: 12.5,
      aliases: ['Raqqa', 'Ar-Raqqah'],
    ),
    SyriaGovernorate(
      'الحسكة',
      LatLng(36.5024, 40.7477),
      zoom: 12.5,
      aliases: ['Al-Hasakah', 'Hasakah', 'Hassakeh'],
    ),
  ];

  /// The governorate called [name] in any of its spellings, or null.
  static SyriaGovernorate? byName(String? name) {
    if (name == null) return null;
    final wanted = normalizePlaceName(name);
    for (final governorate in all) {
      if (normalizePlaceName(governorate.name) == wanted) return governorate;
      for (final alias in governorate.aliases) {
        if (normalizePlaceName(alias) == wanted) return governorate;
      }
    }
    return null;
  }
}

/// Folds the ways one place name is written into one key.
///
/// «محافظة ريف دمشق», «ريف دمشق» and «Rif Dimashq Governorate» must meet:
/// the geocoder adds an administrative word the platform does not use, Arabic
/// has three alefs and two ways to end «حماة», and English has hyphens and
/// a definite article that comes and goes.
String normalizePlaceName(String value) {
  var text = value.trim().toLowerCase();
  text = text
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp('[ً-ْـ]'), '') // harakat and tatweel
      .replaceAll(RegExp(r'^محافظه\s+'), '')
      .replaceAll(RegExp(r'^مدينه\s+'), '')
      // OSM names a quarter with its administrative word — «بلدية الشاغور»,
      // «حي باب توما» — and a delivery zone is just «الشاغور».
      .replaceAll(RegExp(r'^(بلديه|حي|منطقه|ناحيه)\s+'), '')
      .replaceAll(RegExp(r'\s+governorate$'), '')
      .replaceAll(RegExp(r'\s+province$'), '')
      .replaceAll(RegExp(r'^(al|as|ar|ad|ash|az|el)[-\s]'), '')
      .replaceAll(RegExp(r"[-'’`]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  return text.trim();
}

/// The option in [options] that names the same place as any of [candidates].
///
/// The checkout offers only the governorates the platform delivers to, by
/// the names the shipping zones use, so a geocoder's «محافظة حماه» has to be
/// turned into whichever option is spelled «حماة» — or into nothing, if the
/// platform does not deliver there.
String? matchPlaceName(Iterable<String> options, Iterable<String?> candidates) {
  final keyed = {
    for (final option in options) normalizePlaceName(option): option,
  };
  for (final candidate in candidates) {
    if (candidate == null || candidate.trim().isEmpty) continue;
    final direct = keyed[normalizePlaceName(candidate)];
    if (direct != null) return direct;

    // Through the canonical list: «Aleppo» → «حلب» → the option «حلب».
    final known = SyriaGovernorates.byName(candidate);
    if (known != null) {
      final viaKnown = keyed[normalizePlaceName(known.name)];
      if (viaKnown != null) return viaKnown;
    }
  }
  return null;
}
