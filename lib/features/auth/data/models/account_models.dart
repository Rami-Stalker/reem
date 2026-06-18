import 'package:reem/core/shared/models/user_model.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';

class OtpChallengeModel extends OtpChallenge {
  const OtpChallengeModel({
    required super.id,
    required super.expiresAt,
    super.debugCode,
  });

  factory OtpChallengeModel.fromJson(Map<String, dynamic> json) {
    return OtpChallengeModel(
      id: json['otp_request_id'] as String? ?? '',
      expiresAt: DateTime.parse(json['expires_at'] as String),
      debugCode: json['debug_code'] as String?,
    );
  }
}

class SecuritySettingsModel extends SecuritySettings {
  const SecuritySettingsModel({
    required super.mfaEnabled,
    required super.deviceVerificationRequired,
  });

  factory SecuritySettingsModel.fromJson(Map<String, dynamic> json) {
    return SecuritySettingsModel(
      mfaEnabled: json['mfa_enabled'] as bool? ?? false,
      deviceVerificationRequired:
          json['device_verification_required'] as bool? ?? true,
    );
  }
}

class LinkedAccountModel extends LinkedAccount {
  const LinkedAccountModel({
    required super.id,
    required super.provider,
    super.email,
    super.displayName,
    required super.linkedAt,
  });

  factory LinkedAccountModel.fromJson(Map<String, dynamic> json) {
    return LinkedAccountModel(
      id: json['id'] as String,
      provider: _providerFromWire(json['provider'] as String?),
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      linkedAt: DateTime.parse(json['linked_at'] as String),
    );
  }
}

class AccountDeviceModel extends AccountDevice {
  const AccountDeviceModel({
    required super.id,
    required super.name,
    super.platform,
    required super.trustLevel,
    super.ipAddress,
    required super.lastSeenAt,
  });

  factory AccountDeviceModel.fromJson(Map<String, dynamic> json) {
    return AccountDeviceModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown device',
      platform: json['platform'] as String?,
      trustLevel: json['trust_level'] as String? ?? 'unverified',
      ipAddress: json['ip_address'] as String?,
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
    );
  }
}

class AccountSessionModel extends AccountSession {
  const AccountSessionModel({
    required super.id,
    required super.status,
    super.deviceName,
    super.platform,
    super.ipAddress,
    required super.lastSeenAt,
    required super.expiresAt,
  });

  factory AccountSessionModel.fromJson(Map<String, dynamic> json) {
    return AccountSessionModel(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'active',
      deviceName: json['device_name'] as String?,
      platform: json['platform'] as String?,
      ipAddress: json['ip_address'] as String?,
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

class SellerVerificationModel extends SellerVerification {
  const SellerVerificationModel({
    required super.id,
    required super.status,
    required super.businessName,
    required super.legalName,
    super.taxId,
    required super.documentUrls,
    super.rejectionReason,
    required super.submittedAt,
  });

  factory SellerVerificationModel.fromJson(Map<String, dynamic> json) {
    final docs = json['document_urls'];
    return SellerVerificationModel(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'pending',
      businessName: json['business_name'] as String? ?? '',
      legalName: json['legal_name'] as String? ?? '',
      taxId: json['tax_id'] as String?,
      documentUrls: docs is List ? docs.map((e) => e.toString()).toList() : [],
      rejectionReason: json['rejection_reason'] as String?,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
    );
  }
}

class AuthAccountModel extends AuthAccount {
  const AuthAccountModel({
    required super.user,
    required super.permissions,
    required super.linkedAccounts,
    required super.security,
    super.sellerVerification,
  });

  factory AuthAccountModel.fromJson(Map<String, dynamic> json) {
    final linked = json['linked_accounts'];
    final permissions = json['permissions'];
    final verification = json['seller_verification'];
    return AuthAccountModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      permissions:
          permissions is List ? permissions.map((e) => e.toString()).toList() : [],
      linkedAccounts: linked is List
          ? linked
              .whereType<Map>()
              .map((e) => LinkedAccountModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : [],
      security: SecuritySettingsModel.fromJson(
        json['security'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      sellerVerification: verification is Map
          ? SellerVerificationModel.fromJson(
              Map<String, dynamic>.from(verification),
            )
          : null,
    );
  }
}

SocialAuthProvider _providerFromWire(String? value) => switch (value) {
      'apple' => SocialAuthProvider.apple,
      _ => SocialAuthProvider.google,
    };
