import 'package:ohara/features/settings/domain/entities/notification_preferences.dart';

class NotificationPreferencesModel extends NotificationPreferences {
  const NotificationPreferencesModel({
    required super.inAppPosts,
    required super.inAppStories,
    required super.inAppOrders,
    required super.inAppCoupons,
    required super.inAppRooms,
    required super.inAppSocial,
    required super.inAppModeration,
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
      inAppRooms: json['in_app_rooms'] as bool? ?? true,
      inAppSocial: json['in_app_social'] as bool? ?? true,
      inAppModeration: json['in_app_moderation'] as bool? ?? true,
      // The one default that is off rather than on, and it agrees with the
      // server's column default deliberately: push is not something a platform
      // may assume. It becomes true the moment a handset registers a token,
      // which only happens after the operating system has asked her.
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
      'in_app_rooms': preferences.inAppRooms,
      'in_app_social': preferences.inAppSocial,
      'in_app_moderation': preferences.inAppModeration,
      'push': preferences.push,
      'email': preferences.email,
      'sms': preferences.sms,
    };
  }
}
