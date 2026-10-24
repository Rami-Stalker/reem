import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/settings/domain/entities/notification_preferences.dart';
import 'package:ohara/features/settings/domain/repositories/settings_repository.dart';

class GetNotificationPreferencesUseCase {
  const GetNotificationPreferencesUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<NotificationPreferences>> call() =>
      _repository.getNotificationPreferences();
}
