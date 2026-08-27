/// Digit normalisation for Arabic screens.
///
/// `intl` disagrees with itself: `NumberFormat(locale: 'ar')` renders Western
/// digits (`300,000`) while `DateFormat(locale: 'ar')` renders Arabic-Indic
/// ones (`٢٠٢٦`). Left alone that puts both systems in a single row — a price
/// in one script beside its date in another — which reads as a bug even when
/// each half is defensible on its own.
///
/// Reem settles on **Western digits**, because that is what Syrian shoppers
/// see on price tags, on bank apps, and in the numbers sellers type in. Money
/// already formats that way, so dates are brought to match rather than the
/// other way round.
library;

const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
const _extendedArabicIndic = '۰۱۲۳۴۵۶۷۸۹'; // Persian/Urdu forms

/// Rewrites Arabic-Indic digits as Western ones, leaving everything else be.
String toWesternDigits(String input) {
  if (input.isEmpty) return input;

  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    final arabic = _arabicIndic.indexOf(char);
    if (arabic >= 0) {
      buffer.write(arabic);
      continue;
    }
    final extended = _extendedArabicIndic.indexOf(char);
    if (extended >= 0) {
      buffer.write(extended);
      continue;
    }
    buffer.write(char);
  }
  return buffer.toString();
}
