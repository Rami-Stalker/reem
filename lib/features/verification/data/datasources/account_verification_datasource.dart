import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/verification/domain/entities/account_verification.dart';

/// `/account-verification` — hers.
final class AccountVerificationDataSource extends BaseRemoteDataSource {
  const AccountVerificationDataSource(super.dio);

  /// Her claim, or null when she has never filed one.
  Future<AccountVerification?> mine() async {
    final json = await getJson(ApiEndpoints.accountVerification);
    // The API answers `null` for an account that has never applied, which the
    // transport renders as an empty map.
    if (json.isEmpty || json['id'] is! String) return null;
    return _parse(json);
  }

  Future<AccountVerification> submit({
    required String legalName,
    String? documentType,
    String? documentFrontUrl,
    String? documentBackUrl,
    String? selfieUrl,
    String? note,
  }) async {
    final json = await postJson(
      ApiEndpoints.accountVerification,
      body: {
        'legal_name': legalName,
        'document_type': ?documentType,
        'document_front_url': ?documentFrontUrl,
        'document_back_url': ?documentBackUrl,
        'selfie_url': ?selfieUrl,
        'note': ?note,
      },
    );
    return _parse(json);
  }

  Future<void> withdraw() async {
    await deleteJson(ApiEndpoints.accountVerification);
  }

  AccountVerification _parse(Map<String, dynamic> json) {
    return AccountVerification(
      id: json['id'] as String,
      status: AccountVerificationStatus.fromWire(json['status'] as String?),
      legalName: json['legal_name'] as String? ?? '',
      documentType: json['document_type'] as String?,
      documentFrontUrl: json['document_front_url'] as String?,
      documentBackUrl: json['document_back_url'] as String?,
      selfieUrl: json['selfie_url'] as String?,
      note: json['note'] as String?,
      reviewNote: json['review_note'] as String?,
      submittedAt:
          DateTime.tryParse(json['submitted_at'] as String? ?? '') ??
          DateTime.now(),
      reviewedAt: DateTime.tryParse(json['reviewed_at'] as String? ?? ''),
      canResubmit: json['can_resubmit'] as bool? ?? false,
      history: (json['history'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) {
            final event = Map<String, dynamic>.from(raw);
            return AccountVerificationEvent(
              status: AccountVerificationStatus.fromWire(
                event['status'] as String?,
              ),
              reason: event['reason'] as String? ?? '',
              at:
                  DateTime.tryParse(event['created_at'] as String? ?? '') ??
                  DateTime.now(),
            );
          })
          .toList(growable: false),
    );
  }
}
