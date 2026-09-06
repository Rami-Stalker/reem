import 'package:reem/core/result/result.dart';
import 'package:reem/features/returns/domain/entities/return_eligibility.dart';
import 'package:reem/features/seller_returns/domain/entities/return_request.dart';

abstract interface class ReturnsRepository {
  Future<Result<ReturnEligibility>> eligibility(String sellerOrderId);

  Future<Result<List<ReturnRequest>>> mine();

  Future<Result<ReturnRequest>> request({
    required String sellerOrderId,
    required ReturnReason reason,
    String? reasonNote,
    List<String>? evidence,
    required List<({String orderItemId, int quantity})> items,
  });

  Future<Result<ReturnRequest>> cancel(String id);
}
