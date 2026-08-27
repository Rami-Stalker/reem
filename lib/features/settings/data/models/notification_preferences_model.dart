import '../../domain/entities/notification_preferences.dart';

class NotificationPreferencesModel extends NotificationPreferences {
  const NotificationPreferencesModel({
    required super.inAppPosts,
    required super.inAppStories,
    required super.inAppOrders,
    required super.inAppCoupons,
    required super.push,
    required super.email,
    required super.sms,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      inAppPosts: json['in_app_posts'] as bool? ?? true,
      inAppStories: json['in_app_stories'] as bool? ?? true,
      inAppOrders: json['in_app_orders'] as bool? ?? true,
      inAppCoupons: json['in_app_coupons'] as bool? ?? true,
      push: json['push'] as bool? ?? false,
      email: json['email'] as bool? ?? false,
      sms: json['sms'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> toJson(NotificationPreferences preferences) {
    return {
      'in_app_posts': preferences.inAppPosts,
      'in_app_stories': preferences.inAppStories,
      'in_app_orders': preferences.inAppOrders,
      'in_app_coupons': preferences.inAppCoupons,
      'push': preferences.push,
      'email': preferences.email,
      'sms': preferences.sms,
    };
  }
}
