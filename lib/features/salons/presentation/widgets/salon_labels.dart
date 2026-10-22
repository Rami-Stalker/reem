import 'package:reem/features/salons/domain/entities/appointment.dart';
import 'package:reem/features/salons/domain/entities/salon.dart';

/// The Arabic words this feature uses, in one place.
///
/// Not in `app_ar.arb` on purpose, and it is worth saying why: these are a
/// *closed vocabulary that mirrors a database enum*, and the two have to stay
/// in step. A translator editing an `.arb` cannot add a salon category, and a
/// developer adding one to the Prisma enum would have to remember to add it to
/// two `.arb` files and regenerate — which is exactly the kind of two-place
/// edit that drifts. Everything a translator can usefully change is in the arb
/// files; this is the enum's own face.
abstract final class SalonLabels {
  static String category(SalonCategory value) => switch (value) {
    SalonCategory.hair => 'الشعر',
    SalonCategory.nails => 'الأظافر',
    SalonCategory.skin => 'العناية بالبشرة',
    SalonCategory.makeup => 'المكياج',
    SalonCategory.lashesBrows => 'الرموش والحواجب',
    SalonCategory.hairRemoval => 'إزالة الشعر',
    SalonCategory.massageSpa => 'المساج والسبا',
    SalonCategory.bridal => 'خدمات العرائس',
    SalonCategory.other => 'خدمات أخرى',
  };

  static String status(AppointmentStatus value) => switch (value) {
    AppointmentStatus.pending => 'قيد الانتظار',
    AppointmentStatus.confirmed => 'مؤكّد',
    AppointmentStatus.completed => 'مكتمل',
    AppointmentStatus.cancelled => 'ملغى',
    AppointmentStatus.noShow => 'لم تحضري',
  };

  /// What the status means, for the line under the badge. A woman looking at
  /// «قيد الانتظار» wants to know whether she has an appointment or not.
  static String statusHint(AppointmentStatus value) => switch (value) {
    AppointmentStatus.pending => 'بانتظار تأكيد الصالون',
    AppointmentStatus.confirmed => 'موعدكِ محجوز',
    AppointmentStatus.completed => 'تمّت الزيارة',
    AppointmentStatus.cancelled => 'أُلغي هذا الموعد',
    AppointmentStatus.noShow => 'سجّل الصالون عدم الحضور',
  };

  static String location(ServiceLocation value) => switch (value) {
    ServiceLocation.inSalon => 'في الصالون',
    ServiceLocation.atHome => 'في المنزل',
    ServiceLocation.both => 'في الصالون أو المنزل',
  };

  static String cancelledBy(AppointmentActor? actor) => switch (actor) {
    AppointmentActor.customer => 'ألغيتِ هذا الموعد',
    AppointmentActor.salon => 'ألغى الصالون هذا الموعد',
    AppointmentActor.system => 'أُلغي تلقائياً لعدم تأكيده قبل موعده',
    null => 'أُلغي هذا الموعد',
  };

  /// `٤٥ دقيقة` / `ساعة ونصف` — a duration a woman reads rather than parses.
  static String duration(int minutes) {
    if (minutes < 60) return '$minutes دقيقة';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    final hoursLabel = switch (hours) {
      1 => 'ساعة',
      2 => 'ساعتان',
      _ => '$hours ساعات',
    };
    if (rest == 0) return hoursLabel;
    if (rest == 30) return '$hoursLabel ونصف';
    return '$hoursLabel و$rest دقيقة';
  }

  /// 0 = Sunday, matching `SalonHours.weekday` and the server's column.
  static String weekday(int weekday) => switch (weekday % 7) {
    0 => 'الأحد',
    1 => 'الإثنين',
    2 => 'الثلاثاء',
    3 => 'الأربعاء',
    4 => 'الخميس',
    5 => 'الجمعة',
    _ => 'السبت',
  };

  /// «الخميس ١٨ أيلول» — a date she recognises. Arabic month names as used in
  /// the Levant rather than the transliterated Gregorian ones.
  static String date(DateTime when) {
    const months = [
      'كانون الثاني',
      'شباط',
      'آذار',
      'نيسان',
      'أيار',
      'حزيران',
      'تموز',
      'آب',
      'أيلول',
      'تشرين الأول',
      'تشرين الثاني',
      'كانون الأول',
    ];
    return '${weekday(when.weekday % 7)} ${when.day} ${months[when.month - 1]}';
  }

  /// `٦:٣٠ م` — a twelve-hour clock, which is how an appointment is spoken of.
  static String time(DateTime when) {
    final hour = when.hour % 12 == 0 ? 12 : when.hour % 12;
    final minute = when.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${when.hour < 12 ? 'ص' : 'م'}';
  }

  /// «الخميس ١٨ أيلول · ٦:٣٠ م».
  static String dateTime(DateTime when) => '${date(when)} · ${time(when)}';

  /// How far away it is, for a card that has already said the date.
  static String relativeDay(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(when.year, when.month, when.day);
    final days = that.difference(today).inDays;
    return switch (days) {
      0 => 'اليوم',
      1 => 'غداً',
      2 => 'بعد غد',
      _ when days > 2 && days <= 7 => 'بعد $days أيام',
      _ => date(when),
    };
  }
}
