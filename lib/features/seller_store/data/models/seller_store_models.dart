import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/seller_store/domain/entities/seller_store.dart';

/// Wire → domain for the shop's settings, team, activity and codes.
abstract final class SellerStoreMapper {
  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static StorePolicies policies(Map<String, dynamic> json) => StorePolicies(
    platformReturnDays: (json['platform_return_days'] as num?)?.toInt() ?? 7,
    acceptsExchanges: json['accepts_exchanges'] as bool? ?? true,
    exchangeNote: _text(json['exchange_note']),
    returnNote: _text(json['return_note']),
    careNote: _text(json['care_note']),
    customOrderNote: _text(json['custom_order_note']),
    updatedAt: _date(json['updated_at']),
  );

  static ShippingSettings shipping(Map<String, dynamic> json) =>
      ShippingSettings(
        shipsFromGovernorate: _text(json['ships_from_governorate']),
        shipsFromArea: _text(json['ships_from_area']),
        defaultHandlingDays:
            (json['default_handling_days'] as num?)?.toInt() ?? 1,
        offersPickup: json['offers_pickup'] as bool? ?? false,
        pickupAddress: _text(json['pickup_address']),
        pickupHours: _text(json['pickup_hours']),
        packagingNote: _text(json['packaging_note']),
        updatedListings: (json['updated_listings'] as num?)?.toInt(),
        rates: [
          for (final row
              in (json['platform_rates'] as List? ?? const []).whereType<Map>())
            ShippingRate(
              governorate: row['governorate'] as String? ?? '',
              isRural: row['is_rural'] as bool? ?? false,
              fee: Money.fromJson(row['fee']),
              etaHoursMin: (row['eta_hours_min'] as num?)?.toInt() ?? 0,
              etaHoursMax: (row['eta_hours_max'] as num?)?.toInt() ?? 0,
            ),
        ],
      );

  static StoreTeamMember member(Map<String, dynamic> json) {
    final member = (json['member'] as Map?)?.cast<String, dynamic>() ?? {};
    return StoreTeamMember(
      id: json['id'] as String? ?? '',
      role: StoreTeamRole.fromWire(json['role'] as String?),
      isActive: json['status'] == 'active',
      memberId: member['id'] as String? ?? '',
      name: member['name'] as String? ?? '',
      username: _text(member['username']),
      imageUrl: _text(member['image_url']),
      phone: _text(member['phone']),
      invitedAt: _date(json['invited_at']),
    );
  }

  static StoreMembership membership(Map<String, dynamic> json) {
    final store = (json['store'] as Map?)?.cast<String, dynamic>() ?? {};
    return StoreMembership(
      id: json['id'] as String? ?? '',
      role: StoreTeamRole.fromWire(json['role'] as String?),
      isActive: json['status'] == 'active',
      storeId: store['id'] as String? ?? '',
      storeName: store['name'] as String? ?? '',
      storeImageUrl: _text(store['image_url']),
    );
  }

  static ActivityPage activity(Map<String, dynamic> json) {
    final entries = [
      for (final row in (json['data'] as List? ?? const []).whereType<Map>())
        ActivityEntry(
          id: row['id'] as String? ?? '',
          action: row['action'] as String? ?? '',
          category: row['category'] as String? ?? '',
          succeeded: (row['outcome'] as String? ?? 'success').toLowerCase() ==
              'success',
          createdAt: _date(row['created_at']) ?? DateTime.now(),
          actorName: _text((row['actor'] as Map?)?['name']),
          byOwner: (row['actor'] as Map?)?['is_owner'] as bool? ?? true,
          device: _text(row['device']),
        ),
    ];
    return ActivityPage(
      entries: entries,
      nextBefore: json['has_more'] == true
          ? json['next_before'] as String?
          : null,
    );
  }

  static SellerCoupon coupon(Map<String, dynamic> json) => SellerCoupon(
    id: json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    percent: double.tryParse('${json['discount_percent']}')?.round() ?? 0,
    expiresAt: _date(json['expires_at']) ?? DateTime.now(),
    isActive: json['is_active'] as bool? ?? false,
    usedCount: (json['used_count'] as num?)?.toInt() ?? 0,
    maxUses: (json['max_uses'] as num?)?.toInt(),
    minOrder: json['min_order_amount'] == null
        ? null
        : Money.fromJson({
            'amount': '${json['min_order_amount']}',
            'currency': 'SYP',
          }),
  );
}
