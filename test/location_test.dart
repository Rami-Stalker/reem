import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ohara/core/location/geocoding_service.dart';
import 'package:ohara/core/location/picked_place.dart';
import 'package:ohara/core/location/syria_governorates.dart';

/// Answers every request with [body] and remembers what was asked.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);

  Object body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

GeocodingService _service(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://geo.test'))
    ..httpClientAdapter = adapter;
  return GeocodingService(dio: dio);
}

void main() {
  group('place names', () {
    test('the administrative word, alef forms and taa marbuta fold away', () {
      expect(normalizePlaceName('محافظة حماه'), normalizePlaceName('حماة'));
      expect(normalizePlaceName('إدلب'), normalizePlaceName('ادلب'));
      expect(
        normalizePlaceName('Rif Dimashq Governorate'),
        normalizePlaceName('rif dimashq'),
      );
    });

    test('Damascus and its countryside never meet', () {
      expect(
        matchPlaceName(['دمشق', 'ريف دمشق'], ['محافظة ريف دمشق']),
        'ريف دمشق',
      );
      expect(matchPlaceName(['دمشق', 'ريف دمشق'], ['محافظة دمشق']), 'دمشق');
    });

    test('an English name finds the Arabic option through the known list', () {
      expect(matchPlaceName(['حلب', 'حمص'], ['Aleppo Governorate']), 'حلب');
    });

    test('a quarter matches its zone without the administrative word', () {
      expect(
        matchPlaceName(['الشاغور', 'المزة'], ['بلدية الشاغور']),
        'الشاغور',
      );
      expect(matchPlaceName(['باب توما'], ['حي باب توما']), 'باب توما');
    });

    test('a governorate the platform does not deliver to matches nothing', () {
      expect(matchPlaceName(['دمشق'], ['محافظة حلب', null, '']), isNull);
    });

    test('the fourteen governorates are all reachable by name', () {
      expect(SyriaGovernorates.all, hasLength(14));
      for (final governorate in SyriaGovernorates.all) {
        expect(SyriaGovernorates.byName(governorate.name), same(governorate));
      }
    });
  });

  group('picked place', () {
    const point = LatLng(33.5, 36.25);

    test('the address line reads street, number, then quarter', () {
      const place = PickedPlace(
        point: point,
        governorate: 'دمشق',
        city: 'دمشق',
        district: 'المزة',
        road: 'شارع الجلاء',
        houseNumber: '12',
      );
      expect(place.addressLine, 'شارع الجلاء 12، المزة');
      expect(place.fullAddress, 'شارع الجلاء 12، المزة، دمشق');
      expect(place.headline, 'شارع الجلاء');
    });

    test('the same place named three ways is said once', () {
      const place = PickedPlace(
        point: point,
        governorate: 'دمشق',
        city: 'دمشق',
        district: 'حي باب توما',
        neighbourhood: 'باب توما',
        road: 'ساحة باب توما',
      );
      expect(place.addressLine, 'ساحة باب توما');
      expect(place.fullAddress, 'ساحة باب توما، دمشق');
    });

    test('a pin on an unnamed field still gives something to edit', () {
      const place = PickedPlace(
        point: point,
        displayName: 'طريق زراعي, عين الفيجة, ريف دمشق, سوريا',
      );
      expect(place.addressLine, 'طريق زراعي، عين الفيجة، ريف دمشق');
    });

    test('only a pin the geocoder placed abroad is outside', () {
      expect(const PickedPlace(point: point).isOutsideSyria, isFalse);
      expect(
        const PickedPlace(point: point, countryCode: 'sy').isOutsideSyria,
        isFalse,
      );
      expect(
        const PickedPlace(point: point, countryCode: 'lb').isOutsideSyria,
        isTrue,
      );
    });
  });

  group('geocoder', () {
    test('a Damascus street is read into the platform spelling', () async {
      final adapter = _FakeAdapter({
        'display_name': 'شارع الجلاء, المزة, دمشق, محافظة دمشق, سوريا',
        'address': {
          'road': 'شارع الجلاء',
          'suburb': 'المزة',
          'city': 'دمشق',
          'state': 'محافظة دمشق',
          'country_code': 'sy',
        },
      });
      final place = await _service(adapter).reverse(const LatLng(33.5, 36.25));

      expect(place.governorate, 'دمشق');
      expect(place.city, 'دمشق');
      expect(place.district, 'المزة');
      expect(place.road, 'شارع الجلاء');
      expect(place.isRural, isFalse);
      expect(place.isOutsideSyria, isFalse);

      final query = adapter.requests.single.queryParameters;
      expect(query['accept-language'], 'ar');
      expect(query['addressdetails'], 1);
    });

    test('a village is rural and keeps its governorate', () async {
      final adapter = _FakeAdapter({
        'display_name': 'عين الفيجة, منطقة الزبداني, محافظة ريف دمشق, سوريا',
        'address': {
          'village': 'عين الفيجة',
          'county': 'منطقة الزبداني',
          'state': 'محافظة ريف دمشق',
          'country_code': 'sy',
        },
      });
      final place = await _service(
        adapter,
      ).reverse(const LatLng(33.6, 36.17));

      expect(place.governorate, 'ريف دمشق');
      expect(place.city, 'عين الفيجة');
      expect(place.isRural, isTrue);
    });

    test('dragging back to a spot already read asks nobody', () async {
      final adapter = _FakeAdapter({
        'address': {'city': 'حمص', 'state': 'محافظة حمص'},
      });
      final service = _service(adapter);
      await service.reverse(const LatLng(34.73241, 36.71371));
      final again = await service.reverse(const LatLng(34.73243, 36.71372));

      expect(adapter.requests, hasLength(1));
      expect(again.governorate, 'حمص');
      // The answer is reused, the pin is not: it stays where she put it.
      expect(again.point.latitude, 34.73243);
    });

    test('an error answer still returns the pin', () async {
      final adapter = _FakeAdapter({'error': 'Unable to geocode'});
      final place = await _service(adapter).reverse(const LatLng(35, 38));
      expect(place.point, const LatLng(35, 38));
      expect(place.governorate, isNull);
    });

    test('search stays inside Syria and drops the country from lines', () async {
      final adapter = _FakeAdapter([
        {
          'lat': '33.5112',
          'lon': '36.3069',
          'name': 'سوق الحميدية',
          'category': 'shop',
          'display_name': 'سوق الحميدية, دمشق القديمة, دمشق, سوريا',
        },
        {'lat': 'nope', 'lon': '1', 'display_name': 'broken'},
      ]);
      final results = await _service(adapter).search('الحميدية');

      expect(results, hasLength(1));
      expect(results.single.title, 'سوق الحميدية');
      expect(results.single.subtitle, 'دمشق القديمة، دمشق');
      expect(results.single.kind, 'shop');
      expect(adapter.requests.single.queryParameters['countrycodes'], 'sy');
    });

    test('a one-letter query is not sent', () async {
      final adapter = _FakeAdapter(const []);
      expect(await _service(adapter).search('د'), isEmpty);
      expect(adapter.requests, isEmpty);
    });
  });
}
