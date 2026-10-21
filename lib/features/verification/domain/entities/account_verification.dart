import 'package:equatable/equatable.dart';

/// Where a claim on the badge stands.
enum AccountVerificationStatus {
  /// Filed, waiting for a reviewer.
  pending,

  /// A reviewer has it open.
  underReview,

  /// Sent back with a note. Hers to answer — not a refusal.
  needsMoreInfo,
  approved,
  rejected,

  /// Granted once, withdrawn since.
  revoked;

  static AccountVerificationStatus fromWire(String? value) =>
      switch ((value ?? '').toLowerCase()) {
        'under_review' => AccountVerificationStatus.underReview,
        'needs_more_info' => AccountVerificationStatus.needsMoreInfo,
        'approved' => AccountVerificationStatus.approved,
        'rejected' => AccountVerificationStatus.rejected,
        'revoked' => AccountVerificationStatus.revoked,
        _ => AccountVerificationStatus.pending,
      };

  /// True while staff still owe her an answer.
  bool get isOpen =>
      this == AccountVerificationStatus.pending ||
      this == AccountVerificationStatus.underReview;
}

/// One move a claim made, and why.
class AccountVerificationEvent extends Equatable {
  const AccountVerificationEvent({
    required this.status,
    required this.reason,
    required this.at,
  });

  final AccountVerificationStatus status;
  final String reason;
  final DateTime at;

  @override
  List<Object?> get props => [status, reason, at];
}

/// «توثيق الحساب» — her claim on the badge beside her name.
///
/// The badge used to be a side-effect of receiving a sign-in code, so it sat
/// next to every account in the app and meant nothing. It is now this: papers
/// she sent, a person who read them, and an answer she can act on.
class AccountVerification extends Equatable {
  const AccountVerification({
    required this.id,
    required this.status,
    required this.legalName,
    required this.submittedAt,
    required this.canResubmit,
    this.documentType,
    this.documentFrontUrl,
    this.documentBackUrl,
    this.selfieUrl,
    this.note,
    this.reviewNote,
    this.reviewedAt,
    this.history = const [],
  });

  final String id;
  final AccountVerificationStatus status;
  final String legalName;
  final String? documentType;
  final String? documentFrontUrl;
  final String? documentBackUrl;
  final String? selfieUrl;
  final String? note;

  /// What the reviewer said. The whole reason «نحتاج توضيح» is a state she can
  /// act on rather than a dead end.
  final String? reviewNote;

  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final bool canResubmit;
  final List<AccountVerificationEvent> history;

  bool get isApproved => status == AccountVerificationStatus.approved;

  @override
  List<Object?> get props => [
    id,
    status,
    legalName,
    documentType,
    documentFrontUrl,
    documentBackUrl,
    selfieUrl,
    note,
    reviewNote,
    submittedAt,
    reviewedAt,
    canResubmit,
    history,
  ];
}
