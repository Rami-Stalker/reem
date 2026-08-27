import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/entities/courier_assignment.dart';
import '../../domain/repositories/courier_repository.dart';
import '../datasources/courier_remote_datasource.dart';

class CourierRepositoryImpl with RepositoryHandler implements CourierRepository {
  const CourierRepositoryImpl(this.remote);

  final CourierRemoteDataSource remote;

  @override
  Future<Result<List<CourierAssignment>>> today() =>
      guard(() => remote.today());

  @override
  Future<Result<void>> pickUp(String shipmentId) =>
      guard(() => remote.pickUp(shipmentId));

  @override
  Future<Result<void>> startDelivery(String shipmentId) =>
      guard(() => remote.startDelivery(shipmentId));

  @override
  Future<Result<void>> deliver(
    String shipmentId, {
    String? collected,
    String? proofImageUrl,
    String? recipientNote,
  }) => guard(
    () => remote.deliver(
      shipmentId,
      collected: collected,
      proofImageUrl: proofImageUrl,
      recipientNote: recipientNote,
    ),
  );

  @override
  Future<Result<void>> fail(
    String shipmentId,
    DeliveryFailureReason reason, {
    String? note,
  }) => guard(() => remote.fail(shipmentId, reason, note: note));
}
