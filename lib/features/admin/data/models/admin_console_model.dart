import 'package:reem/features/admin/domain/entities/admin_console_entity.dart';

class AdminConsoleSectionModel extends AdminConsoleSection {
  const AdminConsoleSectionModel({
    required super.key,
    required super.title,
    required super.records,
    super.summary,
    super.page,
    super.total,
    super.hasMore,
  });

  /// A section from an endpoint that still answers with a bare array.
  ///
  /// Kept because not every admin list lives under `/admin` — the notification
  /// campaign endpoints are owned by another module and return plain lists.
  /// Such a section knows its own size and nothing more, so `total` is the
  /// length of what arrived and there is never a second page to ask for.
  factory AdminConsoleSectionModel.fromList({
    required String key,
    required String title,
    required List<dynamic> items,
  }) {
    final records = items
        .whereType<Map>()
        .map(
          (item) => AdminRecordModel.fromJson(
            Map<String, dynamic>.from(item),
            fallbackKey: key,
          ),
        )
        .toList();
    return AdminConsoleSectionModel(
      key: key,
      title: title,
      records: records,
      total: records.length,
    );
  }

  factory AdminConsoleSectionModel.fromMap({
    required String key,
    required String title,
    required Map<String, dynamic> json,
  }) {
    // `items` is the envelope every /admin list now speaks. The first-list-key
    // fallback stays for the endpoints that predate it and for the composite
    // payloads (commissions returns `rules` and `ledgers` side by side).
    final listKey = json['items'] is List ? 'items' : _firstListKey(json);
    final records = listKey == null
        ? <AdminRecord>[]
        : (json[listKey] as List)
              .whereType<Map>()
              .map(
                (item) => AdminRecordModel.fromJson(
                  Map<String, dynamic>.from(item),
                  fallbackKey: key,
                ),
              )
              .toList();

    const envelopeKeys = {'page', 'limit', 'total', 'has_more'};
    final summary = <String, String>{};
    for (final entry in json.entries) {
      if (entry.value is List || entry.value is Map) continue;
      if (envelopeKeys.contains(entry.key)) continue;
      if (entry.value == null) continue;
      summary[entry.key] = entry.value.toString();
    }

    return AdminConsoleSectionModel(
      key: key,
      title: title,
      records: records,
      summary: summary,
      page: json['page'] as int? ?? 1,
      total: json['total'] as int? ?? records.length,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

class AdminRecordModel extends AdminRecord {
  const AdminRecordModel({
    required super.id,
    required super.title,
    required super.subtitle,
    required super.status,
    required super.metrics,
    required super.raw,
  });

  factory AdminRecordModel.fromJson(
    Map<String, dynamic> json, {
    required String fallbackKey,
  }) {
    final id = (json['id'] ?? json['number'] ?? json['key'] ?? '').toString();
    final title =
        (json['name'] ??
                json['title'] ??
                json['subject'] ??
                json['number'] ??
                json['business_name'] ??
                json['action'] ??
                json['key'] ??
                id)
            .toString();
    final subtitle =
        (json['email'] ??
                json['phone'] ??
                json['customer'] ??
                json['seller_name'] ??
                json['seller_id'] ??
                json['description'] ??
                json['reason'] ??
                json['body'] ??
                json['actor_name'] ??
                json['category'] ??
                fallbackKey)
            .toString();
    final status =
        (json['status'] ??
                json['verification_status'] ??
                json['payment_status'] ??
                json['severity'] ??
                json['role'] ??
                'active')
            .toString();
    final metrics = <String, String>{};
    for (final key in [
      'total',
      'price',
      'amount',
      'gross',
      'commission',
      'net',
      'count',
      'priority',
      'rate_bps',
      'deliveries_count',
      'created_at',
    ]) {
      final value = json[key];
      if (value == null) continue;
      metrics[key] = value is Map && value['amount'] != null
          ? '${value['amount']} ${value['currency'] ?? ''}'.trim()
          : value.toString();
    }
    return AdminRecordModel(
      id: id,
      title: title,
      subtitle: subtitle,
      status: status,
      metrics: metrics,
      raw: json,
    );
  }
}

String? _firstListKey(Map<String, dynamic> json) {
  for (final entry in json.entries) {
    if (entry.value is List) return entry.key;
  }
  return null;
}
