import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/admin/presentation/providers/admin_actions.dart';

/// A console record, read as a record rather than as a payload.
///
/// The detail sheet used to print `JsonEncoder.withIndent('  ')` over the raw
/// row — so an operator who tapped a customer to see her phone number was shown
/// forty lines of braces, quoted keys and `2026-09-10T01:53:18.694Z`. That is
/// the API's language, not hers, and on a screen whose whole job is letting a
/// person decide something about a woman, a product or an order, it is not
/// information at all.
///
/// So the same map is rendered as labelled lines: the key in Arabic where the
/// console knows the word, the value formatted the way the rest of the app
/// formats that kind of value — money as money, a timestamp as a date, a flag
/// as نعم/لا, an enum as a readable word. Nested objects are followed one level
/// and lists are summarised, because a record is a thing to read, not a tree to
/// explore. The raw JSON is still available, one tap away, for the rare support
/// question that needs the literal bytes.
class AdminRecordDetails extends StatelessWidget {
  const AdminRecordDetails({super.key, required this.raw});

  final Map<String, dynamic> raw;

  /// Keys that say nothing to a human reading the row.
  ///
  /// Foreign keys and internal flags are not hidden to keep secrets — the row
  /// is already on her screen — but because a list of uuids buries the four
  /// lines she came for.
  static const _hidden = <String>{
    'id',
    'raw',
    'metadata',
    'search_key',
    'password_hash',
    'token',
    'secret',
  };

