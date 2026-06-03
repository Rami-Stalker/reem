import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/impl/settings_remote_datasource_impl.dart';
import '../../data/datasources/settings_remote_datasource.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/usecases/get_addresses_usecase.dart';
import '../../domain/usecases/get_coupons_usecase.dart';
import '../../domain/usecases/get_notifications_usecase.dart';
import '../../domain/usecases/get_rewards_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import 'settings_notifier.dart';
import 'settings_state.dart';

final settingsRemoteDataSourceProvider = Provider<SettingsRemoteDataSource>(
  (ref) => SettingsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(
    remote: ref.watch(settingsRemoteDataSourceProvider),
  ),
);

final getAddressesUseCaseProvider = Provider(
  (ref) => GetAddressesUseCase(ref.watch(settingsRepositoryProvider)),
);

final getCouponsUseCaseProvider = Provider(
  (ref) => GetCouponsUseCase(ref.watch(settingsRepositoryProvider)),
);

final getNotificationsUseCaseProvider = Provider(
  (ref) => GetNotificationsUseCase(ref.watch(settingsRepositoryProvider)),
);

final updateProfileUseCaseProvider = Provider(
  (ref) => UpdateProfileUseCase(ref.watch(settingsRepositoryProvider)),
);

final getRewardsUseCaseProvider = Provider(
  (ref) => GetRewardsUseCase(ref.watch(settingsRepositoryProvider)),
);

final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(
    getAddressesUseCase: ref.watch(getAddressesUseCaseProvider),
    getCouponsUseCase: ref.watch(getCouponsUseCaseProvider),
    getNotificationsUseCase: ref.watch(getNotificationsUseCaseProvider),
    getRewardsUseCase: ref.watch(getRewardsUseCaseProvider),
    updateProfileUseCase: ref.watch(updateProfileUseCaseProvider),
  );
});
