import 'package:reem/core/result/result.dart';
import 'package:reem/features/seller_returns/domain/entities/return_request.dart';

/// What the seller may do about goods coming back.
///
/// There is deliberately no `refund` here. Paying a return out is the
/// platform's act — Q60 puts money in the accountant's hands — and a seller
/// who could press it would be deciding her own liability. A sweep settles it
/// once she confirms she has the goods.
abstract interface class SellerReturnsRepository {
  Future<Result<List<ReturnRequest>>> queue({ReturnStatus? status});

  Future<Result<ReturnRequest>> detail(String id);

  Future<Result<ReturnRequest>> act(
    String id,
    ReturnAction action, {
    String? reason,
    String? note,
    bool? restock,
    ReturnCostBearer? shippingBorneBy,
  });
}
