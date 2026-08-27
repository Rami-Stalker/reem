import '../../../../core/result/result.dart';
import '../entities/courier_assignment.dart';

abstract interface class CourierRepository {
  Future<Result<List<CourierAssignment>>> today();
  Future<Result<void>> pickUp(String shipmentId);
  Future<Result<void>> startDelivery(String shipmentId);
  Future<Result<void>> deliver(
    String shipmentId, {
    String? collected,
    String? proofImageUrl,
    String? recipientNote,
  });
  Future<Result<void>> fail(
    String shipmentId,
    DeliveryFailureReason reason, {
    String? note,
  });
}
