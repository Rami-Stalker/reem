import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/seller_orders/data/datasources/seller_orders_remote_datasource.dart';
import 'package:ohara/features/seller_orders/data/models/seller_order_models.dart';
import 'package:ohara/features/seller_orders/domain/entities/seller_order.dart';

final class SellerOrdersRemoteDataSourceImpl extends BaseRemoteDataSource
    implements SellerOrdersRemoteDataSource {
  const SellerOrdersRemoteDataSourceImpl(super.dio);

  @override
  Future<SellerOrderQueue> queue({
    SellerQueueTab? tab,
    int page = 1,
    int limit = 20,
  }) async {
    final json = await getJson(
      ApiEndpoints.sellerOrders,
      query: {
        if (tab != null) 'tab': tab.wire,
        'page': page,
        'limit': limit,
      },
    );
    return SellerOrderMapper.queueFromJson(json);
  }

  @override
  Future<SellerOrderDetail> detail(String id) async =>
      SellerOrderMapper.detailFromJson(
        await getJson(ApiEndpoints.sellerOrderById(id)),
      );

  @override
  Future<SellerOrderDetail> confirm(String id) async =>
      SellerOrderMapper.detailFromJson(
        await postJson(ApiEndpoints.sellerOrderConfirm(id)),
      );

  @override
  Future<SellerOrderDetail> ready(String id) async =>
      SellerOrderMapper.detailFromJson(
        await postJson(ApiEndpoints.sellerOrderReady(id)),
      );

  @override
  Future<SellerOrderDetail> handOver(String id, {String? carrier}) async =>
      SellerOrderMapper.detailFromJson(
        await postJson(
          ApiEndpoints.sellerOrderHandOver(id),
          body: {if (carrier != null && carrier.isNotEmpty) 'carrier': carrier},
        ),
      );

  @override
  Future<SellerOrderDetail> deliver(
    String id, {
    String? collected,
    String? note,
    String? handoverCode,
  }) async => SellerOrderMapper.detailFromJson(
    await postJson(
      ApiEndpoints.sellerOrderDeliver(id),
      body: {
        // Sent as the decimal string it came in as. Money never becomes a
        // double on the way out any more than on the way in.
        if (collected != null && collected.isNotEmpty) 'collected': collected,
        if (note != null && note.isNotEmpty) 'note': note,
        if (handoverCode != null && handoverCode.isNotEmpty)
          'handover_code': handoverCode,
      },
    ),
  );

  @override
  Future<SellerOrderDetail> outForDelivery(String id) async =>
      SellerOrderMapper.detailFromJson(
        await postJson(ApiEndpoints.sellerOrderOutForDelivery(id)),
      );

  @override
  Future<SellerOrderDetail> carrierPickedUp(String id) async =>
      SellerOrderMapper.detailFromJson(
        await postJson(ApiEndpoints.sellerOrderCarrierPickedUp(id)),
      );

  @override
  Future<SellerOrderDetail> fail(
    String id, {
    required String reason,
    String? note,
  }) async => SellerOrderMapper.detailFromJson(
    await postJson(
      ApiEndpoints.sellerOrderFail(id),
      body: {
        // The server's enum is upper case; the wire elsewhere is lower.
        'reason': reason.toUpperCase(),
        if (note != null && note.isNotEmpty) 'note': note,
      },
    ),
  );

  @override
  Future<SellerOrderDetail> cancel(
    String id, {
    required String reason,
  }) async => SellerOrderMapper.detailFromJson(
    await postJson(ApiEndpoints.sellerOrderCancel(id), body: {'reason': reason}),
  );
}
