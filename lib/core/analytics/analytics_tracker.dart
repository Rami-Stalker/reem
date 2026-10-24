import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';

/// The few moments only the phone can see.
///
/// The server records what it witnesses — a product page opening, a cart line,
/// a search, an order — and refuses those types from a client. What it cannot
/// witness is reported here: that she *opened* checkout, for one. Without that
/// step the funnel went straight from basket to order and every abandoned
/// checkout was invisible.
///
/// Signed-in sessions only: the endpoint stamps the event with the caller's
/// account, and a guest has none. Fire-and-forget; a dropped event is a gap in
/// a chart, never an error on her screen.
class AnalyticsTracker {
  const AnalyticsTracker(this._dio);

  final Dio _dio;

  void track(
    String type, {
    String? sellerId,
    String? productId,
    String? source,
    Map<String, Object?>? metadata,
  }) {
    _dio
        .post<void>(
          ApiEndpoints.analyticsEvents,
          data: {
            'type': type,
            'seller_id': ?sellerId,
            'product_id': ?productId,
            'source': ?source,
            'metadata': ?metadata,
          },
        )
        .then<void>((_) {}, onError: (Object _) {});
  }
}

final analyticsTrackerProvider = Provider<AnalyticsTracker>(
  (ref) => AnalyticsTracker(ref.watch(dioProvider)),
);
