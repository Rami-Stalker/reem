import 'package:intl/intl.dart';

import 'package:reem/core/utils/arabic_numerals.dart';
import 'package:reem/l10n/app_localizations.dart';

/// "قبل ٣ دقائق" / "3 minutes ago", in the reader's language.
///
/// Deliberately coarse: a conversation list is scanned, not read, and an exact
/// clock time on a message from four minutes ago is noise. The steps are the
/// ones people actually think in — now, minutes, hours, yesterday, a date.
String formatRelativeTime(AppLocalizations l10n, DateTime moment) {
  final now = DateTime.now();
  final elapsed = now.difference(moment);

  // A clock skewed a few seconds ahead of the server must not produce
  // "in 2 seconds"; anything at or before the present reads as just now.
  if (elapsed.inMinutes < 1) return l10n.justNow;
  if (elapsed.inMinutes < 60) return l10n.timeAgoMinutes(elapsed.inMinutes);
  if (elapsed.inHours < 24) return l10n.timeAgoHours(elapsed.inHours);
  if (elapsed.inDays < 7) return l10n.timeAgoDays(elapsed.inDays);

  // Older than a week: a date is more use than a count of days. Same-year
  // dates drop the year, which is how a date is spoken aloud.
  final pattern = moment.year == now.year ? 'd MMM' : 'd MMM yyyy';
  return toWesternDigits(
    DateFormat(pattern, l10n.localeName).format(moment),
  );
}

/// The timestamp on a conversation row: a clock time for today, a weekday for
/// this week, a date beyond it. Narrower than [formatRelativeTime] because it
/// sits in a corner beside a name and must stay short.
String formatThreadStamp(AppLocalizations l10n, DateTime moment) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(moment.year, moment.month, moment.day);
  final daysApart = today.difference(day).inDays;

  final pattern = switch (daysApart) {
    0 => 'h:mm a',
    < 7 => 'EEE',
    _ when moment.year == now.year => 'd MMM',
    _ => 'd/M/yy',
  };
  return toWesternDigits(
    DateFormat(pattern, l10n.localeName).format(moment),
  );
}

/// A calendar date — «5 أكتوبر», "5 October" — in the reader's language,
/// with Western digits like every other number in the app.
///
/// Seller screens once formatted dates with a hard-coded `'ar'` locale, which
/// gave English readers Arabic month names and Arabic readers Arabic-Indic
/// digits. Going through here makes both impossible.
String formatCalendarDate(
  AppLocalizations l10n,
  DateTime moment, {
  String pattern = 'd MMMM',
}) => toWesternDigits(
  DateFormat(pattern, l10n.localeName).format(moment.toLocal()),
);
