import 'package:reem/core/shared/models/user_model.dart';
import 'package:reem/features/settings/data/models/address_model.dart';
import 'package:reem/features/settings/data/models/coupon_model.dart';
import 'package:reem/features/settings/data/models/notification_preferences_model.dart';
import 'package:reem/features/settings/data/models/notification_settings_model.dart';
import 'package:reem/features/settings/data/models/rewards_model.dart';
import 'package:reem/features/settings/domain/entities/address_draft.dart';
import 'package:reem/features/settings/domain/entities/coupon_validation.dart';
import 'package:reem/features/settings/domain/entities/notification_preferences.dart';

abstract interface class SettingsRemoteDataSource {
  Future<List<AddressModel>> getAddresses();

  Future<AddressModel> createAddress(AddressDraft draft);

  Future<AddressModel> updateAddress(String id, AddressDraft draft);

  Future<void> deleteAddress(String id);

  Future<AddressModel> setDefaultAddress(String id);

  Future<List<CouponModel>> getCoupons();

  Future<CouponValidation> validateCoupon({
    required String code,
    required double subtotal,
    required String currency,
  });

  Future<List<NotificationSettingsModel>> getNotifications();
  Future<void> markNotificationRead(String id);
  Future<void> markAllNotificationsRead();

  Future<NotificationPreferencesModel> getNotificationPreferences();

  Future<NotificationPreferencesModel> updateNotificationPreferences(
    NotificationPreferences preferences,
  );

  Future<UserModel> updateProfile({
    String? name,
    String? bio,
    String? imageUrl,
  });

  Future<RewardsModel> getRewards();
}
