// shared/value_objects/money.dart

import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// The currencies the platform prices in.
enum Currency {
  syp,
  usd;

  static Currency fromWire(String? value) => switch (value?.toUpperCase()) {
        'USD' => Currency.usd,
        _ => Currency.syp,
      };

  String get wire => name.toUpperCase();

  /// Symbol shown next to the figure. Arabic-first, since the UI is Arabic.
  String get symbol => switch (this) {
        Currency.syp => 'ل.س',
        Currency.usd => r'$',
      };

  /// SYP is charged in whole thousands (Q48), so fractions are never shown.
  int get fractionDigits => switch (this) {
        Currency.syp => 0,
        Currency.usd => 2,
      };
}

/// A currency-tagged amount, mirroring the backend's `{amount, currency}`.
///
/// The wire format carries the amount as a decimal **string**, not a JSON
/// number: SYP figures run into the millions and a JSON parser is free to
/// round a large float. `raw` keeps that string verbatim, and it is what gets
/// sent back to the server.
///
/// This type deliberately exposes no arithmetic. Every figure the customer is
/// charged — line totals, discounts, shipping, commission — is computed and
/// allocated server-side, where the values are exact decimals. The client's job
/// is to display what it was given, and a `+` operator here would be an
/// invitation to quietly disagree with the invoice.
class Money extends Equatable {
  /// The decimal string exactly as the server sent it, e.g. `"1450000.0000"`.
  final String raw;
  final Currency currency;

  const Money({required this.raw, required this.currency});

  static const Money zeroSyp = Money(raw: '0', currency: Currency.syp);

  /// Parses `{"amount": "1450000.0000", "currency": "SYP"}`.
  ///
  /// Also accepts a bare number so a stray legacy field does not crash a whole
  /// screen — but the currency then has to be supplied by the caller.
  static Money? tryFromJson(dynamic json, {Currency fallback = Currency.syp}) {
    if (json == null) return null;
    if (json is Map<String, dynamic>) {
      final amount = json['amount'];
      if (amount == null) return null;
      return Money(
        raw: amount.toString(),
        currency: Currency.fromWire(json['currency'] as String?),
      );
    }
    if (json is num) return Money(raw: json.toString(), currency: fallback);
    if (json is String) return Money(raw: json, currency: fallback);
    return null;
  }

  static Money fromJson(dynamic json, {Currency fallback = Currency.syp}) =>
      tryFromJson(json, fallback: fallback) ??
      Money(raw: '0', currency: fallback);

  Map<String, dynamic> toJson() => {'amount': raw, 'currency': currency.wire};

  /// For comparisons, sorting and progress bars only — never for a figure the
  /// customer is charged.
  double get approximateValue => double.tryParse(raw) ?? 0;

  bool get isZero => approximateValue == 0;

  /// True for a debit — a wallet spend, a reversal, a negative adjustment.
  bool get isNegative => approximateValue < 0;

  /// The same amount without its sign, for UI that shows direction with an
  /// icon or colour instead of a minus sign.
  Money get absolute =>
      isNegative ? Money(raw: raw.replaceFirst('-', ''), currency: currency) : this;

  /// `1,450,000 ل.س`
  ///
  /// Pass `includeSymbol: false` for the bare amount — used where the currency
  /// is already established by a neighbouring price, e.g. the struck-through
  /// original on a discounted product card, where repeating «ل.س» costs room
  /// a narrow two-column tile does not have.
  String format({String locale = 'ar', bool includeSymbol = true}) {
    final formatter = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: currency.fractionDigits,
    );
    final amount = formatter.format(approximateValue);
    return includeSymbol ? '$amount ${currency.symbol}' : amount;
  }

  /// `1.45M ل.س` — for tight spaces like chart axes and stat tiles.
  String formatCompact({String locale = 'ar'}) {
    final formatter = NumberFormat.compactCurrency(
      locale: locale,
      symbol: currency.symbol,
      decimalDigits: currency.fractionDigits,
    );
    return formatter.format(approximateValue);
  }

  @override
  String toString() => format();

  @override
  List<Object?> get props => [raw, currency];
}

/// Helper for the several endpoints that return a list of per-currency totals
/// (`subtotals_by_currency`, `gross_revenue`, …). The backend never sums across
/// currencies, so neither does the client.
extension MoneyListX on List<Money> {
  Money? get primary {
    if (isEmpty) return null;
    return firstWhere(
      (money) => money.currency == Currency.syp,
      orElse: () => first,
    );
  }

  String formatAll({String separator = ' + ', String locale = 'ar'}) =>
      map((money) => money.format(locale: locale)).join(separator);
}

List<Money> moneyListFromJson(dynamic json) {
  if (json is! List) {
    final single = Money.tryFromJson(json);
    return single == null ? const [] : [single];
  }
  return json
      .map(Money.tryFromJson)
      .whereType<Money>()
      .toList(growable: false);
}
