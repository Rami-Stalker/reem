import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/seller_returns/data/datasources/seller_returns_remote_datasource.dart';
import 'package:ohara/features/seller_returns/domain/entities/return_request.dart';
import 'package:ohara/features/seller_returns/domain/repositories/seller_returns_repository.dart';

class SellerReturnsRepositoryImpl
    with RepositoryHandler
    implements SellerReturnsRepository {
  const SellerReturnsRepositoryImpl(this.remote);

  final SellerReturnsRemoteDataSource remote;

  @override
  Future<Result<List<ReturnRequest>>> queue({ReturnStatus? status}) =>
      guard(() => remote.queue(status: status));

  @override
  Future<Result<ReturnRequest>> detail(String id) =>
      guard(() => remote.detail(id));

  @override
  Future<Result<ReturnRequest>> act(
    String id,
    ReturnAction action, {
    String? reason,
    String? note,
    bool? restock,
    ReturnCostBearer? shippingBorneBy,
  }) => guard(() => switch (action) {
    ReturnAction.approve => remote.approve(
      id,
      shippingBorneBy: shippingBorneBy,
      note: note,
    ),
    // The server requires one, and rightly: a refusal with no reason leaves
    // the customer nothing to answer and the dispute that follows nothing
    // to weigh.
    ReturnAction.reject => remote.reject(id, reason: reason ?? ''),
    ReturnAction.markInTransit => remote.markInTransit(id),
    ReturnAction.receive => remote.receive(id, restock: restock, note: note),
    ReturnAction.exchange => remote.exchange(id),
    ReturnAction.exchangeDelivered => remote.exchangeDelivered(id),
  });
}
