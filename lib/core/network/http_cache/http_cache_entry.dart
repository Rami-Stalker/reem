import 'dart:convert';

/// One cached HTTP response.
///
/// Only the parts worth replaying are kept: the decoded body, the status, and
/// the two timestamps that decide whether it may be served. Headers are
/// deliberately dropped — nothing in this client reads them off a cached
/// response, and storing them invites serving a stale `Set-Cookie`.
final class HttpCacheEntry {
  const HttpCacheEntry({
    required this.body,
    required this.statusCode,
    required this.storedAt,
    required this.expiresAt,
  });

  /// The decoded JSON body — a `Map` or a `List`, exactly as Dio handed it over.
  final Object? body;

  final int statusCode;

  /// When the response came off the wire. Surfaced to the UI so a screen can
  /// say "prices as of 12 minutes ago" rather than implying it is live.
  final DateTime storedAt;

  /// After this the entry is stale. Stale is not useless: an offline read and
  /// a stale-while-revalidate paint both serve it deliberately.
  final DateTime expiresAt;

  bool isFresh(DateTime now) => expiresAt.isAfter(now);

  Duration age(DateTime now) => now.difference(storedAt);

  Map<String, dynamic> toJson() => {
        'body': body,
        'status': statusCode,
        'stored_at': storedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      };

  /// Returns null rather than throwing on anything malformed. A cache is a
  /// convenience; a corrupt entry must degrade into a network fetch, never
  /// into a crash on a screen that would otherwise have loaded.
  static HttpCacheEntry? tryFromJson(Map<String, dynamic> json) {
    final storedAt = DateTime.tryParse('${json['stored_at']}');
    final expiresAt = DateTime.tryParse('${json['expires_at']}');
    final status = json['status'];
    if (storedAt == null || expiresAt == null || status is! int) return null;
    return HttpCacheEntry(
      body: json['body'],
      statusCode: status,
      storedAt: storedAt,
      expiresAt: expiresAt,
    );
  }

  String encode() => jsonEncode(toJson());

  static HttpCacheEntry? tryDecode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return tryFromJson(json);
    } on FormatException {
      return null;
    }
  }
}
