import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/result/result.dart';
import 'package:reem/features/settings/domain/entities/notification_entity.dart';
import 'package:reem/features/settings/domain/usecases/get_notifications_usecase.dart';
import 'package:reem/features/settings/domain/usecases/mark_notifications_read_usecase.dart';
import 'package:reem/features/settings/presentation/providers/notification_inbox_state.dart';

/// Everything the customer has been told, and whether she has read it.
///
/// The list was already being fetched — into `SettingsState.notifications`,
/// where nothing ever rendered it. Every entrance the app offers (the bell on
/// home, the summary card, the Activity hub, the Settings row) opened the
/// *preferences* screen instead, so twelve unread notices were unreachable.
/// This holds the inbox itself.
class NotificationInboxNotifier extends StateNotifier<NotificationInboxState> {
  NotificationInboxNotifier({
    required GetNotificationsUseCase getNotifications,
    required MarkNotificationReadUseCase markRead,
    required MarkAllNotificationsReadUseCase markAllRead,
  })  : _getNotifications = getNotifications,
        _markRead = markRead,
        _markAllRead = markAllRead,
        super(const NotificationInboxState());

  final GetNotificationsUseCase _getNotifications;
  final MarkNotificationReadUseCase _markRead;
  final MarkAllNotificationsReadUseCase _markAllRead;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    switch (await _getNotifications()) {
      case Success(:final data):
        state = state.copyWith(isLoading: false, items: data, clearError: true);
      case Error(:final failure):
        state = state.copyWith(isLoading: false, error: failure.message);
    }
  }

  /// Marks one read. The row flips first and is put back if the server
  /// refuses — tapping a notification should never feel like it hung.
  Future<void> markRead(NotificationEntity notification) async {
    if (notification.isRead) return;
    final before = state.items;
    state = state.copyWith(items: _replace(before, notification.id, true));

    if (await _markRead(notification.id) case Error()) {
      state = state.copyWith(items: before);
    }
  }

  Future<bool> markAllRead() async {
    if (state.unreadCount == 0) return true;
    final before = state.items;
    state = state.copyWith(
      items: [for (final n in before) n.copyWith(isRead: true)],
    );

    if (await _markAllRead() case Error(:final failure)) {
      state = state.copyWith(items: before, error: failure.message);
      return false;
    }
    return true;
  }

  static List<NotificationEntity> _replace(
    List<NotificationEntity> items,
    String id,
    bool isRead,
  ) {
    return [
      for (final item in items)
        item.id == id ? item.copyWith(isRead: isRead) : item,
    ];
  }
}
