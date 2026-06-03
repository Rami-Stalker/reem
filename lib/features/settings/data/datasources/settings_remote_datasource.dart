import 'package:reem/core/shared/models/user_model.dart';

import '../models/address_model.dart';
import '../models/coupon_model.dart';
import '../models/notification_settings_model.dart';
import '../models/rewards_model.dart';

abstract interface class SettingsRemoteDataSource {
  Future<List<AddressModel>> getAddresses();

  Future<List<CouponModel>> getCoupons();

  Future<List<NotificationSettingsModel>> getNotifications();

  Future<UserModel> updateProfile({
    String? name,
    String? bio,
    String? imageUrl,
  });

  Future<RewardsModel> getRewards();
}
