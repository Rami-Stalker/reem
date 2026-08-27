import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';

import '../entities/address_draft.dart';
import '../entities/address_entity.dart';
import '../entities/coupon_entity.dart';
import '../entities/coupon_validation.dart';
import '../entities/notification_entity.dart';
import '../entities/notification_preferences.dart';
import '../entities/rewards_entity.dart';

abstract interface class SettingsRepository {
  Future<Result<List<AddressEntity>>> getAddresses();

  Future<Result<AddressEntity>> createAddress(AddressDraft draft);

  Future<Result<AddressEntity>> updateAddress(String id, AddressDraft draft);

  Future<Result<void>> deleteAddress(String id);

  Future<Result<AddressEntity>> setDefaultAddress(String id);

  Future<Result<List<CouponEntity>>> getCoupons();

  /// Asks the server what [code] is worth on a basket of [subtotal].
  ///
  /// An ineligible coupon comes back as an [Error] carrying the server's own
  /// reason — below the minimum, already spent, not for this account — which
  /// is the sentence worth showing her.
  Future<Result<CouponValidation>> validateCoupon({
    required String code,
    required double subtotal,
    required String currency,
  });

  Future<Result<List<NotificationEntity>>> getNotifications();

  Future<Result<NotificationPreferences>> getNotificationPreferences();

  Future<Result<NotificationPreferences>> updateNotificationPreferences(
    NotificationPreferences preferences,
  );

  Future<Result<User>> updateProfile({
    String? name,
    String? bio,
    String? imageUrl,
  });

  Future<Result<RewardsEntity>> getRewards();
}
