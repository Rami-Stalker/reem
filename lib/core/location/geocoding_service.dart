import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:ohara/core/config/app_env.dart';
import 'package:ohara/core/location/picked_place.dart';
import 'package:ohara/core/location/syria_governorates.dart';

/// Turns a pin into an address, and a typed name into a pin.
///
/// Speaks the Nominatim API, which OpenStreetMap runs for free and which any
/// self-hosted or paid geocoder can stand in for through
/// `GEOCODER_BASE_URL`.
///
/// Deliberately its own [Dio], not the app's API client: that one attaches
/// her session token and device proof to every request, and neither has any
/// business reaching a third-party server.
class GeocodingService {
  GeocodingService({Dio? dio, String? baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? AppEnv.geocoderBaseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                // Nominatim's usage policy asks every client to identify
                // itself; anonymous traffic is the first to be blocked. A
                // browser forbids setting this header and identifies the page
                // itself, so the web build leaves it to the browser.
                if (!kIsWeb)
                  'User-Agent':
                      'Ohara/1.0 (+https://ohara.app; location picker)',
              },
            ),
          );

  final Dio _dio;

  /// The public server allows one request a second per client. A pin that
  /// settles three times in a second gets one answer, not a ban.
  static const _minInterval = Duration(milliseconds: 1100);
  DateTime _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Addresses already read, keyed to about ten metres — dragging the pin back
  /// to where it was costs nothing.
  final _reverseCache = <String, PickedPlace>{};
  static const _cacheSize = 64;

  Future<void> _waitTurn() async {
    final wait = _minInterval - DateTime.now().difference(_lastRequestAt);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    _lastRequestAt = DateTime.now();
  }

  /// What is at [point], or a place carrying only the point when the geocoder
  /// is unreachable — the pin is still the most useful thing she can send.
  Future<PickedPlace> reverse(
    LatLng point, {
    String language = 'ar',
    CancelToken? cancelToken,
  }) async {
    final key =
        '${point.latitude.toStringAsFixed(4)},'
        '${point.longitude.toStringAsFixed(4)},$language';
    final cached = _reverseCache[key];
    if (cached != null) return _withPoint(cached, point);

    await _waitTurn();
    if (cancelToken?.isCancelled ?? false) return PickedPlace(point: point);

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reverse',
        queryParameters: {
          'format': 'jsonv2',
          'lat': point.latitude,
          'lon': point.longitude,
          'zoom': 18,
          'addressdetails': 1,
          'accept-language': language,
        },
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null || data['error'] != null) {
        return PickedPlace(point: point);
      }

      final place = _placeFrom(point, data);
      _reverseCache[key] = place;
      if (_reverseCache.length > _cacheSize) {
        _reverseCache.remove(_reverseCache.keys.first);
      }
      return place;
    } on DioException {
      return PickedPlace(point: point);
    }
  }

  /// Places matching [query], inside Syria, nearest [near] first when given.
  Future<List<PlaceSuggestion>> search(
    String query, {
    LatLng? near,
    String language = 'ar',
    CancelToken? cancelToken,
  }) async {
    final text = query.trim();
    if (text.length < 2) return const [];

    await _waitTurn();
    if (cancelToken?.isCancelled ?? false) return const [];

    try {
      final response = await _dio.get<List<dynamic>>(
        '/search',
        queryParameters: {
          'format': 'jsonv2',
          'q': text,
          'countrycodes': 'sy',
          'limit': 8,
          'addressdetails': 1,
          'accept-language': language,
          // Biases, does not restrict: a search for «الحميدية» from Homs
          // should still find the souq in Damascus.
          if (near != null)
            'viewbox':
                '${near.longitude - 0.6},${near.latitude + 0.6},'
                '${near.longitude + 0.6},${near.latitude - 0.6}',
        },
        cancelToken: cancelToken,
      );
      final rows = response.data ?? const [];
      return [
        for (final row in rows.whereType<Map<String, dynamic>>())
          ?_suggestionFrom(row),
      ];
    } on DioException {
      return const [];
    }
  }

  static PickedPlace _withPoint(PickedPlace place, LatLng point) => PickedPlace(
    point: point,
    governorate: place.governorate,
    city: place.city,
    district: place.district,
    neighbourhood: place.neighbourhood,
    road: place.road,
    houseNumber: place.houseNumber,
    displayName: place.displayName,
    isRural: place.isRural,
    countryCode: place.countryCode,
  );

  static String? _text(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static PickedPlace _placeFrom(LatLng point, Map<String, dynamic> data) {
    final address = (data['address'] as Map?)?.cast<String, dynamic>() ?? {};
    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = _text(address, key);
        if (value != null) return value;
      }
      return null;
    }

    final state = pick(['state', 'province', 'region']);
    final city = pick(['city', 'town', 'village', 'hamlet', 'municipality']);
    final isRural =
        _text(address, 'city') == null &&
        _text(address, 'town') == null &&
        (_text(address, 'village') != null || _text(address, 'hamlet') != null);

    // Damascus is its own governorate, and OSM sometimes files the city with
    // no state at all — the city's name then stands for both.
    final governorate =
        SyriaGovernorates.byName(state)?.name ??
        SyriaGovernorates.byName(city)?.name ??
        (state == null ? null : _stripAdministrative(state));

    return PickedPlace(
      point: point,
      governorate: governorate,
      city: city,
      district: pick(['suburb', 'city_district', 'quarter', 'borough']),
      neighbourhood: pick(['neighbourhood', 'quarter', 'residential']),
      road: pick(['road', 'pedestrian', 'street', 'footway']),
      houseNumber: _text(address, 'house_number'),
      displayName: _text(data, 'display_name'),
      isRural: isRural,
      countryCode: _text(address, 'country_code')?.toLowerCase(),
    );
  }

  static String _stripAdministrative(String value) => value
      .replaceFirst(RegExp(r'^محافظة\s+'), '')
      .replaceFirst(RegExp(r'\s+Governorate$'), '')
      .trim();

  static PlaceSuggestion? _suggestionFrom(Map<String, dynamic> row) {
    final lat = double.tryParse('${row['lat']}');
    final lon = double.tryParse('${row['lon']}');
    final sentence = _text(row, 'display_name');
    if (lat == null || lon == null || sentence == null) return null;

    final pieces = sentence.split(RegExp(r'[,،]\s*'));
    final title = _text(row, 'name') ?? pieces.first;
    final rest = pieces
        .where((piece) => piece != title)
        // The country is implied: every result is in Syria.
        .where((piece) => piece != 'سوريا' && piece != 'Syria')
        .take(3)
        .join('، ');

    return PlaceSuggestion(
      point: LatLng(lat, lon),
      title: title,
      subtitle: rest,
      kind: _text(row, 'category') ?? _text(row, 'class'),
    );
  }
}

final geocodingServiceProvider = Provider<GeocodingService>(
  (ref) => GeocodingService(),
);
