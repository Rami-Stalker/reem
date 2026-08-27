import 'package:reem/core/result/result.dart';

import 'package:reem/features/settings/domain/entities/notification_entity.dart';
import 'package:reem/features/settings/domain/repositories/settings_repository.dart';

class GetNotificationsUseCase {
  const GetNotificationsUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<List<NotificationEntity>>> call() =>
      _repository.getNotifications();
}
