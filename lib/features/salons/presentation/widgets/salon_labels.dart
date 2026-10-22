import 'package:reem/features/salons/domain/entities/appointment.dart';
import 'package:reem/features/salons/domain/entities/salon.dart';
import 'package:reem/l10n/app_localizations.dart';

/// The words this feature uses for its enums, in one place.
///
/// The text lives in the ARB bundles like every other string in the app; this
/// is only the switch from a database enum to its key. Adding a value to one
/// of these enums is a compile error here until it has a label, which keeps
/// the enum and its words in step.
abstract final class SalonLabels {
  static String category(AppLocalizations l10n, SalonCategory value) =>
      switch (value) {
        SalonCategory.hair => l10n.salonCategoryHair,
        SalonCategory.nails => l10n.salonCategoryNails,
        SalonCategory.skin => l10n.salonCategorySkin,
        SalonCategory.makeup => l10n.salonCategoryMakeup,
        SalonCategory.lashesBrows => l10n.salonCategoryLashesBrows,
        SalonCategory.hairRemoval => l10n.salonCategoryHairRemoval,
        SalonCategory.massageSpa => l10n.salonCategoryMassageSpa,
        SalonCategory.bridal => l10n.salonCategoryBridal,
        SalonCategory.other => l10n.salonCategoryOther,
      };

  static String status(AppLocalizations l10n, AppointmentStatus value) =>
      switch (value) {
        AppointmentStatus.pending => l10n.salonStatusPending,
        AppointmentStatus.confirmed => l10n.salonStatusConfirmed,
        AppointmentStatus.completed => l10n.salonStatusCompleted,
        AppointmentStatus.cancelled => l10n.salonStatusCancelled,
        AppointmentStatus.noShow => l10n.salonStatusNoShow,
      };

  /// What the status means, for the line under the badge. A woman looking at
  /// «قيد الانتظار» wants to know whether she has an appointment or not.
  static String statusHint(AppLocalizations l10n, AppointmentStatus value) =>
      switch (value) {
        AppointmentStatus.pending => l10n.salonStatusHintPending,
        AppointmentStatus.confirmed => l10n.salonStatusHintConfirmed,
        AppointmentStatus.completed => l10n.salonStatusHintCompleted,
        AppointmentStatus.cancelled => l10n.salonStatusHintCancelled,
        AppointmentStatus.noShow => l10n.salonStatusHintNoShow,
      };

  static String location(AppLocalizations l10n, ServiceLocation value) =>
      switch (value) {
        ServiceLocation.inSalon => l10n.salonLocationInSalon,
        ServiceLocation.atHome => l10n.salonLocationAtHome,
        ServiceLocation.both => l10n.salonLocationBoth,
      };

  static String cancelledBy(AppLocalizations l10n, AppointmentActor? actor) =>
      switch (actor) {
        AppointmentActor.customer => l10n.salonCancelledByCustomer,
        AppointmentActor.salon => l10n.salonCancelledBySalon,
        AppointmentActor.system => l10n.salonCancelledBySystem,
        null => l10n.salonStatusHintCancelled,
      };

  /// `٤٥ دقيقة` / `ساعة ونصف` — a duration a woman reads rather than parses.
  static String duration(AppLocalizations l10n, int minutes) {
    if (minutes < 60) return l10n.salonDurationMinutes(minutes);
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    final hoursLabel = switch (hours) {
      1 => l10n.salonDurationOneHour,
      2 => l10n.salonDurationTwoHours,
      _ => l10n.salonDurationHours(hours),
    };
    if (rest == 0) return hoursLabel;
    if (rest == 30) return l10n.salonDurationAndHalf(hoursLabel);
    return l10n.salonDurationAndMinutes(hoursLabel, rest);
  }

  /// 0 = Sunday, matching `SalonHours.weekday` and the server's column.
  static String weekday(AppLocalizations l10n, int weekday) =>
      switch (weekday % 7) {
        0 => l10n.salonWeekdaySun,
        1 => l10n.salonWeekdayMon,
        2 => l10n.salonWeekdayTue,
        3 => l10n.salonWeekdayWed,
        4 => l10n.salonWeekdayThu,
        5 => l10n.salonWeekdayFri,
        _ => l10n.salonWeekdaySat,
      };

  /// «الخميس ١٨ أيلول» — a date she recognises. Arabic month names as used in
  /// the Levant rather than the transliterated Gregorian ones.
  static String date(AppLocalizations l10n, DateTime when) {
    final months = [
      l10n.salonMonth1,
      l10n.salonMonth2,
      l10n.salonMonth3,
      l10n.salonMonth4,
      l10n.salonMonth5,
      l10n.salonMonth6,
      l10n.salonMonth7,
      l10n.salonMonth8,
      l10n.salonMonth9,
      l10n.salonMonth10,
      l10n.salonMonth11,
      l10n.salonMonth12,
    ];
    return '${weekday(l10n, when.weekday % 7)} ${when.day} '
        '${months[when.month - 1]}';
  }

  /// `٦:٣٠ م` — a twelve-hour clock, which is how an appointment is spoken of.
  static String time(AppLocalizations l10n, DateTime when) {
    final hour = when.hour % 12 == 0 ? 12 : when.hour % 12;
    final minute = when.minute.toString().padLeft(2, '0');
    final period = when.hour < 12 ? l10n.salonTimeAm : l10n.salonTimePm;
    return '$hour:$minute $period';
  }

  /// «الخميس ١٨ أيلول · ٦:٣٠ م».
  static String dateTime(AppLocalizations l10n, DateTime when) =>
      '${date(l10n, when)} · ${time(l10n, when)}';

  /// How far away it is, for a card that has already said the date.
  static String relativeDay(AppLocalizations l10n, DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(when.year, when.month, when.day);
    final days = that.difference(today).inDays;
    return switch (days) {
      0 => l10n.salonToday,
      1 => l10n.salonTomorrow,
      2 => l10n.salonDayAfterTomorrow,
      _ when days > 2 && days <= 7 => l10n.salonInDays(days),
      _ => date(l10n, when),
    };
  }
}
