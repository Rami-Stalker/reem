import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';

import '../entities/address_entity.dart';
import '../entities/coupon_entity.dart';
import '../entities/notification_entity.dart';
import '../entities/rewards_entity.dart';

abstract interface class SettingsRepository {
  Future<Result<List<AddressEntity>>> getAddresses();

  Future<Result<List<CouponEntity>>> getCoupons();

  Future<Result<List<NotificationEntity>>> getNotifications();

  Future<Result<User>> updateProfile({
    String? name,
    String? bio,
    String? imageUrl,
  });

  Future<Result<RewardsEntity>> getRewards();
}
