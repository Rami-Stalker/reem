import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/seller_returns/data/datasources/seller_returns_remote_datasource.dart';
import 'package:reem/features/seller_returns/data/models/return_request_model.dart';
import 'package:reem/features/seller_returns/domain/entities/return_request.dart';

/// Every one of these routes has existed since the returns module landed, and
/// not one of them had a caller. A seller could watch a parcel come back on her
/// order queue and had no way to accept it, refuse it, or say it had arrived.
///
/// Each action answers with the whole request as it now stands, so the screen
/// never has to guess what a transition did — including the refund figure,
/// which the server recomputes rather than the client deriving it.
final class SellerReturnsRemoteDataSourceImpl extends BaseRemoteDataSource
    implements SellerReturnsRemoteDataSource {
  const SellerReturnsRemoteDataSourceImpl(super.dio);

  @override
  Future<List<ReturnRequest>> queue({ReturnStatus? status}) async =>
      ReturnRequestMapper.listFromJson(
        await getList(
          ApiEndpoints.sellerReturns,
          query: {'status': ?status?.wire},
        ),
      );

  @override
  Future<ReturnRequest> detail(String id) async =>
      ReturnRequestMapper.fromJson(await getJson(ApiEndpoints.returnById(id)));

  @override
  Future<ReturnRequest> approve(
    String id, {
    ReturnCostBearer? shippingBorneBy,
    String? note,
  }) async => ReturnRequestMapper.fromJson(
    await postJson(
      ApiEndpoints.returnApprove(id),
      body: {
        'shipping_borne_by': ?shippingBorneBy?.wire,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    ),
  );

  @override
  Future<ReturnRequest> reject(String id, {required String reason}) async =>
      ReturnRequestMapper.fromJson(
        await postJson(
          ApiEndpoints.returnReject(id),
          body: {'reason': reason.trim()},
        ),
      );

  @override
  Future<ReturnRequest> markInTransit(String id) async =>
      ReturnRequestMapper.fromJson(
        await postJson(ApiEndpoints.returnInTransit(id)),
      );

  @override
  Future<ReturnRequest> receive(
    String id, {
    bool? restock,
    String? note,
  }) async => ReturnRequestMapper.fromJson(
    await postJson(
      ApiEndpoints.returnReceive(id),
      body: {
        'restock': ?restock,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    ),
  );

  @override
  Future<ReturnRequest> exchange(String id) async =>
      ReturnRequestMapper.fromJson(
        await postJson(ApiEndpoints.returnExchange(id)),
      );

  @override
  Future<ReturnRequest> exchangeDelivered(String id) async =>
      ReturnRequestMapper.fromJson(
        await postJson(ApiEndpoints.returnExchangeDelivered(id)),
      );
}
