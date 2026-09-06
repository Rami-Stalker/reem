import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/settings/data/datasources/impl/settings_remote_datasource_impl.dart';
import 'package:reem/features/settings/data/datasources/settings_remote_datasource.dart';
import 'package:reem/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:reem/features/settings/domain/entities/notification_preferences.dart';
import 'package:reem/features/settings/domain/repositories/settings_repository.dart';
import 'package:reem/features/settings/domain/usecases/get_addresses_usecase.dart';
import 'package:reem/features/settings/domain/usecases/get_coupons_usecase.dart';
import 'package:reem/features/settings/domain/usecases/get_notification_preferences_usecase.dart';
import 'package:reem/features/settings/domain/usecases/get_notifications_usecase.dart';
import 'package:reem/features/settings/domain/usecases/get_rewards_usecase.dart';
import 'package:reem/features/settings/domain/usecases/mark_notifications_read_usecase.dart';
import 'package:reem/features/settings/domain/usecases/update_notification_preferences_usecase.dart';
import 'package:reem/features/settings/domain/usecases/update_profile_usecase.dart';
import 'package:reem/features/settings/presentation/providers/notification_inbox_notifier.dart';
import 'package:reem/features/settings/presentation/providers/notification_inbox_state.dart';
import 'package:reem/features/settings/presentation/providers/settings_notifier.dart';
import 'package:reem/features/settings/presentation/providers/settings_state.dart';

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

final getNotificationPreferencesUseCaseProvider = Provider(
  (ref) =>
      GetNotificationPreferencesUseCase(ref.watch(settingsRepositoryProvider)),
);

final updateNotificationPreferencesUseCaseProvider = Provider(
  (ref) => UpdateNotificationPreferencesUseCase(
    ref.watch(settingsRepositoryProvider),
  ),
);

final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences>((ref) async {
  final result = await ref.watch(getNotificationPreferencesUseCaseProvider)();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw Exception(failure.message),
  };
});

final markNotificationReadUseCaseProvider = Provider(
  (ref) => MarkNotificationReadUseCase(ref.watch(settingsRepositoryProvider)),
);

final markAllNotificationsReadUseCaseProvider = Provider(
  (ref) =>
      MarkAllNotificationsReadUseCase(ref.watch(settingsRepositoryProvider)),
);

/// The customer's notification inbox. App-wide rather than auto-disposed so
/// the unread badge on the home bell and the list agree with each other.
final notificationInboxProvider =
    StateNotifierProvider<NotificationInboxNotifier, NotificationInboxState>((
      ref,
    ) {
      return NotificationInboxNotifier(
        getNotifications: ref.watch(getNotificationsUseCaseProvider),
        markRead: ref.watch(markNotificationReadUseCaseProvider),
        markAllRead: ref.watch(markAllNotificationsReadUseCaseProvider),
      )..load();
    });

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
