import 'package:ohara/features/settings/domain/entities/notification_entity.dart';

class NotificationSettingsModel extends NotificationEntity {
  const NotificationSettingsModel({
    required super.id,
    required super.title,
    required super.body,
    required super.type,
    required super.isRead,
    required super.createdAt,
    super.imageUrl,
    super.data,
  });

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return NotificationSettingsModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      type: NotificationEntityType.fromWire(json['type'] as String?),
      isRead: json['is_read'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      imageUrl: json['image_url'] as String?,
      data: data is Map ? Map<String, dynamic>.from(data) : const {},
    );
  }
}
