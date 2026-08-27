import 'package:reem/core/result/result.dart';

import '../entities/notification_preferences.dart';
import '../repositories/settings_repository.dart';

class GetNotificationPreferencesUseCase {
  const GetNotificationPreferencesUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<NotificationPreferences>> call() =>
      _repository.getNotificationPreferences();
}
