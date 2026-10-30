// The invite, worded for whoever reads it.
//
// The bug this pins: the app sent the inviter's own line («لكِ 500 نقطة ولها
// 250») to the friend, who read it as her own rewards — backwards. The friend
// gets the welcome discount and 250 points; 500 is the inviter's.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/shared/entities/referral_terms.dart';
import 'package:ohara/core/shared/models/referral_terms_model.dart';
import 'package:ohara/core/shared/services/referral_copy.dart';
import 'package:ohara/l10n/app_localizations.dart';

const _terms = ReferralTerms(
  referrerPoints: 500,
  referredPoints: 250,
  referrerDiscountPercent: 10,
  referredDiscountPercent: 15,
  couponValidDays: 60,
);

void main() {
  for (final locale in const [Locale('ar'), Locale('en')]) {
    final l10n = lookupAppLocalizations(locale);

    group('${locale.languageCode}:', () {
      test('the friend is told her own half', () {
        final message = ReferralCopy.forFriend(
          l10n,
          code: 'MAHA15',
          terms: _terms,
        );
        expect(message, contains('15'));
        expect(message, contains('250'));
        expect(message, contains('MAHA15'));
        expect(
          message,
          isNot(contains('500')),
          reason: "500 is the inviter's reward, not hers",
        );
      });

      test('the inviter is told hers first', () {
        final line = ReferralCopy.forInviter(l10n, _terms);
        expect(line.indexOf('500'), lessThan(line.indexOf('250')));
      });

      test('without terms the friend still gets the code, and no numbers', () {
        final message = ReferralCopy.forFriend(l10n, code: 'MAHA15');
        expect(message, contains('MAHA15'));
        expect(message, isNot(contains('500')));
        expect(message, isNot(contains('250')));
      });
    });
  }

  group('decoding', () {
    test('terms decode from the server shape', () {
      expect(
        referralTermsFromJson({
          'referrer_points': 500,
          'referred_points': 250,
          'referrer_discount_percent': 10,
          'referred_discount_percent': 15,
          'max_discount_syp': 150000,
          'coupon_valid_days': 60,
        }),
        _terms,
      );
    });

    test('no terms is null, not invented numbers', () {
      expect(referralTermsFromJson(null), isNull);
      expect(referralTermsFromJson({'referrer_points': 500}), isNull);
    });
  });
}
