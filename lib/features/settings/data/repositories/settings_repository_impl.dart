import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';

import '../../domain/entities/address_entity.dart';
import '../../domain/entities/coupon_entity.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/entities/rewards_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_remote_datasource.dart';

class SettingsRepositoryImpl with RepositoryHandler implements SettingsRepository {
  const SettingsRepositoryImpl({required this.remote});

  final SettingsRemoteDataSource remote;

  @override
  Future<Result<List<AddressEntity>>> getAddresses() =>
      guard(() => remote.getAddresses());

  @override
  Future<Result<List<CouponEntity>>> getCoupons() =>
      guard(() => remote.getCoupons());

  @override
  Future<Result<List<NotificationEntity>>> getNotifications() =>
      guard(() => remote.getNotifications());

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
