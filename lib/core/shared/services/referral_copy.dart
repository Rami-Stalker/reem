import 'package:ohara/core/shared/entities/referral_terms.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// The invite programme, worded for whoever is reading it.
///
/// One programme, two readers, two sentences. The inviter is told her half
/// first; the friend she sends it to is told hers. Mixing the two is exactly
/// the bug this replaces: the friend received the inviter's line and read
/// that she would get 500 points and her friend 250.
abstract final class ReferralCopy {
  /// The message that leaves the phone, to the friend.
  static String forFriend(
    AppLocalizations l10n, {
    required String code,
    ReferralTerms? terms,
  }) => terms == null
      ? l10n.referralForFriendPlain(code)
      : l10n.referralForFriend(
          terms.referredDiscountPercent,
          terms.referredPoints,
          code,
        );

  /// The line under «ادعي صاحبتكِ», to the inviter.
  static String forInviter(AppLocalizations l10n, ReferralTerms terms) =>
      l10n.referralForInviter(
        terms.referrerPoints,
        terms.referrerDiscountPercent,
        terms.referredDiscountPercent,
        terms.referredPoints,
      );
}
