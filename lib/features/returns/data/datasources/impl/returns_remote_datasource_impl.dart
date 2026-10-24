import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/returns/data/datasources/returns_remote_datasource.dart';
import 'package:ohara/features/returns/data/models/return_eligibility_model.dart';
import 'package:ohara/features/returns/domain/entities/return_eligibility.dart';
import 'package:ohara/features/seller_returns/data/models/return_request_model.dart';
import 'package:ohara/features/seller_returns/domain/entities/return_request.dart';

final class ReturnsRemoteDataSourceImpl extends BaseRemoteDataSource
    implements ReturnsRemoteDataSource {
  const ReturnsRemoteDataSourceImpl(super.dio);

  @override
  Future<ReturnEligibility> eligibility(String sellerOrderId) async =>
      ReturnEligibilityMapper.fromJson(
        await getJson(ApiEndpoints.returnEligibility(sellerOrderId)),
      );

  @override
  Future<List<ReturnRequest>> mine() async =>
      ReturnRequestMapper.listFromJson(await getList(ApiEndpoints.returns));

  @override
  Future<ReturnRequest> request({
    required String sellerOrderId,
    required ReturnReason reason,
    String? reasonNote,
    List<String>? evidence,
    required List<({String orderItemId, int quantity})> items,
  }) async {
    final note = reasonNote?.trim();
    return ReturnRequestMapper.fromJson(
      await postJson(
        ApiEndpoints.returns,
        body: {
          'seller_order_id': sellerOrderId,
          'reason': reason.wire,
          if (note != null && note.isNotEmpty) 'reason_note': note,
          if (evidence != null && evidence.isNotEmpty) 'evidence': evidence,
          'items': [
            for (final line in items)
              {'order_item_id': line.orderItemId, 'quantity': line.quantity},
          ],
        },
      ),
    );
  }

  @override
  Future<ReturnRequest> cancel(String id) async =>
      ReturnRequestMapper.fromJson(
        await postJson(ApiEndpoints.returnCancel(id)),
      );
}
