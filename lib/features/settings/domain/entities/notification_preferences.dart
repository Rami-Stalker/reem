import 'package:equatable/equatable.dart';

/// What she has agreed to hear about, and through which door.
///
/// Two axes, not one, and the distinction matters on every screen that renders
/// this. [push], [email] and [sms] are *transports* — how a message leaves the
/// platform. The `inApp*` flags are *subjects* — which kinds of thing are worth
/// a message at all. Muting a subject silences it everywhere; turning off a
/// transport silences that door and leaves the notification in her inbox.
///
/// Three subjects were missing from the client entirely — rooms, social and
/// moderation — while the server had columns for them, a default, and code
/// that honoured them. The toggles simply had nowhere to be set from, so a
/// woman tired of "someone voted in your room" had no way to say so.
class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    required this.inAppPosts,
    required this.inAppStories,
    required this.inAppOrders,
    required this.inAppCoupons,
    required this.inAppRooms,
    required this.inAppSocial,
    required this.inAppModeration,
    required this.push,
    required this.email,
    required this.sms,
  });

  final bool inAppPosts;
  final bool inAppStories;
  final bool inAppOrders;
  final bool inAppCoupons;

  /// Activity in a shopping room she belongs to.
  final bool inAppRooms;

  /// Likes, comments, reshares, new followers.
  final bool inAppSocial;

  /// The softer half of moderation — a reinstatement, a report resolved in her
  /// favour. A takedown notice ignores this and always reaches her: a woman who
  /// muted likes has muted likes, not the news that her page has changed.
  final bool inAppModeration;

  final bool push;
  final bool email;
  final bool sms;

  NotificationPreferences copyWith({
    bool? inAppPosts,
    bool? inAppStories,
    bool? inAppOrders,
    bool? inAppCoupons,
    bool? inAppRooms,
    bool? inAppSocial,
    bool? inAppModeration,
    bool? push,
    bool? email,
    bool? sms,
  }) {
    return NotificationPreferences(
      inAppPosts: inAppPosts ?? this.inAppPosts,
      inAppStories: inAppStories ?? this.inAppStories,
      inAppOrders: inAppOrders ?? this.inAppOrders,
      inAppCoupons: inAppCoupons ?? this.inAppCoupons,
      inAppRooms: inAppRooms ?? this.inAppRooms,
      inAppSocial: inAppSocial ?? this.inAppSocial,
      inAppModeration: inAppModeration ?? this.inAppModeration,
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
        inAppRooms,
        inAppSocial,
        inAppModeration,
        push,
        email,
        sms,
      ];
}
