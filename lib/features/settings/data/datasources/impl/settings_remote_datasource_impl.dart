import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/core/shared/models/user_model.dart';
import 'package:reem/features/settings/data/datasources/settings_remote_datasource.dart';
import 'package:reem/features/settings/data/models/address_model.dart';
import 'package:reem/features/settings/data/models/coupon_model.dart';
import 'package:reem/features/settings/data/models/notification_settings_model.dart';
import 'package:reem/features/settings/data/models/rewards_model.dart';

final class SettingsRemoteDataSourceImpl extends BaseRemoteDataSource
    implements SettingsRemoteDataSource {
  const SettingsRemoteDataSourceImpl(super.dio);

  @override
  Future<List<AddressModel>> getAddresses() async {
    final list = await getList(ApiEndpoints.addresses);
    return list
        .whereType<Map>()
        .map((e) => AddressModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<CouponModel>> getCoupons() async {
    final list = await getList(ApiEndpoints.coupons);
    return list
        .whereType<Map>()
        .map((e) => CouponModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<NotificationSettingsModel>> getNotifications() async {
    final list = await getList(ApiEndpoints.notifications);
    return list
        .whereType<Map>()
        .map(
          (e) => NotificationSettingsModel.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  @override
  Future<UserModel> updateProfile({
    String? name,
    String? bio,
    String? imageUrl,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (bio != null) body['bio'] = bio;
    if (imageUrl != null) body['image_url'] = imageUrl;

    final json = await patchJson(ApiEndpoints.usersMe, body: body);
    final userJson = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    return UserModel.fromJson(userJson);
  }

  @override
  Future<RewardsModel> getRewards() async {
    final json = await getJson(ApiEndpoints.rewards);
    final rewardsJson = json['rewards'] is Map<String, dynamic>
        ? json['rewards'] as Map<String, dynamic>
        : json;
    return RewardsModel.fromJson(rewardsJson);
  }
}
