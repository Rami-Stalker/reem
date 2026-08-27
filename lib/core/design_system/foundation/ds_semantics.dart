import 'package:flutter/widgets.dart';

import '../../localization/l10n_extension.dart';

/// Semantic labels for accessibility.
///
/// These used to be `static const` English strings, which meant an Arabic
/// screen-reader user heard "Add to cart" and "Go back" on every core control —
/// the interface was localised but the spoken interface was not. They now read
/// from the current locale, so they need a [BuildContext].
extension DsSemantics on BuildContext {
  String get semanticsBack => l10n.a11yBack;
  String get semanticsClose => l10n.a11yClose;
  String get semanticsSearch => l10n.a11ySearch;
  String get semanticsCart => l10n.a11yCart;
  String get semanticsNotifications => l10n.a11yNotifications;
  String get semanticsProfile => l10n.a11yProfile;
  String get semanticsLike => l10n.a11yLike;
  String get semanticsShare => l10n.a11yShare;
  String get semanticsSave => l10n.a11ySave;
  String get semanticsMore => l10n.a11yMore;
  String get semanticsPlay => l10n.a11yPlay;
  String get semanticsAddToCart => l10n.addToCart;
  String get semanticsLoading => l10n.success;
  String get semanticsError => l10n.error;
}
