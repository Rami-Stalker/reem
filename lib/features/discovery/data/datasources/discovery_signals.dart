import 'package:dio/dio.dart';

import 'package:reem/core/network/api_endpoints.dart';

/// The taps the server cannot see for itself.
///
/// Opening a product is recorded server-side; *why* it was opened is not. Two
/// things are reported from here: which search result she chose, and which
/// paid slot she tapped. Both are fire-and-forget — a lost signal is a gap in
/// a chart, and a tap that waited on analytics would be a slower app.
class DiscoverySignals {
  const DiscoverySignals(this._dio);

  final Dio _dio;

  /// She opened [productId] from the results for [query].
  void searchResultTapped({required String query, required String productId}) {
    final q = query.trim();
    if (q.isEmpty) return;
    _send(ApiEndpoints.searchClicks, {'q': q, 'product_id': productId});
  }

  /// She tapped a sponsored card — credited to the offer that paid for it.
  void sponsoredTapped({required String offerId, required String placement}) {
    _send(ApiEndpoints.sponsoredClicks, {
      'offer_id': offerId,
      'placement': placement,
    });
  }

  void _send(String path, Map<String, Object> body) {
    _dio.post<void>(path, data: body).then<void>(
      (_) {},
      onError: (Object _) {},
    );
  }
}
