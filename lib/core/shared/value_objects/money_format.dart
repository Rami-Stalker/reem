import 'package:intl/intl.dart';

import 'money.dart';

/// Renders a bare `double` as Syrian pounds.
///
/// Several dashboards carry money as plain numbers rather than [Money] — the
/// analytics and seller-dashboard entities both do — and every one of them was
/// printing `'\$$value'`. That is the wrong currency for a platform that
/// charges in SYP (Q48), and the wrong grouping besides. Routing those figures
/// through [Money] gives the right symbol, the right separators and the right
/// number of fraction digits (SYP is charged in whole units, so none).
///
/// This lives in core rather than in one feature because the seller console
/// and the admin console both need it, and a second copy is how the two drift.
extension SypFormat on double {
  Money get asSyp => Money(raw: toStringAsFixed(0), currency: Currency.syp);

  /// `1,450,000 ل.س` — for figures that have room to breathe.
  String get sypFull => asSyp.format();

  /// `1.45M ل.س` — for stat tiles and anywhere narrow that still needs to say
  /// which currency it means.
  String get sypCompact => asSyp.formatCompact();

  /// `1.45M` — for chart axes.
  ///
  /// Two things are dropped deliberately. The currency, because repeating
  /// «ل.س» down every tick is noise the panel heading already covers. And the
  /// Arabic compact words: `NumberFormat.compact(locale: 'ar')` spells out
  /// «12.1 مليون», which needs a fifth of a chart's width as gutter and gets
  /// clipped. The K/M suffix matches how counts are already abbreviated
  /// alongside, so a panel stays internally consistent.
  String get compactBare => NumberFormat.compact(locale: 'en').format(this);
}

/// `+12.4%` / `−3.1%` — the sign is part of the meaning, so it is always
/// shown, and the minus is a true minus sign rather than a hyphen.
String formatTrend(double percent) {
  final rounded = percent.abs().toStringAsFixed(1);
  return percent < 0 ? '−$rounded%' : '+$rounded%';
}

/// Compact counts for tiles: 1.2K, 3.4M.
String formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}
