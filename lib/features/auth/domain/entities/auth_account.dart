import 'package:ohara/core/shared/entities/user.dart';

enum OtpPurpose {
  phoneVerification,
  passwordReset,
  deviceVerification,
  /// The main door. A code on her SIM is the credential Ohara signs in with;
  /// a password, if she has one, only shortens this on a device we know.
  login,
  /// The challenge on the number she is *leaving*, which is the half a SIM
  /// swapper cannot answer.
  phoneChange,
  /// Reaching a woman who has lost the SIM, on whatever number she has now.
  accountRecovery,
}

extension OtpPurposeX on OtpPurpose {
  String get wire => switch (this) {
    OtpPurpose.phoneVerification => 'phone_verification',
    OtpPurpose.passwordReset => 'password_reset',
    OtpPurpose.deviceVerification => 'device_verification',
    OtpPurpose.login => 'login',
    OtpPurpose.phoneChange => 'phone_change',
    OtpPurpose.accountRecovery => 'account_recovery',
  };
}

class OtpChallenge {
  const OtpChallenge({
    required this.id,
    required this.expiresAt,
    this.channel,
    this.matchCode,
    this.maskedDestination,
    this.resendAfter,
    this.deliveryMode,
    this.ceremony,
    this.sendTo,
    this.smsBody,
  });

  final String id;
  final DateTime expiresAt;

  /// Where the code was sent — the app tells her to check WhatsApp or SMS.
  /// It deliberately does NOT carry the code: the server used to return it in
  /// the response body, which made every account resettable by anyone.
  final String? channel;

  /// Two digits shown on screen and repeated inside the message.
  ///
  /// She is meant to compare them. It is the only defence the product has
  /// against "this is Ohara support, read me the code you just received" — the
  /// dominant attack wherever OTPs arrive over WhatsApp — because a code
  /// somebody else requested carries somebody else's two digits.
  final String? matchCode;

  /// `+9639****5678`, so she can see the code went where she expected.
  final String? maskedDestination;

  /// When the resend button should come back.
  final DateTime? resendAfter;

  /// `code_to_handset` or `reverse_sms` — which direction the code travels.
  ///
  /// On the reverse rail nothing is sent to her: she messages a number the
  /// platform owns and the inbound sender check is the proof. The two screens
  /// are different enough that the app has to know before it draws anything,
  /// which is why the server states this rather than leaving the client to
  /// infer it from a missing field.
  final String? deliveryMode;

  /// `binding` the first time this number is seen by the provider,
  /// `verification` every time after. She is told the same thing either way;
  /// it is here because support cannot otherwise tell the two apart.
  final String? ceremony;

  /// The receiver number her message must be addressed to.
  final String? sendTo;

  /// The exact body she must send, e.g. `VERIFY 763PM5`.
  final String? smsBody;

  /// Whether she proves the number by sending rather than by typing.
  ///
  /// Both parts are demanded, not just the mode: a reverse challenge with no
  /// address or no body is an instruction she cannot follow, and falling back
  /// to the code field — which the server will refuse — is better than drawing
  /// a screen that asks her to send nothing to nobody.
  bool get isReverse =>
      deliveryMode == 'reverse_sms' &&
      (sendTo?.isNotEmpty ?? false) &&
      (smsBody?.isNotEmpty ?? false);
}

/// What came back from `POST /auth/otp/login/verify`.
///
/// Two outcomes, and this is the first moment the platform reveals which one
/// applies: until the code is verified, a number with an account and a number
/// without are answered identically, so the route cannot be used to ask
/// whether a particular woman is on Ohara.
sealed class OtpLoginResult {
  const OtpLoginResult();
}

/// She has an account and is now signed in.
class OtpLoginAuthenticated extends OtpLoginResult {
  const OtpLoginAuthenticated(this.user, {this.passwordEnabled = false});

  final User user;

  /// Whether she has opted into a password. Drives the security-centre copy.
  final bool passwordEnabled;
}

/// The number is free. She carries this ticket to the signup form, which is
/// the only way an account gets created for it.
class OtpLoginRegistrationRequired extends OtpLoginResult {
  const OtpLoginRegistrationRequired({
    required this.phone,
    required this.registrationTicket,
    required this.expiresIn,
  });

  final String phone;
  final String registrationTicket;

  /// Seconds. Short — long enough to type a name and a city.
  final int expiresIn;
}

