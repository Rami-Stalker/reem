import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/settings/data/datasources/settings_remote_datasource.dart';
import 'package:reem/features/settings/domain/entities/address_draft.dart';
import 'package:reem/features/settings/domain/entities/address_entity.dart';
import 'package:reem/features/settings/domain/entities/coupon_entity.dart';
import 'package:reem/features/settings/domain/entities/coupon_validation.dart';
import 'package:reem/features/settings/domain/entities/notification_entity.dart';
import 'package:reem/features/settings/domain/entities/notification_preferences.dart';
import 'package:reem/features/settings/domain/entities/rewards_entity.dart';
import 'package:reem/features/settings/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl with RepositoryHandler implements SettingsRepository {
  const SettingsRepositoryImpl({required this.remote});

  final SettingsRemoteDataSource remote;

  @override
  Future<Result<List<AddressEntity>>> getAddresses() =>
      guard(() => remote.getAddresses());

  @override
  Future<Result<AddressEntity>> createAddress(AddressDraft draft) =>
      guard(() => remote.createAddress(draft));

  @override
  Future<Result<AddressEntity>> updateAddress(String id, AddressDraft draft) =>
      guard(() => remote.updateAddress(id, draft));

  @override
  Future<Result<void>> deleteAddress(String id) =>
      guard(() => remote.deleteAddress(id));

  @override
  Future<Result<AddressEntity>> setDefaultAddress(String id) =>
      guard(() => remote.setDefaultAddress(id));

  @override
  Future<Result<List<CouponEntity>>> getCoupons() =>
      guard(() => remote.getCoupons());

  @override
  Future<Result<CouponValidation>> validateCoupon({
    required String code,
    required double subtotal,
    required String currency,
  }) => guard(
    () => remote.validateCoupon(
      code: code,
      subtotal: subtotal,
      currency: currency,
    ),
  );

  @override
  Future<Result<List<NotificationEntity>>> getNotifications() =>
      guard(() => remote.getNotifications());

  @override
  Future<Result<void>> markNotificationRead(String id) =>
      guard(() => remote.markNotificationRead(id));

  @override
  Future<Result<void>> markAllNotificationsRead() =>
      guard(() => remote.markAllNotificationsRead());

  @override
  Future<Result<NotificationPreferences>> getNotificationPreferences() =>
      guard(() => remote.getNotificationPreferences());

  @override
  Future<Result<NotificationPreferences>> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) =>
      guard(() => remote.updateNotificationPreferences(preferences));

  @override
  Future<Result<User>> updateProfile({
    String? name,
    String? bio,
    String? imageUrl,
  }) =>
      guard(
        () => remote.updateProfile(name: name, bio: bio, imageUrl: imageUrl),
      );

  @override
  Future<Result<RewardsEntity>> getRewards() => guard(() => remote.getRewards());
}
