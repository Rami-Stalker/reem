import 'package:reem/core/shared/entities/user.dart';

import '../../domain/entities/address_entity.dart';
import '../../domain/entities/coupon_entity.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/entities/rewards_entity.dart';

class SettingsState {
  const SettingsState({
    this.addresses = const [],
    this.coupons = const [],
    this.notifications = const [],
    this.rewards,
    this.user,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  final List<AddressEntity> addresses;
  final List<CouponEntity> coupons;
  final List<NotificationEntity> notifications;
  final RewardsEntity? rewards;
  final User? user;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  SettingsState copyWith({
    List<AddressEntity>? addresses,
    List<CouponEntity>? coupons,
    List<NotificationEntity>? notifications,
    RewardsEntity? rewards,
    User? user,
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return SettingsState(
      addresses: addresses ?? this.addresses,
      coupons: coupons ?? this.coupons,
      notifications: notifications ?? this.notifications,
      rewards: rewards ?? this.rewards,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}
