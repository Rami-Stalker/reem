import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';

import '../../../domain/entities/courier_assignment.dart';
import '../../models/courier_assignment_model.dart';
import '../courier_remote_datasource.dart';

final class CourierRemoteDataSourceImpl extends BaseRemoteDataSource
    implements CourierRemoteDataSource {
  const CourierRemoteDataSourceImpl(super.dio);

  @override
  Future<List<CourierAssignmentModel>> today() async {
    final rows = await getList(ApiEndpoints.courierToday);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(CourierAssignmentModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> pickUp(String shipmentId) async {
    await postJson(ApiEndpoints.shipmentPickUp(shipmentId));
  }

  @override
  Future<void> startDelivery(String shipmentId) async {
    await postJson(ApiEndpoints.shipmentOutForDelivery(shipmentId));
  }

  @override
  Future<void> deliver(
    String shipmentId, {
    String? collected,
    String? proofImageUrl,
    String? recipientNote,
  }) async {
    await postJson(
      ApiEndpoints.shipmentDeliver(shipmentId),
      body: {
        // Omitted entirely rather than sent as null: the backend reads absence
        // as "collected exactly what was due", which is the common case.
        if (collected != null) 'collected': collected,
        if (proofImageUrl != null) 'proof_image_url': proofImageUrl,
        if (recipientNote != null) 'recipient_note': recipientNote,
      },
    );
  }

  @override
  Future<void> fail(
    String shipmentId,
    DeliveryFailureReason reason, {
    String? note,
  }) async {
    await postJson(
      ApiEndpoints.shipmentFail(shipmentId),
      body: {'reason': reason.wire, if (note != null) 'note': note},
    );
  }
}
