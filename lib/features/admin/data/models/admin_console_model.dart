import 'dart:convert';

import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/core/shared/value_objects/money_format.dart';
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
          (item) => AdminRecordModel.fromJson(Map<String, dynamic>.from(item)),
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
                (item) =>
                    AdminRecordModel.fromJson(Map<String, dynamic>.from(item)),
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
    super.createdAt,
  });

  factory AdminRecordModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['number'] ?? json['key'] ?? '').toString();
    // `reason` sits high in the chain because a moderation case has no name of
    // any kind — only the complaint that opened it. Without it the row fell
    // through to `id` and a moderator read a queue of raw uuids.
    final title = _text(
          json['name'] ??
              json['title'] ??
              json['subject'] ??
              json['number'] ??
              json['business_name'] ??
              json['action'] ??
              json['reason'] ??
              json['key'],
        ) ??
        id;
    // No `fallbackKey` at the end of this one any more. Falling back to the
    // section key printed the literal word "reports" under every report and
    // "settings" under every setting — a line of text that told an operator
    // only which screen she was already looking at. An empty subtitle is
    // dropped by the row instead.
    final subtitle = _text(
          json['email'] ??
              json['phone'] ??
              json['customer'] ??
              json['seller_name'] ??
              json['description'] ??
              json['body'] ??
              json['actor_name'] ??
              json['category'] ??
              json['target_type'] ??
              json['type'] ??
              json['value'] ??
              json['seller_id'],
        ) ??
        '';
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
      'grand_total',
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
    ]) {
      final value = json[key];
      if (value == null) continue;
      final money = value is Map ? Money.tryFromJson(Map<String, dynamic>.from(value)) : null;
      // `17980.0000 SYP` was what the previous formatting produced, so the
      // orders queue showed either that or — because `grand_total` was not on
      // this list at all — no money whatsoever.
      metrics[key] = money != null
          ? money.approximateValue.sypCompact
          // A commission rule's rate arrives in basis points; «1000» beside
          // its name read as a price. Shown as the percentage it is.
          : key == 'rate_bps' && num.tryParse('$value') != null
          ? '${_trimZeros(num.parse('$value') / 100)}%'
          : value.toString();
    }
    return AdminRecordModel(
      id: id,
      title: title,
      subtitle: subtitle,
      status: status,
      metrics: metrics,
      raw: json,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal(),
    );
  }
}

String _trimZeros(num value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

/// A displayable string for a JSON value, or `null` when there is nothing to
/// show. Structured values are encoded rather than passed through Dart's
/// `toString`, which renders a map as `{a: 1}` — not JSON, and not anything an
/// operator can copy back into the editor.
String? _text(Object? value) {
  if (value == null) return null;
  if (value is String) return value.trim().isEmpty ? null : value;
  if (value is Map || value is List) return jsonEncode(value);
  return value.toString();
}

String? _firstListKey(Map<String, dynamic> json) {
  for (final entry in json.entries) {
    if (entry.value is List) return entry.key;
  }
  return null;
}
