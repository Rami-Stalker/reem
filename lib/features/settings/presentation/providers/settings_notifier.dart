import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/settings/domain/usecases/get_addresses_usecase.dart';
import 'package:ohara/features/settings/domain/usecases/get_coupons_usecase.dart';
import 'package:ohara/features/settings/domain/usecases/get_notifications_usecase.dart';
import 'package:ohara/features/settings/domain/usecases/get_rewards_usecase.dart';
import 'package:ohara/features/settings/domain/usecases/update_profile_usecase.dart';
import 'package:ohara/features/settings/presentation/providers/settings_message.dart';
import 'package:ohara/features/settings/presentation/providers/settings_state.dart';

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier({
    required GetAddressesUseCase getAddressesUseCase,
    required GetCouponsUseCase getCouponsUseCase,
    required GetNotificationsUseCase getNotificationsUseCase,
    required GetRewardsUseCase getRewardsUseCase,
    required UpdateProfileUseCase updateProfileUseCase,
  })  : _getAddresses = getAddressesUseCase,
        _getCoupons = getCouponsUseCase,
        _getNotifications = getNotificationsUseCase,
        _getRewards = getRewardsUseCase,
        _updateProfile = updateProfileUseCase,
        super(const SettingsState());

  final GetAddressesUseCase _getAddresses;
  final GetCouponsUseCase _getCoupons;
  final GetNotificationsUseCase _getNotifications;
  final GetRewardsUseCase _getRewards;
  final UpdateProfileUseCase _updateProfile;

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final addressesResult = await _getAddresses();
    final couponsResult = await _getCoupons();
    final notificationsResult = await _getNotifications();
    final rewardsResult = await _getRewards();

    String? error;

    switch (addressesResult) {
      case Success(:final data):
        state = state.copyWith(addresses: data);
      case Error(:final failure):
        error = failure.message;
    }

    switch (couponsResult) {
      case Success(:final data):
        state = state.copyWith(coupons: data);
      case Error(:final failure):
        error ??= failure.message;
    }

    switch (notificationsResult) {
      case Success(:final data):
        state = state.copyWith(notifications: data);
      case Error(:final failure):
        error ??= failure.message;
    }

    switch (rewardsResult) {
      case Success(:final data):
        state = state.copyWith(rewards: data);
      case Error(:final failure):
        error ??= failure.message;
    }

    state = state.copyWith(isLoading: false, error: error);
  }

  Future<bool> updateProfile({
    String? name,
    String? bio,
    String? imageUrl,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _updateProfile(
      name: name,
      bio: bio,
      imageUrl: imageUrl,
    );
    return switch (result) {
      Success(:final data) => () {
          state = state.copyWith(
            isLoading: false,
            user: data,
            successMessage: SettingsMessage.profileUpdated,
          );
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isLoading: false, error: failure.message);
          return false;
        }(),
    };
  }
}