  @override
  Widget build(BuildContext context) {
    final rows = _rowsOf(context, raw, depth: 0);
    if (rows.isEmpty) {
      return Text(
        context.l10n.adminRecordNoDetails,
        style: context.dsText.bodySmall.tint(context.dsColors.onSurfaceVariant),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  List<Widget> _rowsOf(
    BuildContext context,
    Map<String, dynamic> source, {
    required int depth,
  }) {
    final widgets = <Widget>[];

    for (final entry in source.entries) {
      if (_hidden.contains(entry.key)) continue;
      if (entry.key.endsWith('_id') && depth == 0) continue;

      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      if (value is List && value.isEmpty) continue;
      if (value is Map && value.isEmpty) continue;

      // A nested object is worth following once — an order's `payment`, a
      // seller's `verification` — and no further: past that it is a tree, and a
      // tree is what the JSON dump already was.
      if (value is Map<String, dynamic> && depth == 0 && !_isMoney(value)) {
        final nested = _rowsOf(context, value, depth: 1);
        if (nested.isEmpty) continue;
        widgets.add(_GroupHeading(label: adminFieldLabel(context, entry.key)));
        widgets.addAll(nested);
        continue;
      }

      widgets.add(
        _DetailRow(
          label: adminFieldLabel(context, entry.key),
          value: adminFieldValue(context, entry.key, value as Object),
          isNested: depth > 0,
        ),
      );
    }

    return widgets;
  }

  static bool _isMoney(Map<String, dynamic> value) =>
      value.containsKey('amount') && value.containsKey('currency');
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isNested = false,
  });

  final String label;
  final String value;
  final bool isNested;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: DsSpacing.xs,
        right: isNested ? DsSpacing.md : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: SelectableText(
              value,
              style: context.dsText.bodySmall.tint(colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: DsSpacing.xs, bottom: DsSpacing.xxs),
    child: Text(
      label,
      style: context.dsText.bodySmall.semibold.tint(context.dsColors.onSurface),
    ),
  );
}

/// The Arabic word for a field the server sent.
///
/// A dictionary rather than ARB entries, deliberately: these are the column
/// names of twelve different server tables, they change when the API changes
/// rather than when the product's voice changes, and a translator has no
/// business being asked about `rate_bps`. An unknown key falls back to itself,
/// tidied — which is exactly what an operator would read in the JSON anyway,
/// only without the quotes.
String adminFieldLabel(BuildContext context, String key) {
  final arabic = context.l10n.localeName.startsWith('ar');
  if (!arabic) return _humanise(key);
  return _arabicFieldLabels[key] ?? _humanise(key);
}

const Map<String, String> _arabicFieldLabels = {
  'name': 'الاسم',
  'username': 'اسم المستخدم',
  'title': 'العنوان',
  'description': 'الوصف',
  'phone': 'الهاتف',
  'email': 'البريد',
  'status': 'الحالة',
  'role': 'الدور',
  'tier': 'المستوى',
  'number': 'الرقم',
  'order_number': 'رقم الطلب',
  'tracking_code': 'رمز التتبّع',
  'tracking_number': 'رقم الشحنة',
  'quantity': 'الكمية',
  'stock': 'المخزون',
  'price': 'السعر',
  'unit_price': 'سعر القطعة',
  'total': 'الإجمالي',
  'grand_total': 'الإجمالي',
  'amount': 'المبلغ',
  'currency': 'العملة',
  'commission': 'العمولة',
  'net': 'الصافي',
  'gross': 'الإجمالي قبل الحسم',
  'discount': 'الحسم',
  'shipping': 'الشحن',
  'shipping_total': 'كلفة الشحن',
  'balance': 'الرصيد',
  'rating': 'التقييم',
  'reviews_count': 'عدد التقييمات',
  'count': 'العدد',
  'priority': 'الأولوية',
  'rate_bps': 'النسبة',
  'created_at': 'أُنشئ في',
  'updated_at': 'آخر تحديث',
  'placed_at': 'تاريخ الطلب',
  'delivered_at': 'تاريخ التسليم',
  'confirmed_at': 'تاريخ التأكيد',
  'cancelled_at': 'تاريخ الإلغاء',
  'expires_at': 'ينتهي في',
  'reviewed_at': 'تاريخ المراجعة',
  'last_seen_at': 'آخر ظهور',
  'is_active': 'مُفعّل',
  'is_verified': 'موثّق',
  'is_featured': 'مميّز',
  'is_default': 'افتراضي',
  'verified': 'موثّق',
  'seller': 'البائعة',
  'seller_name': 'البائعة',
  'customer': 'الزبونة',
  'customer_name': 'الزبونة',
  'buyer': 'الزبونة',
  'product': 'المنتج',
  'category': 'الفئة',
  'brand': 'العلامة',
  'reason': 'السبب',
  'note': 'ملاحظة',
  'notes': 'ملاحظات',
  'subject': 'الموضوع',
  'message': 'الرسالة',
  'severity': 'الخطورة',
  'payment_status': 'حالة الدفع',
  'payment_method': 'طريقة الدفع',
  'method': 'الطريقة',
  'governorate': 'المحافظة',
  'city': 'المدينة',
  'district': 'المنطقة',
  'address_line': 'العنوان',
  'recipient_name': 'المستلِمة',
  'recipient_phone': 'هاتف المستلِمة',
  'business_name': 'اسم النشاط',
  'action': 'الإجراء',
  'actor': 'المنفّذ',
  'items': 'العناصر',
  'items_count': 'عدد العناصر',
  'deliveries_count': 'عدد التوصيلات',
  'payment': 'الدفع',
  'shipment': 'الشحنة',
  'carrier': 'شركة التوصيل',
  'provider': 'المزوّد',
  'key': 'المفتاح',
  'value': 'القيمة',
  'type': 'النوع',
  'kind': 'النوع',
  'level': 'المستوى',
  'image_url': 'الصورة',
  'slug': 'المُعرّف اللفظي',
  'seller_level': 'مستوى البائعة',
  'mfa_enabled': 'التحقق بخطوتين',
  'device_verification': 'تحقّق الجهاز',
  'device_verification_required': 'تحقّق الجهاز مطلوب',
  'phone_verified_at': 'تاريخ توثيق الهاتف',
  'declared_female': 'أقرّت بأنها امرأة',
  'orders_count': 'عدد الطلبات',
  'products_count': 'عدد المنتجات',
  'followers_count': 'عدد المتابِعات',
  'last_order_at': 'آخر طلب',
  'suspended_at': 'تاريخ التعليق',
  'disabled_at': 'تاريخ التعطيل',
  'locked_until': 'موقوف حتى',
  'moderation_status': 'حالة المراجعة',
  'verification_status': 'حالة التوثيق',
  'resolution': 'القرار',
  'state': 'الحالة',
  'variant': 'الخيار',
  'offers_count': 'عدد العروض',
  'live_stock': 'المخزون المتاح',
  'min_price_syp': 'أقل سعر',
  'max_price_syp': 'أعلى سعر',
};

/// Fields whose value is an enum the console already knows how to say.
///
/// `role: customer` is a database constant, not a word an operator reads;
/// `adminStatusLabel` has the Arabic for every one of them and is the same
/// function the status chip on the row above uses, so the sheet and the row
/// cannot disagree.
/// A seller's standing, which `adminStatusLabel` does not carry — its map is
/// about the states an operator *acts* on, and a level is something she reads.
const _sellerLevels = <String, String>{
  'BASIC': 'أساسية',
  'VERIFIED': 'موثّقة',
  'PREMIUM': 'مميّزة',
};

const _enumFields = <String>{
  'status',
  'role',
  'tier',
  'severity',
  'priority',
  'kind',
  'type',
  'state',
  'seller_level',
  'payment_status',
  'payment_method',
  'moderation_status',
  'verification_status',
  'resolution',
  'method',
};

/// The value, formatted the way the rest of the app formats that kind of thing.
String adminFieldValue(BuildContext context, String key, Object value) {
  if (value is bool) {
    return value ? context.l10n.yes : context.l10n.no;
  }

  if (value is Map<String, dynamic>) {
    final money = Money.tryFromJson(value);
    if (money != null) return money.format();
    // A nested object reached at depth — summarised, because the alternative is
    // the tree the JSON dump already was.
    final name = value['name'] ?? value['title'] ?? value['number'];
    if (name != null) return name.toString();
    return context.l10n.adminRecordNestedObject(value.length);
  }

  if (value is Map) {
    return adminFieldValue(context, key, Map<String, dynamic>.from(value));
  }

  if (value is List) {
    if (value.every((item) => item is String || item is num)) {
      return value.join('، ');
    }
    return context.l10n.adminRecordItemCount(value.length);
  }

  if (value is num) {
    return NumberFormat.decimalPattern(context.l10n.localeName).format(value);
  }

  final text = value.toString();

  // A timestamp is only useful once it is in her calendar.
  final parsed = DateTime.tryParse(text);
  if (parsed != null && text.length >= 10 && text.contains('-')) {
    return DateFormat.yMMMd(
      context.l10n.localeName,
    ).add_jm().format(parsed.toLocal());
  }

  // `AWAITING_SELLER_CONFIRMATION` and `customer` are both constants rather
  // than words. The console already owns the Arabic for most of them.
  if (_enumFields.contains(key) ||
      RegExp(r'^[A-Z][A-Z0-9_]{2,}$').hasMatch(text)) {
    final level = _sellerLevels[text.toUpperCase()];
    if (level != null && context.l10n.localeName.startsWith('ar')) {
      return level;
    }
    return adminStatusLabel(context.l10n, text);
  }

  return text;
}

String _humanise(String key) {
  final words = key.replaceAll('_', ' ').trim();
  if (words.isEmpty) return key;
  return words[0].toUpperCase() + words.substring(1);
}
