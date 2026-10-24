import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/policies/domain/entities/policy_document.dart';

/// The policy centre's data.
///
/// Every read here works without a session — the server answers the catalogue
/// and the documents to anyone — which is what lets the registration form name
/// what she is about to agree to before her account exists.
final class PoliciesRemoteDataSource extends BaseRemoteDataSource {
  const PoliciesRemoteDataSource(super.dio);

  /// Every published policy. `locale` decides which translation comes back;
  /// the server falls back to Arabic, which is the binding text anyway.
  Future<List<PolicySummary>> catalogue({required String locale}) async {
    final rows = await getList(
      ApiEndpoints.policies,
      query: {'locale': locale},
    );
    return rows
        .whereType<Map<String, dynamic>>()
        .map(policySummaryFromJson)
        .toList(growable: false);
  }

  /// What a new account of this kind has to sign. `role` is `buyer` or
  /// `seller` — the same vocabulary the registration endpoint takes.
  Future<List<PolicySummary>> requiredFor({
    required String role,
    required String locale,
  }) async {
    final rows = await getList(
      ApiEndpoints.policiesRequired,
      query: {'role': role, 'locale': locale},
    );
    return rows
        .whereType<Map<String, dynamic>>()
        .map(policySummaryFromJson)
        .toList(growable: false);
  }

  /// What this account still owes a signature on. Usually empty.
  Future<List<PolicySummary>> pending({required String locale}) async {
    final rows = await getList(
      ApiEndpoints.policiesPending,
      query: {'locale': locale},
    );
    return rows
        .whereType<Map<String, dynamic>>()
        .map(policySummaryFromJson)
        .toList(growable: false);
  }

  Future<PolicyDetail> document(String slug, {required String locale}) async {
    final json = await getJson(
      ApiEndpoints.policyDocument(slug),
      query: {'locale': locale},
    );
    return PolicyDetail(
      summary: policySummaryFromJson(json),
      body: json['body'] as String? ?? '',
      contentHash: json['content_hash'] as String? ?? '',
      availableLocales:
          (json['available_locales'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      history: (json['history'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => PolicyVersionRef(
              id: row['id'] as String? ?? '',
              version: row['version'] as int? ?? 0,
              isCurrent: row['is_current'] == true,
              publishedAt: _date(row['published_at']),
              effectiveAt: _date(row['effective_at']),
              changeNote: row['change_note'] as String?,
              requiresReacceptance: row['requires_reacceptance'] == true,
            ),
          )
          .toList(growable: false),
    );
  }

  /// One issue by id — including a retired one, which is what makes a receipt
  /// openable against the text it was signed against.
  Future<PolicyDetail> version(String id, {required String locale}) async {
    final json = await getJson(
      ApiEndpoints.policyVersion(id),
      query: {'locale': locale},
    );
    return PolicyDetail(
      summary: PolicySummary(
        id: json['document_id'] as String? ?? '',
        kind: PolicyKind.parse(json['kind'] as String?),
        slug: json['slug'] as String? ?? '',
        audience: PolicyAudience.everyone,
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        versionId: json['id'] as String? ?? '',
        version: json['version'] as int? ?? 0,
        requiredForConsent: false,
        effectiveAt: _date(json['effective_at']),
        publishedAt: _date(json['published_at']),
        changeNote: json['change_note'] as String?,
      ),
      body: json['body'] as String? ?? '',
      contentHash: json['content_hash'] as String? ?? '',
      availableLocales: const [],
      history: const [],
    );
  }

  /// Her receipts, newest first.
  Future<List<PolicyReceipt>> acceptances({required String locale}) async {
    final rows = await getList(
      ApiEndpoints.policiesAcceptances,
      query: {'locale': locale},
    );
    return rows
        .whereType<Map<String, dynamic>>()
        .map((json) {
          return PolicyReceipt(
            id: json['id'] as String? ?? '',
            kind: PolicyKind.parse(json['kind'] as String?),
            slug: json['slug'] as String? ?? '',
            title: json['title'] as String? ?? '',
            versionId: json['version_id'] as String? ?? '',
            version: json['version'] as int? ?? 0,
            acceptedAt: _date(json['accepted_at']),
            source: json['source'] as String? ?? '',
            locale: json['locale'] as String? ?? '',
            isCurrent: json['is_current'] == true,
          );
        })
        .toList(growable: false);
  }

  /// Sign. Answers with whatever is *still* outstanding, so the consent gate
  /// closes itself on the response rather than asking again.
  Future<List<PolicySummary>> accept({
    required List<String> versionIds,
    required String locale,
  }) async {
    final json = await postJson(
      ApiEndpoints.policiesAccept,
      body: {'version_ids': versionIds, 'locale': locale},
    );
    return (json['pending'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(policySummaryFromJson)
        .toList(growable: false);
  }
}

/// Shared because four endpoints return the same shape — the catalogue, the
/// required set, the pending set, and the head of a document's detail.
PolicySummary policySummaryFromJson(Map<String, dynamic> json) {
  final acceptance = json['acceptance'] as Map<String, dynamic>?;
  return PolicySummary(
    id: json['id'] as String? ?? '',
    kind: PolicyKind.parse(json['kind'] as String?),
    slug: json['slug'] as String? ?? '',
    audience: PolicyAudience.parse(json['audience'] as String?),
    title: json['title'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    versionId: json['version_id'] as String? ?? '',
    version: json['version'] as int? ?? 0,
    requiredForConsent: json['required_for_consent'] == true,
    icon: json['icon'] as String?,
    effectiveAt: _date(json['effective_at']),
    publishedAt: _date(json['published_at']),
    changeNote: json['change_note'] as String?,
    acceptance: acceptance == null
        ? null
        : PolicyAcceptanceStamp(
            versionId: acceptance['version_id'] as String? ?? '',
            version: acceptance['version'] as int? ?? 0,
            acceptedAt: _date(acceptance['accepted_at']),
            isCurrent: acceptance['is_current'] == true,
          ),
  );
}

DateTime? _date(dynamic value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
