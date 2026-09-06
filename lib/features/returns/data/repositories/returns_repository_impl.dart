import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/returns/data/datasources/returns_remote_datasource.dart';
import 'package:reem/features/returns/domain/entities/return_eligibility.dart';
import 'package:reem/features/returns/domain/repositories/returns_repository.dart';
import 'package:reem/features/seller_returns/domain/entities/return_request.dart';

class ReturnsRepositoryImpl with RepositoryHandler implements ReturnsRepository {
  const ReturnsRepositoryImpl(this.remote);

  final ReturnsRemoteDataSource remote;

  @override
  Future<Result<ReturnEligibility>> eligibility(String sellerOrderId) =>
      guard(() => remote.eligibility(sellerOrderId));

  @override
  Future<Result<List<ReturnRequest>>> mine() => guard(remote.mine);

  @override
  Future<Result<ReturnRequest>> request({
    required String sellerOrderId,
    required ReturnReason reason,
    String? reasonNote,
    List<String>? evidence,
    required List<({String orderItemId, int quantity})> items,
  }) => guard(
    () => remote.request(
      sellerOrderId: sellerOrderId,
      reason: reason,
      reasonNote: reasonNote,
      evidence: evidence,
      items: items,
    ),
  );

  @override
  Future<Result<ReturnRequest>> cancel(String id) =>
      guard(() => remote.cancel(id));
}
