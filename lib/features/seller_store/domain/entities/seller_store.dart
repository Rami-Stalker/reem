import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/value_objects/money.dart';

/// «سياسات المتجر» — her words on top of the platform's guarantee.
class StorePolicies extends Equatable {
  const StorePolicies({
    this.platformReturnDays = 7,
    this.acceptsExchanges = true,
    this.exchangeNote,
    this.returnNote,
    this.careNote,
    this.customOrderNote,
    this.updatedAt,
  });

  /// The platform's return window, which no shop can shorten.
  final int platformReturnDays;
  final bool acceptsExchanges;
  final String? exchangeNote;
  final String? returnNote;
  final String? careNote;
  final String? customOrderNote;
  final DateTime? updatedAt;

  bool get hasNotes =>
      [exchangeNote, returnNote, careNote, customOrderNote].any(
        (note) => note != null && note.isNotEmpty,
      );

  @override
  List<Object?> get props => [
    platformReturnDays,
    acceptsExchanges,
    exchangeNote,
    returnNote,
    careNote,
    customOrderNote,
    updatedAt,
  ];
}

/// One governorate's platform delivery fee and time.
class ShippingRate extends Equatable {
  const ShippingRate({
    required this.governorate,
    required this.fee,
    required this.etaHoursMin,
    required this.etaHoursMax,
    this.isRural = false,
  });

  final String governorate;
  final Money fee;
  final int etaHoursMin;
  final int etaHoursMax;
  final bool isRural;

  @override
  List<Object?> get props => [governorate, fee, etaHoursMin, etaHoursMax];
}

/// «إعدادات الشحن».
class ShippingSettings extends Equatable {
  const ShippingSettings({
    this.shipsFromGovernorate,
    this.shipsFromArea,
    this.defaultHandlingDays = 1,
    this.offersPickup = false,
    this.pickupAddress,
    this.pickupHours,
    this.packagingNote,
    this.rates = const [],
    this.updatedListings,
  });

  final String? shipsFromGovernorate;
  final String? shipsFromArea;

  /// Days to prepare a parcel; every new listing starts with it.
  final int defaultHandlingDays;
  final bool offersPickup;
  final String? pickupAddress;
  final String? pickupHours;
  final String? packagingNote;

  /// The platform's delivery fees, by governorate.
  final List<ShippingRate> rates;

  /// After a save that moved her listings: how many moved.
  final int? updatedListings;

  @override
  List<Object?> get props => [
    shipsFromGovernorate,
    shipsFromArea,
    defaultHandlingDays,
    offersPickup,
    pickupAddress,
    pickupHours,
    packagingNote,
    rates,
  ];
}

/// What a team member may do for the shop.
enum StoreTeamRole {
  manager,
  orders,
  catalog;

  static StoreTeamRole fromWire(String? value) => switch (value) {
    'manager' => StoreTeamRole.manager,
    'catalog' => StoreTeamRole.catalog,
    _ => StoreTeamRole.orders,
  };

  String get wire => name.toUpperCase();
}

/// A person on the shop's team, or invited to it.
class StoreTeamMember extends Equatable {
  const StoreTeamMember({
    required this.id,
    required this.role,
    required this.isActive,
    required this.name,
    required this.memberId,
    this.username,
    this.imageUrl,
    this.phone,
    this.invitedAt,
  });

  final String id;
  final StoreTeamRole role;

  /// False while the invitation waits for her answer.
  final bool isActive;
  final String memberId;
  final String name;
  final String? username;
  final String? imageUrl;
  final String? phone;
  final DateTime? invitedAt;

  @override
  List<Object?> get props => [id, role, isActive];
}

/// A shop she works in, or has been invited to — the member's side.
class StoreMembership extends Equatable {
  const StoreMembership({
    required this.id,
    required this.role,
    required this.isActive,
    required this.storeId,
    required this.storeName,
    this.storeImageUrl,
  });

  final String id;
  final StoreTeamRole role;
  final bool isActive;
  final String storeId;
  final String storeName;
  final String? storeImageUrl;

  @override
  List<Object?> get props => [id, role, isActive, storeId];
}

/// One line of «سجل النشاط».
class ActivityEntry extends Equatable {
  const ActivityEntry({
    required this.id,
    required this.action,
    required this.category,
    required this.succeeded,
    required this.createdAt,
    this.actorName,
    this.byOwner = true,
    this.device,
  });

  /// `METHOD /route/:param`, or an account event such as `login`.
  final String action;
  final String category;
  final bool succeeded;
  final DateTime createdAt;
  final String id;

  /// Who did it — her, or a team member by name.
  final String? actorName;
  final bool byOwner;

  /// `ios`, `android`, `app` or `web`.
  final String? device;

  @override
  List<Object?> get props => [id];
}

class ActivityPage extends Equatable {
  const ActivityPage({required this.entries, this.nextBefore});

  final List<ActivityEntry> entries;

  /// Null when there is nothing older.
  final String? nextBefore;

  @override
  List<Object?> get props => [entries, nextBefore];
}

/// A discount code the shop funds, on her pieces only.
class SellerCoupon extends Equatable {
  const SellerCoupon({
    required this.id,
    required this.code,
    required this.percent,
    required this.expiresAt,
    required this.isActive,
    this.usedCount = 0,
    this.maxUses,
    this.minOrder,
  });

  final String id;
  final String code;
  final int percent;
  final DateTime expiresAt;
  final bool isActive;
  final int usedCount;
  final int? maxUses;
  final Money? minOrder;

  bool get isExpired => expiresAt.isBefore(DateTime.now());
  bool get isUsedUp => maxUses != null && usedCount >= maxUses!;
  bool get isLive => isActive && !isExpired && !isUsedUp;

  @override
  List<Object?> get props => [id, code, percent, isActive, usedCount];
}
