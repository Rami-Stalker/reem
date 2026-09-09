import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/admin/domain/entities/delivery_provider.dart';

/// The carrier desk's data.
///
/// Every route here is on Reem's own API. The app never calls a delivery
/// company: it has no base URL, no key and no reason to — the platform holds
/// the integration, and this screen reads and flips its switches.
final class DeliveryAdminRemoteDataSource extends BaseRemoteDataSource {
  const DeliveryAdminRemoteDataSource(super.dio);

  Future<List<DeliveryProviderAccount>> providers() async {
    final rows = await getList(ApiEndpoints.adminDeliveryProviders);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_provider)
        .toList(growable: false);
  }

  Future<DeliveryProviderAccount> setEnabled(String id, bool enabled) async {
    final json = await postJson(
      enabled
          ? ApiEndpoints.adminDeliveryProviderEnable(id)
          : ApiEndpoints.adminDeliveryProviderDisable(id),
    );
    return _provider(json);
  }

  Future<List<DeliveryDispatchRow>> dispatches({
    bool failedOnly = false,
    int limit = 25,
  }) async {
    final rows = await getList(
      ApiEndpoints.adminDeliveryDispatches,
      query: {
        'page': 1,
        'limit': limit,
        if (failedOnly) 'failed_only': true,
      },
    );
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_dispatch)
        .toList(growable: false);
  }

  Future<void> retry(String dispatchId) =>
      postJson(ApiEndpoints.adminDeliveryDispatchRetry(dispatchId));

  // ── Mapping ───────────────────────────────────────────────────────────

  DeliveryProviderAccount _provider(Map<String, dynamic> json) {
    final capabilities = json['capabilities'] as Map<String, dynamic>? ?? const {};
    final webhook = json['webhook'] as Map<String, dynamic>? ?? const {};

    return DeliveryProviderAccount(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      adapter: json['adapter'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'EXTERNAL_API',
      isEnabled: json['is_enabled'] == true,
      isDefault: json['is_default'] == true,
      priority: json['priority'] as int? ?? 100,
      governorates: (json['governorates'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      supportsQuote: capabilities['quote'] == true,
      supportsCancel: capabilities['cancel'] == true,
      supportsTracking: capabilities['tracking'] == true,
      supportsWebhook: capabilities['webhook'] == true,
      credentials: (json['credentials'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => DeliveryProviderCredential(
              field: row['field'] as String? ?? '',
              envKey: row['env_key'] as String? ?? '',
              isSet: row['is_set'] == true,
            ),
          )
          .toList(growable: false),
      adapterAvailable: json['adapter_available'] == true,
      webhookUrl: webhook['url'] as String? ?? '',
      lastError: json['last_error'] as String?,
      lastErrorAt: _date(json['last_error_at']),
      lastHealthyAt: _date(json['last_healthy_at']),
    );
  }

  DeliveryDispatchRow _dispatch(Map<String, dynamic> json) => DeliveryDispatchRow(
    id: json['id'] as String? ?? '',
    provider: json['provider'] as String? ?? '',
    orderNumber: json['order_number'] as String? ?? '',
    trackingCode: json['tracking_code'] as String? ?? '',
    status: json['status'] as String? ?? '',
    trackingNumber: json['tracking_number'] as String?,
    lastError: json['last_error'] as String?,
    createdAt: _date(json['created_at']),
  );

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}
