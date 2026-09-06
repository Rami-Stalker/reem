import 'package:flutter/material.dart';

import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/value_objects/money.dart';

// ── Formatting ───────────────────────────────────────────────────────────

/// Thousands separators, and a `—` for a figure that does not exist.
String formatCount(num? value) {
  if (value == null) return '—';
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer(rounded < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i += 1) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// A unit count that may be fractional.
///
/// `formatCount` rounds, and a forecast of 0.4 units printed as "0" beside a
/// revenue figure of 305,950 SYP reads as a contradiction — the reader cannot
/// tell whether the units or the money is wrong. Below ten, a decimal is
/// shown; above it, the fraction is noise.
String formatUnits(double? units) {
  if (units == null) return '—';
  if (units >= 10) return formatCount(units);
  return units.toStringAsFixed(1);
}

String formatRate(double? rate) =>
    rate == null ? '—' : '${(rate * 100).toStringAsFixed(1)}٪';

String formatMoney(Money? money) => money?.format() ?? '—';

/// Days, as a phrase rather than a bare number.
String formatDays(BuildContext context, double? days) {
  if (days == null) return '—';
  final l10n = context.l10n;
  if (days < 1) return l10n.trendToday;
  return l10n.trendDaysValue(days.round());
}
