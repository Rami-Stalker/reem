import 'package:reem/core/result/result.dart';

import '../entities/notification_entity.dart';
import '../repositories/settings_repository.dart';

class GetNotificationsUseCase {
  const GetNotificationsUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<List<NotificationEntity>>> call() =>
      _repository.getNotifications();
}