/// A phone change in flight. Two challenges, in order.
class PhoneChangeRequest {
  const PhoneChangeRequest({
    required this.id,
    required this.status,
    required this.maskedCurrent,
    required this.maskedNew,
    required this.expiresAt,
    this.challenge,
    this.sentTo,
  });

  final String id;

  /// `awaiting_current`, `awaiting_new`, `completed`, `cancelled`, `expired`.
  final String status;
  final String maskedCurrent;
  final String maskedNew;
  final DateTime expiresAt;
  final OtpChallenge? challenge;

  /// `current` or `new` — which number the outstanding code went to.
  final String? sentTo;

  bool get awaitingCurrent => status == 'awaiting_current';
  bool get awaitingNew => status == 'awaiting_new';
  bool get isLive => awaitingCurrent || awaitingNew;
}

/// The receipt for a support-mediated recovery case.
///
/// `claimSecret` is the only way back to a case she cannot sign in to check on,
/// so the app has to keep it and show it to her.
class RecoveryCaseReceipt {
  const RecoveryCaseReceipt({
    required this.caseId,
    required this.claimSecret,
    required this.status,
    required this.message,
  });

  final String caseId;
  final String claimSecret;
  final String status;
  final String message;
}

/// A recovery case open against the signed-in account — the warning she needs
/// to see while the 72-hour cool-off is still running.
class OpenRecoveryCase {
  const OpenRecoveryCase({
    required this.caseId,
    required this.status,
    required this.openedAt,
    this.completesAt,
    this.contactPhone,
  });

  final String caseId;
  final String status;
  final DateTime openedAt;

  /// When the account would be handed over if she does nothing.
  final DateTime? completesAt;
  final String? contactPhone;

  bool get isCoolingOff => status == 'cooling_off';
}

class SecuritySettings {
  const SecuritySettings({
    required this.mfaEnabled,
    required this.deviceVerificationRequired,
    this.passwordEnabled = false,
    this.totpEnabled = false,
    this.totpRequired = false,
    this.recoveryCodesRemaining = 0,
    this.payoutFrozenUntil,
    this.newDeviceCooldownUntil,
  });

  final bool mfaEnabled;
  final bool deviceVerificationRequired;

  /// She opted into a password. Off is the normal, recommended state.
  final bool passwordEnabled;

  /// An authenticator app is enrolled and confirmed — the only factor with no
  /// network in its path, and the only one that survives a lost SIM.
  final bool totpEnabled;

  /// True for the privileged roles, where it is not optional.
  final bool totpRequired;
  final int recoveryCodesRemaining;

  /// Set after a phone change or a completed recovery. Money is still.
  final DateTime? payoutFrozenUntil;

  /// While this is in the future, the sensitive actions are refused outright
  /// on this device — no second factor clears it, because on a consumer
  /// account every factor arrives on the SIM an attacker would be holding.
  final DateTime? newDeviceCooldownUntil;

  bool get payoutsFrozen =>
      payoutFrozenUntil != null && payoutFrozenUntil!.isAfter(DateTime.now());

  bool get inNewDeviceCooldown =>
      newDeviceCooldownUntil != null &&
      newDeviceCooldownUntil!.isAfter(DateTime.now());

  /// Can she get back in if this handset disappears tonight?
  bool get hasOfflineRecovery => totpEnabled || recoveryCodesRemaining > 0;
}

class AccountDevice {
  const AccountDevice({
    required this.id,
    required this.name,
    this.platform,
    required this.trustLevel,
    this.model,
    this.osVersion,
    this.appVersion,
    this.hardwareBacked = false,
    this.activeSessions = 0,
    this.verifiedAt,
    this.firstSeenAt,
    required this.lastSeenAt,
  });

  final String id;
  final String name;
  final String? platform;

  /// `unverified`, `verified`, `trusted`, `blocked`.
  final String trustLevel;
  final String? model;
  final String? osVersion;
  final String? appVersion;

  /// Whether the private key lives in Keystore/Secure Enclave rather than in
  /// application storage. Surfaced because it is the honest answer to "how
  /// well is this device pinned", and today it is mostly false.
  final bool hardwareBacked;
  final int activeSessions;

  /// Set when a code was completed on this device — the only way trust is
  /// conferred. Null means the platform has seen the key but she has never
  /// signed in from it.
  final DateTime? verifiedAt;
  final DateTime? firstSeenAt;
  final DateTime lastSeenAt;

