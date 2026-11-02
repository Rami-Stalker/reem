import 'package:ohara/features/seller_orders/domain/entities/seller_order.dart';

abstract interface class SellerOrdersRemoteDataSource {
  /// [today] keeps only parcels placed today («طلبات اليوم»).
  Future<SellerOrderQueue> queue({
    SellerQueueTab? tab,
    int page,
    int limit,
    bool today,
  });

  Future<SellerOrderDetail> detail(String id);

  /// Every action answers with the parcel's new state, so the screen never has
  /// to guess what a transition produced — the server is the authority on what
  /// comes next and says so in the same round trip.
  Future<SellerOrderDetail> confirm(String id);

  Future<SellerOrderDetail> ready(String id);

  Future<SellerOrderDetail> handOver(String id, {String? carrier});

  Future<SellerOrderDetail> deliver(
    String id, {
    String? collected,
    String? note,
    String? handoverCode,
  });

  Future<SellerOrderDetail> outForDelivery(String id);

  Future<SellerOrderDetail> carrierPickedUp(String id);

  /// [reason] is the wire value: no_answer | wrong_address | customer_refused
  /// | postponed | unreachable_area | other.
  Future<SellerOrderDetail> fail(String id, {required String reason, String? note});

  Future<SellerOrderDetail> cancel(String id, {required String reason});
}
