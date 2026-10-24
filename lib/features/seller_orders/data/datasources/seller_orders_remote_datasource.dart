import 'package:ohara/features/seller_orders/domain/entities/seller_order.dart';

abstract interface class SellerOrdersRemoteDataSource {
  Future<SellerOrderQueue> queue({SellerQueueTab? tab, int page, int limit});

  Future<SellerOrderDetail> detail(String id);

  /// Every action answers with the parcel's new state, so the screen never has
  /// to guess what a transition produced — the server is the authority on what
  /// comes next and says so in the same round trip.
  Future<SellerOrderDetail> confirm(String id);

  Future<SellerOrderDetail> ready(String id);

  Future<SellerOrderDetail> handOver(String id, {String? carrier});

  Future<SellerOrderDetail> deliver(String id, {String? collected, String? note});

  Future<SellerOrderDetail> cancel(String id, {required String reason});
}
