import 'package:reem/core/shared/models/user_model.dart';
import 'package:reem/features/auth/data/models/identity_models.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';

class OtpChallengeModel extends OtpChallenge {
  const OtpChallengeModel({
    required super.id,
    required super.expiresAt,
    super.channel,
    super.matchCode,
    super.maskedDestination,
    super.resendAfter,
    super.deliveryMode,
    super.ceremony,
    super.sendTo,
    super.smsBody,
  });

  factory OtpChallengeModel.fromJson(Map<String, dynamic> json) {
    final resend = json['resend_after'];
    return OtpChallengeModel(
      id: json['otp_request_id'] as String? ?? '',
      expiresAt: DateTime.parse(json['expires_at'] as String),
      channel: json['channel'] as String?,
      // The server has always sent these; the client simply never read them,
      // so the two digits she is supposed to compare against the message never
      // reached a screen and the anti-relay defence did nothing.
      matchCode: json['match_code'] as String?,
      maskedDestination: json['masked_destination'] as String?,
      resendAfter: resend is String ? DateTime.parse(resend) : null,
      // Absent from an older server's reply, which reads as the code rail —
      // the right default, because that is what such a server is running.
      deliveryMode: json['delivery_mode'] as String?,
      ceremony: json['ceremony'] as String?,
      sendTo: json['send_to'] as String?,
      smsBody: json['sms_body'] as String?,
    );
  }
}

class SecuritySettingsModel extends SecuritySettings {
  const SecuritySettingsModel({
    required super.mfaEnabled,
    required super.deviceVerificationRequired,
    super.passwordEnabled,
    super.totpEnabled,
    super.totpRequired,
    super.recoveryCodesRemaining,
    super.payoutFrozenUntil,
    super.newDeviceCooldownUntil,
  });

  factory SecuritySettingsModel.fromJson(Map<String, dynamic> json) {
    final frozen = json['payout_frozen_until'];
    final cooldown = json['new_device_cooldown_until'];
    return SecuritySettingsModel(
      mfaEnabled: json['mfa_enabled'] as bool? ?? false,
      deviceVerificationRequired:
          json['device_verification_required'] as bool? ?? true,
      passwordEnabled: json['password_enabled'] as bool? ?? false,
      totpEnabled: json['totp_enabled'] as bool? ?? false,
      totpRequired: json['totp_required'] as bool? ?? false,
      recoveryCodesRemaining: json['recovery_codes_remaining'] as int? ?? 0,
      payoutFrozenUntil: frozen is String ? DateTime.parse(frozen) : null,
      newDeviceCooldownUntil:
          cooldown is String ? DateTime.parse(cooldown) : null,
    );
  }
}

class AccountDeviceModel extends AccountDevice {
  const AccountDeviceModel({
    required super.id,
    required super.name,
    super.platform,
    required super.trustLevel,
    super.model,
    super.osVersion,
    super.appVersion,
    super.hardwareBacked,
    super.activeSessions,
    super.verifiedAt,
    super.firstSeenAt,
    required super.lastSeenAt,
  });

  factory AccountDeviceModel.fromJson(Map<String, dynamic> json) {
    // `label`, not `name`. The device list moved from `devices` (a row keyed
    // on a forgeable header hash) to `device_keys` (a public key), and the
    // field came with it — this reader was still asking for `name`, so every
    // handset showed as "Unknown device", and for `ip_address`, which the key
    // list deliberately does not carry at all.
    final verified = json['verified_at'];
    final firstSeen = json['first_seen_at'];
    return AccountDeviceModel(
      id: json['id'] as String,
      name:
          json['label'] as String? ??
          json['model'] as String? ??
          json['platform'] as String? ??
          'جهاز غير معروف',
      platform: json['platform'] as String?,
      trustLevel: json['trust_level'] as String? ?? 'unverified',
      model: json['model'] as String?,
      osVersion: json['os_version'] as String?,
      appVersion: json['app_version'] as String?,
      hardwareBacked: json['hardware_backed'] as bool? ?? false,
      activeSessions: json['active_sessions'] as int? ?? 0,
      verifiedAt: verified is String ? DateTime.parse(verified) : null,
      firstSeenAt: firstSeen is String ? DateTime.parse(firstSeen) : null,
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
    required super.idleExpiresAt,
    required super.absoluteExpiresAt,
    required super.createdAt,
    super.deviceKeyId,
  });

