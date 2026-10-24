import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/features/auth/presentation/utils/auth_form_validators.dart';
import 'package:ohara/features/search/domain/entities/search_suggestions.dart';
import 'package:ohara/l10n/app_localizations_ar.dart';

void main() {
  group('AuthFormValidators', () {
    // Validators take the localisations so their messages are translatable.
    final l10n = AppLocalizationsAr();

    test('validates email or phone identifiers', () {
      expect(
        AuthFormValidators.requiredEmailOrPhone(l10n, 'reem@example.com'),
        isNull,
      );
      expect(AuthFormValidators.requiredEmailOrPhone(l10n, '+966555555555'), isNull);
      expect(
        AuthFormValidators.requiredEmailOrPhone(l10n, 'not valid'),
        l10n.validEmailOrPhone,
      );
    });

    test('requires strong registration and reset passwords', () {
      // The policy is 10+ characters with mixed case, a digit and a symbol.
      expect(AuthFormValidators.strongPassword(l10n, 'Reem12345!'), isNull);
      expect(
        AuthFormValidators.strongPassword(l10n, 'Reem1234'),
        l10n.passwordMinLength(10),
      );
      expect(
        AuthFormValidators.strongPassword(l10n, 'reem123456'),
        l10n.passwordStrengthRule,
      );
    });
  });

  group('SearchSuggestions', () {
    test(
      'combines categories and products without duplicate display terms',
      () {
        const suggestions = SearchSuggestions(
          categories: ['Dresses', 'Perfume'],
          products: ['dresses', 'Silk dress'],
        );

        expect(suggestions.combined, ['Dresses', 'Perfume', 'Silk dress']);
      },
    );
  });
}
