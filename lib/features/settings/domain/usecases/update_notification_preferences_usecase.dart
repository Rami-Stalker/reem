import 'package:reem/core/result/result.dart';

import 'package:reem/features/settings/domain/entities/notification_preferences.dart';
import 'package:reem/features/settings/domain/repositories/settings_repository.dart';

class UpdateNotificationPreferencesUseCase {
  const UpdateNotificationPreferencesUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<NotificationPreferences>> call(
    NotificationPreferences preferences,
  ) {
    return _repository.updateNotificationPreferences(preferences);
  }
}
