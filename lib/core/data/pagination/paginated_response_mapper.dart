import 'package:reem/core/domain/pagination/paginated_data.dart';

typedef JsonFactory<T> = T Function(Map<String, dynamic> json);

abstract final class PaginatedResponseMapper {
  static PaginatedData<T> fromJson<T>(
    Map<String, dynamic> json, {
    required JsonFactory<T> itemFromJson,
    String dataKey = 'data',
    String paginationKey = 'pagination',
    int fallbackPage = 1,
    int fallbackLimit = 20,
  }) {
    final rawItems = json[dataKey];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => itemFromJson(Map<String, dynamic>.from(item)))
              .toList()
        : <T>[];

    final meta = json[paginationKey] is Map
        ? Map<String, dynamic>.from(json[paginationKey] as Map)
        : const <String, dynamic>{};

    final page =
        _intValue(meta, const ['page', 'current_page']) ?? fallbackPage;
    final limit = _intValue(meta, const ['limit', 'per_page']) ?? fallbackLimit;
    final totalItems = _intValue(meta, const ['total', 'total_items']);
    final totalPages = _intValue(meta, const ['total_pages', 'pages']);
    final hasNextPage =
        _boolValue(meta, const ['has_next_page', 'hasNextPage']) ??
        (totalPages == null ? false : page < totalPages);

    return PaginatedData<T>(
      items: items,
      pageInfo: PageInfo(
        page: page,
        limit: limit,
        totalItems: totalItems,
        totalPages: totalPages,
        hasNextPage: hasNextPage,
        nextCursor: _stringValue(meta, const ['next_cursor', 'nextCursor']),
      ),
    );
  }

  static int? _intValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  static bool? _boolValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
    }
    return null;
  }

  static String? _stringValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }
}
