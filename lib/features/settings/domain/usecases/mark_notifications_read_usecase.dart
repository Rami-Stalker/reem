import 'package:reem/core/result/result.dart';

import 'package:reem/features/settings/domain/repositories/settings_repository.dart';

/// Marks one notification read.
class MarkNotificationReadUseCase {
  const MarkNotificationReadUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<void>> call(String id) => _repository.markNotificationRead(id);
}

/// Clears the whole unread badge in one call.
class MarkAllNotificationsReadUseCase {
  const MarkAllNotificationsReadUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<void>> call() => _repository.markAllNotificationsRead();
}
