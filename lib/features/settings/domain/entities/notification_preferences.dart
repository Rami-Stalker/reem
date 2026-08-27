import 'package:equatable/equatable.dart';

class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    required this.inAppPosts,
    required this.inAppStories,
    required this.inAppOrders,
    required this.inAppCoupons,
    required this.push,
    required this.email,
    required this.sms,
  });

  final bool inAppPosts;
  final bool inAppStories;
  final bool inAppOrders;
  final bool inAppCoupons;
  final bool push;
  final bool email;
  final bool sms;

  NotificationPreferences copyWith({
    bool? inAppPosts,
    bool? inAppStories,
    bool? inAppOrders,
    bool? inAppCoupons,
    bool? push,
    bool? email,
    bool? sms,
  }) {
    return NotificationPreferences(
      inAppPosts: inAppPosts ?? this.inAppPosts,
      inAppStories: inAppStories ?? this.inAppStories,
      inAppOrders: inAppOrders ?? this.inAppOrders,
      inAppCoupons: inAppCoupons ?? this.inAppCoupons,
      push: push ?? this.push,
      email: email ?? this.email,
      sms: sms ?? this.sms,
    );
  }

  @override
  List<Object?> get props => [
        inAppPosts,
        inAppStories,
        inAppOrders,
        inAppCoupons,
        push,
        email,
        sms,
      ];
}
