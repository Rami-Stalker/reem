import 'package:reem/features/admin/domain/entities/admin_console_entity.dart';

class AdminConsoleSectionModel extends AdminConsoleSection {
  const AdminConsoleSectionModel({
    required super.key,
    required super.title,
    required super.records,
    super.summary,
  });

  factory AdminConsoleSectionModel.fromList({
    required String key,
    required String title,
    required List<dynamic> items,
  }) {
    return AdminConsoleSectionModel(
      key: key,
      title: title,
      records: items
          .whereType<Map>()
          .map((item) => AdminRecordModel.fromJson(
                Map<String, dynamic>.from(item),
                fallbackKey: key,
              ))
          .toList(),
    );
  }

  factory AdminConsoleSectionModel.fromMap({
    required String key,
    required String title,
    required Map<String, dynamic> json,
  }) {
    final listKey = _firstListKey(json);
    final records = listKey == null
        ? <AdminRecord>[]
        : (json[listKey] as List)
            .whereType<Map>()
            .map((item) => AdminRecordModel.fromJson(
                  Map<String, dynamic>.from(item),
                  fallbackKey: key,
                ))
            .toList();
    final summary = <String, String>{};
    for (final entry in json.entries) {
      if (entry.value is! List && entry.value is! Map) {
        summary[entry.key] = entry.value.toString();
      }
    }
    return AdminConsoleSectionModel(
      key: key,
      title: title,
      records: records,
      summary: summary,
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
    final title = (json['name'] ??
            json['title'] ??
            json['subject'] ??
            json['number'] ??
            json['business_name'] ??
            id)
        .toString();
    final subtitle = (json['email'] ??
            json['phone'] ??
            json['customer'] ??
            json['seller_name'] ??
            json['description'] ??
            json['body'] ??
            fallbackKey)
        .toString();
    final status = (json['status'] ??
            json['role'] ??
            json['verification_status'] ??
            json['payment_status'] ??
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
      'deliveries_count',
      'created_at',
    ]) {
      if (json[key] != null) metrics[key] = json[key].toString();
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
