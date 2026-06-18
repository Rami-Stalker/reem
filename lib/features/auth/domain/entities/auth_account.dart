import 'package:reem/core/shared/entities/user.dart';

enum SocialAuthProvider { google, apple }

extension SocialAuthProviderX on SocialAuthProvider {
  String get wire => name;

  String get label => switch (this) {
        SocialAuthProvider.google => 'Google',
        SocialAuthProvider.apple => 'Apple',
      };
}

enum OtpPurpose { phoneVerification, passwordReset, deviceVerification }

extension OtpPurposeX on OtpPurpose {
  String get wire => switch (this) {
        OtpPurpose.phoneVerification => 'phone_verification',
        OtpPurpose.passwordReset => 'password_reset',
        OtpPurpose.deviceVerification => 'device_verification',
      };
}

class OtpChallenge {
  const OtpChallenge({
    required this.id,
    required this.expiresAt,
    this.debugCode,
  });

  final String id;
  final DateTime expiresAt;
  final String? debugCode;
}

class LinkedAccount {
  const LinkedAccount({
    required this.id,
    required this.provider,
    this.email,
    this.displayName,
    required this.linkedAt,
  });

  final String id;
  final SocialAuthProvider provider;
  final String? email;
  final String? displayName;
  final DateTime linkedAt;
}

class SecuritySettings {
  const SecuritySettings({
    required this.mfaEnabled,
    required this.deviceVerificationRequired,
  });

  final bool mfaEnabled;
  final bool deviceVerificationRequired;
}

class AccountDevice {
  const AccountDevice({
    required this.id,
    required this.name,
    this.platform,
    required this.trustLevel,
    this.ipAddress,
    required this.lastSeenAt,
  });

  final String id;
  final String name;
  final String? platform;
  final String trustLevel;
  final String? ipAddress;
  final DateTime lastSeenAt;
}

class AccountSession {
  const AccountSession({
    required this.id,
    required this.status,
    this.deviceName,
    this.platform,
    this.ipAddress,
    required this.lastSeenAt,
    required this.expiresAt,
  });

  final String id;
  final String status;
  final String? deviceName;
  final String? platform;
  final String? ipAddress;
  final DateTime lastSeenAt;
  final DateTime expiresAt;
}

class SellerVerification {
  const SellerVerification({
    required this.id,
    required this.status,
    required this.businessName,
    required this.legalName,
    this.taxId,
    required this.documentUrls,
    this.rejectionReason,
    required this.submittedAt,
  });

  final String id;
  final String status;
  final String businessName;
  final String legalName;
  final String? taxId;
  final List<String> documentUrls;
  final String? rejectionReason;
  final DateTime submittedAt;
}

class AuthAccount {
  const AuthAccount({
    required this.user,
    required this.permissions,
    required this.linkedAccounts,
    required this.security,
    this.sellerVerification,
  });

  final User user;
  final List<String> permissions;
  final List<LinkedAccount> linkedAccounts;
  final SecuritySettings security;
  final SellerVerification? sellerVerification;
}
