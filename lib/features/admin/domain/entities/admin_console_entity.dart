class AdminRecord {
  const AdminRecord({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.metrics,
    required this.raw,
    this.createdAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String status;
  final Map<String, String> metrics;
  final Map<String, dynamic> raw;

  /// When the row was made, parsed rather than printed.
  ///
  /// This used to travel inside [metrics] as whatever string the server sent,
  /// which put `2026-09-10T01:53:18.694Z` on the face of every row in the
  /// console. A timestamp is only useful to an operator once it is in her
  /// language and her calendar, and the data layer has neither, so the parsed
  /// moment comes through here and the widget formats it.
  final DateTime? createdAt;

  /// Reads a field off the untyped record.
  ///
  /// The console is deliberately generic — one screen renders twelve different
  /// tables — so an action that needs to seed a form with the row's current
  /// value has to reach into the raw JSON. Doing it through one accessor keeps
  /// the casts and the `null` handling in a single place.
  String? field(String key) {
    final value = raw[key];
    if (value == null) return null;
    return value.toString();
  }

  bool? flag(String key) {
    final value = raw[key];
    return value is bool ? value : null;
  }
}

class AdminConsoleSection {
  const AdminConsoleSection({
    required this.key,
    required this.title,
    required this.records,
    this.summary = const {},
    this.page = 1,
    this.total = 0,
    this.hasMore = false,
  });

  final String key;
  final String title;
  final List<AdminRecord> records;
  final Map<String, String> summary;

  /// Which page [records] came from, and whether the server is holding more.
  ///
  /// The console used to render whatever single page the API returned and say
  /// nothing about the rest, so "25 users" and "25 of 11,402 users" looked
  /// identical on screen. [total] is what makes the difference sayable.
  final int page;
  final int total;
  final bool hasMore;

  AdminConsoleSection appending(AdminConsoleSection next) {
    return AdminConsoleSection(
      key: key,
      title: title,
      records: [...records, ...next.records],
      summary: next.summary,
      page: next.page,
      total: next.total,
      hasMore: next.hasMore,
    );
  }
}
