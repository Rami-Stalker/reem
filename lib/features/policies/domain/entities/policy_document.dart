import 'package:meta/meta.dart';

/// Who a policy is addressed to.
///
/// Not who may *read* one — everything published is readable by everyone,
/// including a woman who has no account yet. This decides whose signature the
/// platform asks for, and which section of the policy centre a card sits in.
enum PolicyAudience {
  everyone,
  customer,
  seller;

  static PolicyAudience parse(String? value) => switch (value?.toUpperCase()) {
    'CUSTOMER' => PolicyAudience.customer,
    'SELLER' => PolicyAudience.seller,
    _ => PolicyAudience.everyone,
  };
}

/// The eight documents, as the server names them.
///
/// Parsed to an enum rather than kept as a string because two screens link to
/// specific ones — checkout to the returns policy, the composer to the content
/// policy — and a mistyped slug is a dead link nobody notices.
enum PolicyKind {
  customerTerms,
  sellerTerms,
  privacy,
  returns,
  commissions,
  disputes,
  liability,
  content,
  other;

  static PolicyKind parse(String? value) => switch (value?.toUpperCase()) {
    'CUSTOMER_TERMS' => PolicyKind.customerTerms,
    'SELLER_TERMS' => PolicyKind.sellerTerms,
    'PRIVACY' => PolicyKind.privacy,
    'RETURNS' => PolicyKind.returns,
    'COMMISSIONS' => PolicyKind.commissions,
    'DISPUTES' => PolicyKind.disputes,
    'LIABILITY' => PolicyKind.liability,
    'CONTENT' => PolicyKind.content,
    _ => PolicyKind.other,
  };
}

/// What she signed, and when.
@immutable
class PolicyAcceptanceStamp {
  const PolicyAcceptanceStamp({
    required this.versionId,
    required this.version,
    required this.acceptedAt,
    required this.isCurrent,
  });

  final String versionId;
  final int version;
  final DateTime? acceptedAt;

  /// Whether the version she signed is the one published today. False is not a
  /// problem by itself: it only matters when the newer version demanded a
  /// signature, and in that case the policy turns up in the consent gate.
  final bool isCurrent;
}

/// One policy, as the list shows it: everything but the text.
@immutable
class PolicySummary {
  const PolicySummary({
    required this.id,
    required this.kind,
    required this.slug,
    required this.audience,
    required this.title,
    required this.summary,
    required this.versionId,
    required this.version,
    required this.requiredForConsent,
    this.icon,
    this.effectiveAt,
    this.publishedAt,
    this.changeNote,
    this.acceptance,
  });

  final String id;
  final PolicyKind kind;
  final String slug;
  final PolicyAudience audience;
  final String title;
  final String summary;

  /// The issue currently published. This is what an acceptance is recorded
  /// against — never the document id, which is a moving target.
  final String versionId;
  final int version;

  final bool requiredForConsent;
  final String? icon;
  final DateTime? effectiveAt;
  final DateTime? publishedAt;
  final String? changeNote;
  final PolicyAcceptanceStamp? acceptance;

  bool get isSignedCurrent => acceptance?.isCurrent ?? false;
}

/// One issue in a policy's history — including the retired ones, which stay
/// readable so a receipt can be opened against the text it was signed against.
@immutable
class PolicyVersionRef {
  const PolicyVersionRef({
    required this.id,
    required this.version,
    required this.isCurrent,
    this.publishedAt,
    this.effectiveAt,
    this.changeNote,
    this.requiresReacceptance = false,
  });

  final String id;
  final int version;
  final bool isCurrent;
  final DateTime? publishedAt;
  final DateTime? effectiveAt;
  final String? changeNote;
  final bool requiresReacceptance;
}

/// One policy with its text.
@immutable
class PolicyDetail {
  const PolicyDetail({
    required this.summary,
    required this.body,
    required this.contentHash,
    required this.availableLocales,
    required this.history,
  });

  final PolicySummary summary;

  /// The policy itself, in the restricted Markdown `PolicyBody` renders.
  final String body;

  /// SHA-256 of the body, as published. Shown nowhere; carried so the app can
  /// say, on a receipt, that the text has not changed under the signature.
  final String contentHash;

  final List<String> availableLocales;
  final List<PolicyVersionRef> history;
}

/// A signature, from her side: which policy, which issue, which day.
@immutable
class PolicyReceipt {
  const PolicyReceipt({
    required this.id,
    required this.kind,
    required this.slug,
    required this.title,
    required this.versionId,
    required this.version,
    required this.acceptedAt,
    required this.source,
    required this.locale,
    required this.isCurrent,
  });

  final String id;
  final PolicyKind kind;
  final String slug;
  final String title;
  final String versionId;
  final int version;
  final DateTime? acceptedAt;

  /// `registration`, `reconsent`, `seller_application` — what she was doing.
  final String source;
  final String locale;
  final bool isCurrent;
}
