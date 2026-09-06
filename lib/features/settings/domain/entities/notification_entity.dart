import 'package:equatable/equatable.dart';

/// The kinds of notification the server sends.
///
/// All eleven of them. The client used to know six and map everything else to
/// [like] by default, so a shipping update, a coupon, a story and a system
/// notice all arrived wearing a heart.
enum NotificationEntityType {
  like,
  comment,
  follow,
  message,
  order,
  payment,
  post,
  story,
  promo,
  coupon,

  /// Activity in a shopping room. Coalesced server-side, so one of these
  /// stands for an afternoon of votes rather than a single one.
  room,
  system;

  static NotificationEntityType fromWire(String? value) => switch (value) {
    'like' => NotificationEntityType.like,
    'comment' => NotificationEntityType.comment,
    'follow' => NotificationEntityType.follow,
    'message' => NotificationEntityType.message,
    'order' => NotificationEntityType.order,
    'payment' => NotificationEntityType.payment,
    'post' => NotificationEntityType.post,
    'story' => NotificationEntityType.story,
    'promo' => NotificationEntityType.promo,
    'coupon' => NotificationEntityType.coupon,
    'room' => NotificationEntityType.room,
    // Anything the server adds later reads as a plain notice rather than
    // silently borrowing another kind's icon.
    _ => NotificationEntityType.system,
  };
}

class NotificationEntity extends Equatable {
  const NotificationEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.imageUrl,
    this.data = const {},
  });

  final String id;
  final String title;
  final String body;
  final NotificationEntityType type;
  final bool isRead;
  final DateTime createdAt;

  /// Artwork the server attached, if any.
  final String? imageUrl;

  /// What the notification is about — `order_id`, `product_id`, `chat_id` and
  /// friends. It is what makes a notification tappable rather than a sentence.
  final Map<String, dynamic> data;

  NotificationEntity copyWith({bool? isRead}) => NotificationEntity(
    id: id,
    title: title,
    body: body,
    type: type,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    imageUrl: imageUrl,
    data: data,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    body,
    type,
    isRead,
    createdAt,
    imageUrl,
    data,
  ];
}
