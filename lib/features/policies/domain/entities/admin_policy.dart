import 'package:meta/meta.dart';

/// A version's state, as the console sees it.
///
/// Only a [draft] can be edited or thrown away. [published] is the live
/// contract; [archived] is somebody's evidence of what she agreed to. The
/// server enforces all three — this enum only decides what the screen offers.
enum AdminPolicyStatus {
  draft,
  published,
  archived;

  static AdminPolicyStatus parse(String? value) =>
      switch (value?.toUpperCase()) {
        'PUBLISHED' => AdminPolicyStatus.published,
        'ARCHIVED' => AdminPolicyStatus.archived,
        _ => AdminPolicyStatus.draft,
      };
}

@immutable
class AdminPolicyTranslation {
  const AdminPolicyTranslation({
    required this.locale,
    required this.title,
    required this.summary,
    required this.body,
  });

  factory AdminPolicyTranslation.fromJson(Map<String, dynamic> json) =>
      AdminPolicyTranslation(
        locale: json['locale'] as String? ?? 'ar',
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );

  final String locale;
  final String title;
  final String summary;
  final String body;

  AdminPolicyTranslation copyWith({
    String? title,
    String? summary,
    String? body,
  }) => AdminPolicyTranslation(
    locale: locale,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    body: body ?? this.body,
  );
}

@immutable
class AdminPolicyVersion {
  const AdminPolicyVersion({
    required this.id,
    required this.version,
    required this.status,
    required this.requiresReacceptance,
    required this.translations,
    this.changeNote,
    this.publishedAt,
    this.effectiveAt,
  });

  factory AdminPolicyVersion.fromJson(Map<String, dynamic> json) =>
      AdminPolicyVersion(
        id: json['id'] as String? ?? '',
        version: json['version'] as int? ?? 0,
        status: AdminPolicyStatus.parse(json['status'] as String?),
        requiresReacceptance: json['requires_reacceptance'] == true,
        changeNote: json['change_note'] as String?,
        publishedAt: _date(json['published_at']),
        effectiveAt: _date(json['effective_at']),
        translations: (json['translations'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AdminPolicyTranslation.fromJson)
            .toList(growable: false),
      );

  final String id;
  final int version;
  final AdminPolicyStatus status;
  final bool requiresReacceptance;
  final String? changeNote;
  final DateTime? publishedAt;
  final DateTime? effectiveAt;
  final List<AdminPolicyTranslation> translations;

  AdminPolicyTranslation? translation(String locale) {
    for (final row in translations) {
      if (row.locale == locale) return row;
    }
    return null;
  }
}

@immutable
class AdminPolicyDocument {
  const AdminPolicyDocument({
    required this.id,
    required this.kind,
    required this.slug,
    required this.audience,
    required this.requiredForConsent,
    required this.isActive,
    required this.sortOrder,
    required this.acceptanceCount,
    required this.versions,
    this.icon,
  });

  factory AdminPolicyDocument.fromJson(Map<String, dynamic> json) =>
      AdminPolicyDocument(
        id: json['id'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        audience: json['audience'] as String? ?? 'EVERYONE',
        requiredForConsent: json['required_for_consent'] == true,
        isActive: json['is_active'] == true,
        sortOrder: json['sort_order'] as int? ?? 0,
        acceptanceCount: json['acceptance_count'] as int? ?? 0,
        icon: json['icon'] as String?,
        versions: (json['versions'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AdminPolicyVersion.fromJson)
            .toList(growable: false),
      );

  final String id;
  final String kind;
  final String slug;
  final String audience;
  final bool requiredForConsent;
  final bool isActive;
  final int sortOrder;

  /// How many signatures exist against this document, across every version.
  final int acceptanceCount;

  final String? icon;

  /// Newest version first, as the server orders them.
  final List<AdminPolicyVersion> versions;

  AdminPolicyVersion? get draft => _firstWhere(AdminPolicyStatus.draft);
  AdminPolicyVersion? get published => _firstWhere(AdminPolicyStatus.published);

  /// What the console shows as the document's name: the published title,
  /// falling back to the draft's for a document that has never been published.
  String title(String locale) {
    final version =
        published ?? draft ?? (versions.isEmpty ? null : versions.first);
    final translation =
        version?.translation(locale) ?? version?.translation('ar');
    final fallback = translation ?? version?.translations.firstOrNull;
    return fallback?.title ?? slug;
  }

  AdminPolicyVersion? _firstWhere(AdminPolicyStatus status) {
    for (final version in versions) {
      if (version.status == status) return version;
    }
    return null;
  }
}

/// How far a published version has landed across the population — the number
/// the console needs after a material change: is this reaching people, or has
/// nobody opened the app since.
@immutable
class AdminPolicyConsentStat {
  const AdminPolicyConsentStat({
    required this.documentId,
    required this.slug,
    required this.version,
    required this.requiresReacceptance,
    required this.acceptedCurrent,
    required this.acceptedAnyVersion,
  });

  final String documentId;
  final String slug;
  final int version;
  final bool requiresReacceptance;
  final int acceptedCurrent;
  final int acceptedAnyVersion;
}

DateTime? _date(dynamic value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
