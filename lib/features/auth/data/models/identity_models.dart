import 'package:ohara/core/shared/models/user_model.dart';
import 'package:ohara/features/auth/data/models/account_models.dart';
import 'package:ohara/features/auth/data/models/token_model.dart';
import 'package:ohara/features/auth/domain/entities/auth_account.dart';

/// The two shapes `POST /auth/otp/login/verify` can return.
///
/// Parsed off the `status` discriminator rather than by sniffing which keys are
/// present: guessing from key presence is how a partially-parsed error body
/// ends up being read as a successful sign-in.
class OtpLoginResponse {
  const OtpLoginResponse({
    required this.result,
    this.tokens,
  });

  final OtpLoginResult result;

  /// Present only on the authenticated branch.
  final TokenModel? tokens;

  factory OtpLoginResponse.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String?;

    if (status == 'registration_required') {
      return OtpLoginResponse(
        result: OtpLoginRegistrationRequired(
          phone: json['phone'] as String? ?? '',
          registrationTicket: json['registration_ticket'] as String? ?? '',
          expiresIn: json['expires_in'] as int? ?? 0,
        ),
      );
    }

    final user = json['user'];
    if (user is! Map) {
      throw StateError('Sign-in response carried neither a user nor a ticket');
    }
    return OtpLoginResponse(
      result: OtpLoginAuthenticated(
        UserModel.fromAuthPayload(json),
        passwordEnabled: json['password_enabled'] as bool? ?? false,
      ),
      tokens: TokenModel.fromJson(json['tokens'] as Map<String, dynamic>),
    );
  }
}

class PhoneChangeRequestModel extends PhoneChangeRequest {
  const PhoneChangeRequestModel({
    required super.id,
    required super.status,
    required super.maskedCurrent,
    required super.maskedNew,
    required super.expiresAt,
    super.challenge,
    super.sentTo,
  });

  factory PhoneChangeRequestModel.fromJson(Map<String, dynamic> json) {
    final challenge = json['challenge'];
    return PhoneChangeRequestModel(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'awaiting_current',
      maskedCurrent: json['masked_current'] as String? ?? '',
      maskedNew: json['masked_new'] as String? ?? '',
      expiresAt: DateTime.parse(json['expires_at'] as String),
      challenge: challenge is Map
          ? OtpChallengeModel.fromJson(Map<String, dynamic>.from(challenge))
          : null,
      sentTo: challenge is Map ? challenge['sent_to'] as String? : null,
    );
  }
}

class RecoveryCaseReceiptModel extends RecoveryCaseReceipt {
  const RecoveryCaseReceiptModel({
    required super.caseId,
    required super.claimSecret,
    required super.status,
    required super.message,
  });

  factory RecoveryCaseReceiptModel.fromJson(Map<String, dynamic> json) {
    return RecoveryCaseReceiptModel(
      caseId: json['case_id'] as String? ?? '',
      claimSecret: json['claim_secret'] as String? ?? '',
      status: json['status'] as String? ?? 'submitted',
      message: json['message'] as String? ?? '',
    );
  }
}

class OpenRecoveryCaseModel extends OpenRecoveryCase {
  const OpenRecoveryCaseModel({
    required super.caseId,
    required super.status,
    required super.openedAt,
    super.completesAt,
    super.contactPhone,
  });

  factory OpenRecoveryCaseModel.fromJson(Map<String, dynamic> json) {
    final completes = json['completes_at'];
    return OpenRecoveryCaseModel(
      caseId: json['case_id'] as String? ?? '',
      status: json['status'] as String? ?? 'submitted',
      openedAt: DateTime.parse(json['opened_at'] as String),
      completesAt: completes is String ? DateTime.parse(completes) : null,
      contactPhone: json['contact_phone'] as String?,
    );
  }
}

/// Answers to the recovery questionnaire.
///
/// Every field here is about something the platform already holds. There is
/// deliberately no place to attach a selfie or an identity document: on a
/// women-only platform that queue would be a bigger liability than the fraud it
/// is meant to stop, and the documents answer the wrong question anyway —
/// they show who is holding a phone today, not who opened the account.
class RecoveryClaimModel {
  const RecoveryClaimModel({
    required this.claimedPhone,
    required this.contactPhone,
    required this.contactCode,
    this.registrationMonth,
    this.displayName,
    this.city,
    this.lastOrderMonth,
    this.lastOrderTotal,
    this.deviceLabel,
  });

  final String claimedPhone;
  final String contactPhone;
  final String contactCode;
  final String? registrationMonth;
  final String? displayName;
  final String? city;
  final String? lastOrderMonth;
  final double? lastOrderTotal;
  final String? deviceLabel;

  Map<String, dynamic> toJson() => {
    'claimed_phone': claimedPhone,
    'contact_phone': contactPhone,
    'contact_code': contactCode,
    if (registrationMonth != null) 'registration_month': registrationMonth,
    if (displayName != null) 'display_name': displayName,
    if (city != null) 'city': city,
    if (lastOrderMonth != null) 'last_order_month': lastOrderMonth,
    if (lastOrderTotal != null) 'last_order_total': lastOrderTotal,
    if (deviceLabel != null) 'device_label': deviceLabel,
  };
}
