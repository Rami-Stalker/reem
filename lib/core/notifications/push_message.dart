import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:meta/meta.dart';

import 'package:reem/core/notifications/notification_channels.dart';

/// One push, as the client reads it.
///
/// Everything here comes out of the message's `data` map rather than its
/// `notification` block, and that is deliberate on both platforms: the
/// `notification` block is consumed by the operating system, and on iOS its
/// contents are not handed to the app at all when the woman taps a
/// notification that arrived while the app was terminated. A push whose
/// routing lives only in `notification` is one that shows up correctly and
/// then opens the home screen — the commonest bug in this whole area.
///
/// The server fills both halves; see `notification-routing.ts`.
@immutable
class PushMessage {
  const PushMessage({
    required this.title,
    required this.body,
    required this.channel,
    required this.data,
    this.deepLink,
    this.collapseKey,
  });

  /// Reads one out of Firebase's envelope.
  ///
  /// Tolerant by design: every field has a fallback, because this parses a
  /// payload composed by a server that may be newer than this build. A push
  /// with a type this client has never heard of must still be readable and
  /// still open *something*, rather than being dropped on the floor.
  factory PushMessage.from(RemoteMessage message) {
    final data = message.data.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );
    final notification = message.notification;

    return PushMessage(
      // The visible sentence is duplicated into `data` by the server precisely
      // so the foreground handler can draw it: a data-only message has no
      // `notification` block to read it from.
      title: notification?.title ?? _nonEmpty(data['title']) ?? 'ريم',
      body: notification?.body ?? _nonEmpty(data['body']) ?? '',
      channel: PushChannel.fromId(data['channel_id']),
      deepLink: _nonEmpty(data['deep_link']),
      collapseKey: _nonEmpty(message.collapseKey),
      data: data,
    );
  }

  final String title;
  final String body;
  final PushChannel channel;

  /// `reem://order/abc` — the route to open when she taps it. Null for a
  /// notification that is only an announcement.
  final String? deepLink;

  /// What this replaces in the shade. Reused as the local notification's id so
  /// that a foreground redraw replaces rather than stacks, exactly as the
  /// system does for one that arrives while the app is closed.
  final String? collapseKey;

  final Map<String, String> data;

  /// The kind, as the server named it — `order`, `message`, `like`. Used to
  /// decide which parts of the app to refresh, never to decide whether to
  /// show it.
  String get type => data['type'] ?? 'system';

  /// A stable small integer for the local notification, derived from what this
  /// message collapses onto.
  ///
  /// Two pushes about the same order share an id and so replace each other;
  /// two about different orders do not. Falling back to the clock for an
  /// uncollapsible message is right — a coupon and a new follower are each
  /// one-of-a-kind and should stack.
  int get localId {
    final key = collapseKey ?? _nonEmpty(data['collapse_key']);
    if (key == null) {
      return DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    }
    // Java's string hash, kept positive. Deterministic across launches, which
    // `Object.hashCode` is not.
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (31 * hash + unit) & 0x7fffffff;
    }
    return hash;
  }

  static String? _nonEmpty(String? value) =>
      (value == null || value.isEmpty) ? null : value;

  @override
  String toString() => 'PushMessage($type -> $deepLink)';
}
