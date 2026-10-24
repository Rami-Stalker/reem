import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/settings/domain/entities/notification_entity.dart';
import 'package:ohara/features/settings/domain/repositories/settings_repository.dart';

class GetNotificationsUseCase {
  const GetNotificationsUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<List<NotificationEntity>>> call() =>
      _repository.getNotifications();
}
