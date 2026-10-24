import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/core/shared/models/user_model.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/settings/data/datasources/settings_remote_datasource.dart';
import 'package:ohara/features/settings/data/models/address_model.dart';
import 'package:ohara/features/settings/data/models/coupon_model.dart';
import 'package:ohara/features/settings/data/models/notification_preferences_model.dart';
import 'package:ohara/features/settings/data/models/notification_settings_model.dart';
import 'package:ohara/features/settings/data/models/rewards_model.dart';
import 'package:ohara/features/settings/domain/entities/address_draft.dart';
import 'package:ohara/features/settings/domain/entities/coupon_validation.dart';
import 'package:ohara/features/settings/domain/entities/notification_preferences.dart';

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
  Future<AddressModel> createAddress(AddressDraft draft) async {
    final json = await postJson(
      ApiEndpoints.addresses,
      body: AddressModel.bodyFrom(draft),
    );
    return AddressModel.fromJson(json);
  }

  @override
  Future<AddressModel> updateAddress(String id, AddressDraft draft) async {
    final json = await patchJson(
      ApiEndpoints.addressById(id),
      body: AddressModel.bodyFrom(draft),
    );
    return AddressModel.fromJson(json);
  }

  @override
  Future<void> deleteAddress(String id) =>
      deleteRequest(ApiEndpoints.addressById(id));

  @override
  Future<AddressModel> setDefaultAddress(String id) async {
    final json = await postJson('${ApiEndpoints.addressById(id)}/default');
    return AddressModel.fromJson(json);
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
  Future<CouponValidation> validateCoupon({
    required String code,
    required double subtotal,
    required String currency,
  }) async {
    final json = await postJson(
      ApiEndpoints.couponsValidate,
      body: {
        'code': code,
        // Whole units: the server takes a number here and the platform charges
        // in Syrian pounds, which have no fraction.
        'subtotal': subtotal.round(),
        'currency': currency,
      },
    );

    return CouponValidation(
      code: json['code'] as String? ?? code,
      kind: CouponModel.kindFromWire(json['type']),
      discount:
          Money.tryFromJson(json['discount']) ??
          Money(raw: '0', currency: Currency.fromWire(currency)),
    );
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
  Future<void> markNotificationRead(String id) =>
      postJson(ApiEndpoints.notificationRead(id));

  @override
  Future<void> markAllNotificationsRead() =>
      postJson(ApiEndpoints.notificationsReadAll);

  @override
  Future<NotificationPreferencesModel> getNotificationPreferences() async {
    final json = await getJson(ApiEndpoints.notificationPreferences);
    return NotificationPreferencesModel.fromJson(json);
  }

  @override
  Future<NotificationPreferencesModel> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    final json = await patchJson(
      ApiEndpoints.notificationPreferences,
      body: NotificationPreferencesModel.toJson(preferences),
    );
    return NotificationPreferencesModel.fromJson(json);
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
