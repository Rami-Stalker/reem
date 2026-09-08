import 'package:equatable/equatable.dart';

/// How loudly a finding asks to be looked at.
enum FindingSeverity { critical, warning, opportunity }

/// One thing the marketplace thinks somebody should look at today.
///
/// Every field here exists because a dashboard without it is a dashboard that
/// gets checked on Monday and abandoned by March: the [title] says what is
/// happening, [evidence] carries the numbers so the claim can be checked or
/// dismissed on its merits, and [action] names something a person can actually
/// do. The server never invents the last one — where the honest answer is
/// "look at this", that is what it says.
class AdminFinding extends Equatable {
  const AdminFinding({
    required this.code,
    required this.severity,
    required this.title,
    required this.action,
    required this.weight,
    this.href,
    this.evidence = const {},
  });

  factory AdminFinding.fromJson(Map<String, dynamic> json) => AdminFinding(
        code: json['code'] as String? ?? '',
        severity: _severityFrom(json['severity'] as String?),
        title: json['title'] as String? ?? '',
        action: json['action'] as String? ?? '',
        weight: (json['weight'] as num?)?.toInt() ?? 0,
        href: json['href'] as String?,
        evidence: (json['evidence'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  final String code;
  final FindingSeverity severity;
  final String title;
  final String action;

  /// How much attention it deserves *relative to everything else today* — not
  /// a severity. A critical finding about two customers can rank below a
  /// warning about two hundred, and the server has already ordered the list.
  final int weight;

  final String? href;
  final Map<String, dynamic> evidence;

  static FindingSeverity _severityFrom(String? raw) => switch (raw) {
        'critical' => FindingSeverity.critical,
        'warning' => FindingSeverity.warning,
        _ => FindingSeverity.opportunity,
      };

  @override
  List<Object?> get props => [code, severity, title, action, weight, href];
}

/// The morning briefing.
class AdminBriefing extends Equatable {
  const AdminBriefing({
    required this.windowDays,
    required this.generatedAt,
    required this.findings,
    required this.quiet,
  });

  factory AdminBriefing.fromJson(Map<String, dynamic> json) => AdminBriefing(
        windowDays: (json['window_days'] as num?)?.toInt() ?? 30,
        generatedAt:
            DateTime.tryParse(json['generated_at'] as String? ?? '') ??
                DateTime.now(),
        findings: (json['findings'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AdminFinding.fromJson)
            .toList(growable: false),
        quiet: json['quiet'] as bool? ?? false,
      );

  final int windowDays;
  final DateTime generatedAt;
  final List<AdminFinding> findings;

  /// Sent explicitly rather than inferred from an empty list.
  ///
  /// "Nothing needs you today" is a useful thing to be told, and a screen that
  /// renders emptiness as a blank panel makes a quiet week look like a broken
  /// one.
  final bool quiet;

  @override
  List<Object?> get props => [windowDays, generatedAt, findings, quiet];
}
