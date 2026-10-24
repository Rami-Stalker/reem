import 'package:ohara/l10n/app_localizations.dart';

/// Minimum password length. Kept here so the rule and the message that
/// explains it cannot drift apart.
const int kPasswordMinLength = 10;

/// Form validation for the auth screens.
///
/// Validators take the localisations rather than returning English. They are
/// static and have no `BuildContext`, so the caller passes `context.l10n` —
/// which is what a `TextFormField` validator has to hand anyway. Returning a
/// hardcoded English string here would have made every auth error message
/// unlocalisable no matter what the rest of the app did.
abstract final class AuthFormValidators {
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _phone = RegExp(r'^\+?[0-9]{7,15}$');

  static bool isEmail(String value) => _email.hasMatch(value.trim());

  static bool isPhone(String value) => _phone.hasMatch(value.trim());

  static String? requiredName(AppLocalizations l10n, String? value) {
    if ((value ?? '').trim().isEmpty) return l10n.fullNameRequired;
    return null;
  }

  static String? requiredField(
    AppLocalizations l10n,
    String label,
    String? value,
  ) {
    if ((value ?? '').trim().isEmpty) return '$label — ${l10n.error}';
    return null;
  }

  static String? optionalEmail(AppLocalizations l10n, String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return null;
    if (!isEmail(trimmed)) return l10n.validEmailRequired;
    return null;
  }

  static String? requiredEmailOrPhone(AppLocalizations l10n, String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return l10n.emailOrPhoneRequired;
    if (!isEmail(trimmed) && !isPhone(trimmed)) {
      return l10n.validEmailOrPhone;
    }
    return null;
  }

  static String? requiredPhone(AppLocalizations l10n, String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return l10n.phoneRequired;
    if (!isPhone(trimmed)) return l10n.validPhone;
    return null;
  }

  static String? requiredPassword(AppLocalizations l10n, String? value) {
    if ((value ?? '').isEmpty) return l10n.passwordRequired;
    return null;
  }

  static String? strongPassword(AppLocalizations l10n, String? value) {
    final password = value ?? '';
    if (password.length < kPasswordMinLength) {
      return l10n.passwordMinLength(kPasswordMinLength);
    }
    if (!RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return l10n.passwordStrengthRule;
    }
    return null;
  }
}
