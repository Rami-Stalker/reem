import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/policies/domain/entities/admin_policy.dart';

/// The console's policy desk.
///
/// Every mutation answers with the whole working set rather than with the row
/// it changed. That is deliberate: publishing a version archives another one,
/// and a response that described only the row that was posted would leave the
/// screen holding two current versions until somebody pulled to refresh.
final class PolicyAdminRemoteDataSource extends BaseRemoteDataSource {
  const PolicyAdminRemoteDataSource(super.dio);

  Future<List<AdminPolicyDocument>> documents() async {
    final rows = await getList(ApiEndpoints.adminPolicies);
    return _parse(rows);
  }

  Future<List<AdminPolicyConsentStat>> consentSummary() async {
    final rows = await getList(ApiEndpoints.adminPolicyConsentSummary);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => AdminPolicyConsentStat(
            documentId: json['document_id'] as String? ?? '',
            slug: json['slug'] as String? ?? '',
            version: json['version'] as int? ?? 0,
            requiresReacceptance: json['requires_reacceptance'] == true,
            acceptedCurrent: json['accepted_current'] as int? ?? 0,
            acceptedAnyVersion: json['accepted_any_version'] as int? ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<List<AdminPolicyDocument>> updateDocument(
    String id, {
    String? audience,
    bool? requiredForConsent,
    bool? isActive,
    int? sortOrder,
  }) async {
    final response = await patchList(
      ApiEndpoints.adminPolicyDocument(id),
      body: {
        'audience': ?audience,
        'required_for_consent': ?requiredForConsent,
        'is_active': ?isActive,
        'sort_order': ?sortOrder,
      },
    );
    return _parse(response);
  }

  /// Opens a draft. With no translations the server clones what is published,
  /// which is what an editor amending one clause actually wants.
  Future<List<AdminPolicyDocument>> createDraft(
    String documentId, {
    String? changeNote,
  }) async {
    final response = await postList(
      ApiEndpoints.adminPolicyVersions(documentId),
      body: {'change_note': ?changeNote},
    );
    return _parse(response);
  }

  Future<List<AdminPolicyDocument>> saveDraft(
    String versionId, {
    required List<AdminPolicyTranslation> translations,
    String? changeNote,
  }) async {
    final response = await patchList(
      ApiEndpoints.adminPolicyVersion(versionId),
      body: {
        'translations': translations
            .map(
              (row) => {
                'locale': row.locale,
                'title': row.title,
                if (row.summary.isNotEmpty) 'summary': row.summary,
                'body': row.body,
              },
            )
            .toList(growable: false),
        'change_note': ?changeNote,
      },
    );
    return _parse(response);
  }

  Future<List<AdminPolicyDocument>> publish(
    String versionId, {
    required bool requiresReacceptance,
    String? changeNote,
  }) async {
    final response = await postList(
      ApiEndpoints.adminPolicyVersionPublish(versionId),
      body: {
        'requires_reacceptance': requiresReacceptance,
        'change_note': ?changeNote,
      },
    );
    return _parse(response);
  }

  Future<List<AdminPolicyDocument>> discard(String versionId) async {
    final response = await deleteList(
      ApiEndpoints.adminPolicyVersion(versionId),
    );
    return _parse(response);
  }

  List<AdminPolicyDocument> _parse(List<dynamic> rows) => rows
      .whereType<Map<String, dynamic>>()
      .map(AdminPolicyDocument.fromJson)
      .toList(growable: false);
}