  bool get isTrusted => verifiedAt != null;
}

class AccountSession {
  const AccountSession({
    required this.id,
    required this.status,
    this.deviceName,
    this.platform,
    this.ipAddress,
    required this.lastSeenAt,
    required this.idleExpiresAt,
    required this.absoluteExpiresAt,
    required this.createdAt,
    this.deviceKeyId,
  });

  final String id;
  final String status;
  final String? deviceName;
  final String? platform;
  final String? ipAddress;
  final DateTime lastSeenAt;

  /// Slides forward every time the session refreshes.
  final DateTime idleExpiresAt;

  /// Never moves. The checkpoint that eventually forces her to sign in again,
  /// and the reason a stolen unlocked handset does not stay signed in forever.
  final DateTime absoluteExpiresAt;
  final DateTime createdAt;
  final String? deviceKeyId;

  bool get isActive => status == 'active';
}

class SellerVerification {
  const SellerVerification({
    required this.id,
    required this.status,
    required this.businessName,
    required this.legalName,
    this.businessCategory,
    this.storeDescription,
    this.storeLogoUrl,
    this.contactPhone,
    this.contactEmail,
    this.businessAddress,
    this.warehouseAddress,
    this.commercialRegistration,
    this.governmentIdUrl,
    this.businessLicenseUrl,
    this.taxId,
    this.bankName,
    this.accountHolder,
    this.iban,
    this.shippingMethods = const [],
    this.returnPolicy,
    this.productCategories = const [],
    this.yearsExperience,
    this.website,
    required this.documentUrls,
    this.reviewReason,
    this.rejectionReason,
    required this.submittedAt,
  });

  final String id;
  final String status;
  final String businessName;
  final String legalName;
  final String? businessCategory;
  final String? storeDescription;
  final String? storeLogoUrl;
  final String? contactPhone;
  final String? contactEmail;
  final String? businessAddress;
  final String? warehouseAddress;
  final String? commercialRegistration;
  final String? governmentIdUrl;
  final String? businessLicenseUrl;
  final String? taxId;
  final String? bankName;
  final String? accountHolder;
  final String? iban;
  final List<String> shippingMethods;
  final String? returnPolicy;
  final List<String> productCategories;
  final int? yearsExperience;
  final String? website;
  final List<String> documentUrls;
  final String? reviewReason;
  final String? rejectionReason;
  final DateTime submittedAt;
}

class AuthAccount {
  const AuthAccount({
    required this.user,
    required this.permissions,
    required this.security,
    this.sellerVerification,
    this.openRecoveryCases = const [],
  });

  final User user;
  final List<String> permissions;
  final SecuritySettings security;
  final SellerVerification? sellerVerification;

  /// Requests to move this account to another number that are still live.
  /// The security screen has to put these in front of her — during the
  /// cool-off, one tap from her is what stops the hand-over.
  final List<OpenRecoveryCase> openRecoveryCases;
}

/// What begins an authenticator enrolment.
///
/// A domain type, not a data model: `AuthRepository` returns it, and a domain
/// contract that reaches into `data/` is the one boundary this project's
/// fitness check refuses outright. The JSON mapping lives in `data/`, where
/// mapping belongs.
class TotpEnrolment {
  const TotpEnrolment({
    required this.secret,
    required this.otpauthUri,
    required this.digits,
    required this.periodSeconds,
  });

  /// Shown once, before confirmation — the server never returns it again.
  final String secret;

  /// `otpauth://…`, for the authenticators that can be handed a link.
  final String otpauthUri;

  final int digits;
  final int periodSeconds;
}

/// What stands between her and deleting the account.
///
/// The server's own codes, so the screen can say each one in her language:
/// `STAFF_ACCOUNT`, `OPEN_ORDERS`, `OPEN_SALES`, `WALLET_BALANCE`,
/// `PENDING_PAYOUTS`, `UPCOMING_APPOINTMENTS`.
class AccountDeletionBlocker {
  const AccountDeletionBlocker({required this.code, required this.count});

  final String code;
  final int count;
}

/// Whether the account can be deleted right now.
class AccountDeletionStatus {
  const AccountDeletionStatus({required this.blockers});

  final List<AccountDeletionBlocker> blockers;

  bool get canDelete => blockers.isEmpty;
}
