import 'package:reem/features/settings/domain/entities/notification_entity.dart';

class NotificationInboxState {
  const NotificationInboxState({
    this.isLoading = false,
    this.items = const [],
    this.error,
  });

  final bool isLoading;
  final List<NotificationEntity> items;
  final String? error;

  int get unreadCount => items.where((n) => !n.isRead).length;
  bool get isEmpty => !isLoading && error == null && items.isEmpty;

  NotificationInboxState copyWith({
    bool? isLoading,
    List<NotificationEntity>? items,
    String? error,
    bool clearError = false,
  }) {
    return NotificationInboxState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
