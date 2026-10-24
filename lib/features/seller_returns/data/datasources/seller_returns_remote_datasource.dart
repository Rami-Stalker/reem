import 'package:ohara/features/seller_returns/domain/entities/return_request.dart';

abstract interface class SellerReturnsRemoteDataSource {
  Future<List<ReturnRequest>> queue({ReturnStatus? status});

  Future<ReturnRequest> detail(String id);

  Future<ReturnRequest> approve(
    String id, {
    ReturnCostBearer? shippingBorneBy,
    String? note,
  });

  Future<ReturnRequest> reject(String id, {required String reason});

  Future<ReturnRequest> markInTransit(String id);

  Future<ReturnRequest> receive(String id, {bool? restock, String? note});

  Future<ReturnRequest> exchange(String id);

  Future<ReturnRequest> exchangeDelivered(String id);
}
