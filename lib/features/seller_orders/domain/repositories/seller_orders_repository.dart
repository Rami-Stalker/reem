import 'package:reem/core/result/result.dart';
import 'package:reem/features/seller_orders/domain/entities/seller_order.dart';

abstract interface class SellerOrdersRepository {
  Future<Result<SellerOrderQueue>> queue({
    SellerQueueTab? tab,
    int page,
    int limit,
  });

  Future<Result<SellerOrderDetail>> detail(String id);

  Future<Result<SellerOrderDetail>> act(
    String id,
    SellerOrderAction action, {
    String? reason,
    String? collected,
    String? carrier,
  });
}