  factory AccountSessionModel.fromJson(Map<String, dynamic> json) {
    // A session carries two clocks, and the server has sent both since they
    // were introduced. This reader was still parsing a single `expires_at`
    // that no longer exists — `DateTime.parse(null)` throws, so the sessions
    // screen failed to load outright rather than showing a wrong date.
    return AccountSessionModel(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'active',
      deviceName: json['device_name'] as String?,
      platform: json['platform'] as String?,
      ipAddress: json['ip_address'] as String?,
      deviceKeyId: json['device_key_id'] as String?,
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
      idleExpiresAt: DateTime.parse(json['idle_expires_at'] as String),
      absoluteExpiresAt: DateTime.parse(json['absolute_expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class SellerVerificationModel extends SellerVerification {
  const SellerVerificationModel({
    required super.id,
    required super.status,
    required super.businessName,
    required super.legalName,
    super.businessCategory,
    super.storeDescription,
    super.storeLogoUrl,
    super.contactPhone,
    super.contactEmail,
    super.businessAddress,
    super.warehouseAddress,
    super.commercialRegistration,
    super.governmentIdUrl,
    super.businessLicenseUrl,
    super.taxId,
    super.bankName,
    super.accountHolder,
    super.iban,
    super.shippingMethods,
    super.returnPolicy,
    super.productCategories,
    super.yearsExperience,
    super.website,
    required super.documentUrls,
    super.reviewReason,
    super.rejectionReason,
    required super.submittedAt,
  });

  factory SellerVerificationModel.fromJson(Map<String, dynamic> json) {
    final docs = json['document_urls'];
    final shipping = json['shipping_methods'];
    final categories = json['product_categories'];
    return SellerVerificationModel(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'pending',
      businessName: json['business_name'] as String? ?? '',
      legalName: json['legal_name'] as String? ?? '',
      businessCategory: json['business_category'] as String?,
      storeDescription: json['store_description'] as String?,
      storeLogoUrl: json['store_logo_url'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      businessAddress: json['business_address'] as String?,
      warehouseAddress: json['warehouse_address'] as String?,
      commercialRegistration: json['commercial_registration'] as String?,
      governmentIdUrl: json['government_id_url'] as String?,
      businessLicenseUrl: json['business_license_url'] as String?,
      taxId: json['tax_id'] as String?,
      bankName: json['bank_name'] as String?,
      accountHolder: json['account_holder'] as String?,
      iban: json['iban'] as String?,
      shippingMethods: shipping is List
          ? shipping.map((e) => e.toString()).toList()
          : const [],
      returnPolicy: json['return_policy'] as String?,
      productCategories: categories is List
          ? categories.map((e) => e.toString()).toList()
          : const [],
      yearsExperience: json['years_experience'] as int?,
      website: json['website'] as String?,
      documentUrls: docs is List ? docs.map((e) => e.toString()).toList() : [],
      reviewReason: json['review_reason'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
    );
  }
}

class AuthAccountModel extends AuthAccount {
  const AuthAccountModel({
    required super.user,
    required super.permissions,
    required super.security,
    super.sellerVerification,
    super.openRecoveryCases,
  });

  factory AuthAccountModel.fromJson(Map<String, dynamic> json) {
    final permissions = json['permissions'];
    final verification = json['seller_verification'];
    final cases = json['open_recovery_cases'];
    return AuthAccountModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      permissions:
          permissions is List ? permissions.map((e) => e.toString()).toList() : [],
      security: SecuritySettingsModel.fromJson(
        json['security'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      sellerVerification: verification is Map
          ? SellerVerificationModel.fromJson(
              Map<String, dynamic>.from(verification),
            )
          : null,
      openRecoveryCases: cases is List
          ? cases
                .whereType<Map>()
                .map(
                  (item) => OpenRecoveryCaseModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

/// Parses `POST /auth/totp/enroll` into the domain's [TotpEnrolment].
abstract final class TotpEnrolmentMapper {
  static TotpEnrolment fromJson(Map<String, dynamic> json) => TotpEnrolment(
    secret: json['secret'] as String? ?? '',
    otpauthUri: json['otpauth_uri'] as String? ?? '',
    digits: (json['digits'] as num?)?.toInt() ?? 6,
    periodSeconds: (json['period_seconds'] as num?)?.toInt() ?? 30,
  );
}
