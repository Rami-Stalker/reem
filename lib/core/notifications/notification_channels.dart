import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The drawers a notification can land in on her phone.
///
/// This file is one half of a contract; the other half is
/// `backend/src/modules/notifications/notification-routing.ts`. The two have to
/// agree literally, character for character, because of how Android behaves
/// when they do not: since Android 8 the system **silently discards** a
/// notification naming a channel the device has not created. Not an error, not
/// a log line — the push arrives, the system drops it, and the only symptom is
/// a woman who says she never gets notified while the server's delivery table
/// says SENT.
///
/// So the channels are created at startup, before any push can arrive, and
/// their ids are named constants on both sides rather than string literals.
///
/// ## Why seven and not one
///
/// Because a channel is the unit Android gives *her* to control. One channel
/// means the only choice available is all or nothing, and the woman who is
/// tired of "a shop you follow posted something" turns off the one switch
/// there is — which also silences the message from a seller she is waiting on
/// and the news that her parcel is downstairs. Seven channels mean she can mute
/// the noise and keep the rest, which is the difference between an app she
/// tunes and an app she mutes.
///
/// The names and descriptions are Arabic because these strings are rendered by
/// the operating system in its own settings screens, where the app's
/// localisation does not reach. They are set once, at the moment the channel is
/// created, and Android will not let them be changed afterwards.
enum PushChannel {
  /// Her orders: paid, packed, shipped, out for delivery, delivered, refunded.
  /// The one she should never want to turn off, so it is first.
  orders(
    id: 'reem_orders',
    name: 'الطلبات',
    description: 'تحديثات طلباتك: الدفع، التجهيز، الشحن، والتسليم.',
    importance: Importance.max,
  ),

  /// Somebody wrote to her.
  messages(
    id: 'reem_messages',
    name: 'الرسائل',
    description: 'رسائل البائعات وردودهن على استفساراتك.',
    importance: Importance.max,
  ),

  /// Likes, comments, reshares, new followers.
  social(
    id: 'reem_social',
    name: 'التفاعلات',
    description: 'الإعجابات والتعليقات والمتابِعات الجديدة على منشوراتك.',
    importance: Importance.defaultImportance,
  ),

  /// Activity in a shopping room she is part of.
  rooms(
    id: 'reem_rooms',
    name: 'غرف التسوّق',
    description: 'ما يجري في الغرف اللي إنتِ فيها: اقتراحات، أصوات، وقرارات.',
    importance: Importance.defaultImportance,
  ),

  /// Coupons, drops, campaigns. The one she is likeliest to turn off, and it
  /// is deliberately the one whose muting costs her nothing she needs.
  offers(
    id: 'reem_offers',
    name: 'العروض والكوبونات',
    description: 'الكوبونات والتخفيضات والإطلاقات الجديدة.',
    importance: Importance.defaultImportance,
  ),

  /// Her salon appointments: requested, confirmed, cancelled, starting soon.
  ///
  /// Its own drawer rather than folded into [orders], because these are the
  /// one kind of notice that is useless a minute late — a woman who mutes
  /// order updates while she waits for a parcel must not thereby mute the
  /// reminder that she is due at the salon at six.
  appointments(
    id: 'reem_appointments',
    name: 'مواعيد الصالونات',
    description: 'تأكيد حجوزاتك وإلغاؤها وتذكيرك قبل موعدك.',
    importance: Importance.max,
  ),

  /// Moderation outcomes, security notices, everything the platform must say.
  system(
    id: 'reem_system',
    name: 'تنبيهات التطبيق',
    description: 'قرارات المراجعة، وتنبيهات الحساب والأمان.',
    importance: Importance.high,
  );

  const PushChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
  });

  /// Must match the backend's `PushChannel` constant exactly.
  final String id;
  final String name;
  final String description;

  /// `max` is what produces a heads-up banner over whatever she is doing.
  /// Spent only on the three kinds she is actually waiting for — her orders,
  /// her messages and her appointments — everything else appears in the shade
  /// without interrupting her.
  final Importance importance;

  /// The channel named by an incoming push, or [system] for one that names
  /// nothing the client knows — a server newer than this build.
  static PushChannel fromId(String? id) {
    for (final channel in PushChannel.values) {
      if (channel.id == id) return channel;
    }
    return PushChannel.system;
  }

  AndroidNotificationChannel get androidChannel => AndroidNotificationChannel(
        id,
        name,
        description: description,
        importance: importance,
        enableVibration: true,
        playSound: true,
      );
}
