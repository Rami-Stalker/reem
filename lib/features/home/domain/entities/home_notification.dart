import 'package:equatable/equatable.dart';

/// The category of a notification — drives its icon + accent.
enum HomeNotificationKind { order, promo, social, system }

/// A single notification preview row inside the home summary card.
class HomeNotificationPreview extends Equatable {
  const HomeNotificationPreview({
    required this.id,
    required this.kind,
    required this.title,
    required this.timeAgo,
    this.unread = true,
  });

  final String id;
  final HomeNotificationKind kind;
  final String title;
  final String timeAgo;
  final bool unread;

  @override
  List<Object?> get props => [id, kind, title, timeAgo, unread];
}

/// A compact, glanceable summary of the notifications centre for the home page.
class NotificationSummary extends Equatable {
  const NotificationSummary({
    this.unreadCount = 0,
    this.previews = const [],
  });

  final int unreadCount;
  final List<HomeNotificationPreview> previews;

  bool get hasUnread => unreadCount > 0;

  @override
  List<Object?> get props => [unreadCount, previews];
}
