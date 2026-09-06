import 'package:flutter/widgets.dart';
import 'package:reem/l10n/app_localizations.dart';

extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  /// True when the interface is running in Arabic.
  ///
  /// Several entities carry `nameAr` / `nameEn` and expose a `name({arabic})`
  /// selector, so this reads `Localizations.localeOf(...)` once instead of
  /// each call site re-deriving it.
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';

  /// True when the interface reads right-to-left.
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
}
