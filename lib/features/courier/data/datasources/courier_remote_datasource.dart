import 'package:reem/features/courier/data/models/courier_assignment_model.dart';
import 'package:reem/features/courier/domain/entities/courier_assignment.dart';

abstract interface class CourierRemoteDataSource {
  /// Q55 — «يشوف طلباته لليوم».
  Future<List<CourierAssignmentModel>> today();

  Future<void> pickUp(String shipmentId);
  Future<void> startDelivery(String shipmentId);

  /// Q55 — «يسجّل مبلغ التحصيل» + «يرفع صورة إثبات تسليم».
  Future<void> deliver(
    String shipmentId, {
    String? collected,
    String? proofImageUrl,
    String? recipientNote,
  });

  /// Q55 — «يسجّل سبب فشل التسليم».
  Future<void> fail(
    String shipmentId,
    DeliveryFailureReason reason, {
    String? note,
  });
}
