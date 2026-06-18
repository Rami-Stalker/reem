class AdminRecord {
  const AdminRecord({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.metrics,
    required this.raw,
  });

  final String id;
  final String title;
  final String subtitle;
  final String status;
  final Map<String, String> metrics;
  final Map<String, dynamic> raw;
}

class AdminConsoleSection {
  const AdminConsoleSection({
    required this.key,
    required this.title,
    required this.records,
    this.summary = const {},
  });

  final String key;
  final String title;
  final List<AdminRecord> records;
  final Map<String, String> summary;
}
