import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/seller_orders/data/datasources/seller_orders_remote_datasource.dart';
import 'package:ohara/features/seller_orders/domain/entities/seller_order.dart';
import 'package:ohara/features/seller_orders/domain/repositories/seller_orders_repository.dart';

class SellerOrdersRepositoryImpl
    with RepositoryHandler
    implements SellerOrdersRepository {
  const SellerOrdersRepositoryImpl(this.remote);

  final SellerOrdersRemoteDataSource remote;

  @override
  Future<Result<SellerOrderQueue>> queue({
    SellerQueueTab? tab,
    int page = 1,
    int limit = 20,
  }) => guard(() => remote.queue(tab: tab, page: page, limit: limit));

  /// One entry point for every action.
  ///
  /// The alternative — five repository methods the notifier picks between —
  /// puts the same switch in the layer above and lets the two drift. Here the
  /// action *is* the parameter, so adding one is a single case.
  @override
  Future<Result<SellerOrderDetail>> act(
    String id,
    SellerOrderAction action, {
    String? reason,
    String? collected,
    String? carrier,
  }) => guard(
    () => switch (action) {
      SellerOrderAction.confirm => remote.confirm(id),
      SellerOrderAction.ready => remote.ready(id),
      SellerOrderAction.handOver => remote.handOver(id, carrier: carrier),
      SellerOrderAction.deliver => remote.deliver(id, collected: collected),
      SellerOrderAction.cancel => remote.cancel(id, reason: reason ?? ''),
    },
  );

  @override
  Future<Result<SellerOrderDetail>> detail(String id) =>
      guard(() => remote.detail(id));
}
