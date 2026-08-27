import 'package:reem/features/settings/domain/entities/notification_entity.dart';

class NotificationSettingsModel extends NotificationEntity {
  const NotificationSettingsModel({
    required super.id,
    required super.title,
    required super.body,
    required super.type,
    required super.isRead,
    required super.createdAt,
  });

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    return NotificationSettingsModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      type: _mapType(json['type'] as String?),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  static NotificationEntityType _mapType(String? type) {
    switch (type) {
      case 'comment':
        return NotificationEntityType.comment;
      case 'follow':
        return NotificationEntityType.follow;
      case 'message':
        return NotificationEntityType.message;
      case 'order':
        return NotificationEntityType.order;
      case 'promo':
        return NotificationEntityType.promo;
      default:
        return NotificationEntityType.like;
    }
  }
}
