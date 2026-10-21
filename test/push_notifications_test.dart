import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/notifications/notification_channels.dart';
import 'package:reem/core/notifications/push_message.dart';
import 'package:reem/core/router/app_router_provider.dart';

/// The client half of push, tested where it can be tested without a handset.
///
/// What these cover is the seam: a payload composed by the API, read by this
/// app, folded into a route this app's router recognises. Every failure here
/// is one that looks perfect on the server — the delivery row says SENT, the
/// notification appears on the phone — and then does the wrong thing when she
/// taps it. The server's own half is covered by
/// `backend/src/modules/notifications/push-delivery.spec.ts`; these two files
/// are the two sides of the same contract and are meant to be read together.

/// A message shaped exactly as `notification-routing.ts` composes one.
RemoteMessage serverMessage({
  required String type,
  required String deepLink,
  required String channelId,
  String? collapseKey,
  Map<String, String> extra = const {},
}) {
  return RemoteMessage(
    notification: const RemoteNotification(
      title: 'طلبك بالطريق',
      body: 'صار بالطريق إلك',
    ),
    collapseKey: collapseKey,
    data: {
      'type': type,
      'deep_link': deepLink,
      'channel_id': channelId,
      'title': 'طلبك بالطريق',
      'body': 'صار بالطريق إلك',
      ...extra,
    },
  );
}

void main() {
  group('reading what the server sent', () {
    test('the visible sentence and the route both survive', () {
      final push = PushMessage.from(
        serverMessage(
          type: 'order',
          deepLink: 'reem://order/o-1',
          channelId: 'reem_orders',
        ),
      );

      expect(push.title, 'طلبك بالطريق');
      expect(push.body, 'صار بالطريق إلك');
      expect(push.type, 'order');
      expect(push.deepLink, 'reem://order/o-1');
      expect(push.channel, PushChannel.orders);
    });

    test('a data-only message is still readable', () {
      // iOS does not hand the app the `notification` block when a terminated
      // app is opened by a tap, which is why the server duplicates the
      // sentence into `data`. This is that case.
      final push = PushMessage.from(
        RemoteMessage(
          data: const {
            'type': 'message',
            'title': 'رسالة جديدة',
            'body': 'وصلتك رسالة',
            'deep_link': 'reem://chat-details?id=c-1',
            'channel_id': 'reem_messages',
          },
        ),
      );

      expect(push.title, 'رسالة جديدة');
      expect(push.body, 'وصلتك رسالة');
      expect(push.channel, PushChannel.messages);
    });

    test('a channel this build has never heard of is not dropped', () {
      // The server may be newer than the app on her phone. A notification it
      // sends must still be shown, in the fallback drawer, rather than
      // discarded because a string did not match.
      final push = PushMessage.from(
        RemoteMessage(data: const {'channel_id': 'reem_something_new'}),
      );

      expect(push.channel, PushChannel.system);
    });

    test('an empty message still has a title to draw', () {
      final push = PushMessage.from(const RemoteMessage(data: {}));

      expect(push.title, isNotEmpty);
      expect(push.deepLink, isNull);
    });
  });

  group('what replaces what in the shade', () {
    test('two notifications about the same thing share a local id', () {
      final first = PushMessage.from(
        serverMessage(
          type: 'order',
          deepLink: 'reem://order/o-1',
          channelId: 'reem_orders',
          collapseKey: 'order-o-1',
        ),
      );
      final second = PushMessage.from(
        serverMessage(
          type: 'order',
          deepLink: 'reem://order/o-1',
          channelId: 'reem_orders',
          collapseKey: 'order-o-1',
        ),
      );

      // Same id means the second replaces the first, so "paid / packed /
      // shipped" is one line about one order rather than three.
      expect(first.localId, second.localId);
      expect(first.localId, greaterThanOrEqualTo(0));
    });

    test('notifications about different things do not', () {
      final a = PushMessage.from(
        serverMessage(
          type: 'order',
          deepLink: 'reem://order/o-1',
          channelId: 'reem_orders',
          collapseKey: 'order-o-1',
        ),
      );
      final b = PushMessage.from(
        serverMessage(
          type: 'order',
          deepLink: 'reem://order/o-2',
          channelId: 'reem_orders',
          collapseKey: 'order-o-2',
        ),
      );

      expect(a.localId, isNot(b.localId));
    });

    test('an uncollapsible notification stacks rather than replacing', () {
      // A coupon and a new follower are each one of a kind.
      final push = PushMessage.from(
        serverMessage(
          type: 'coupon',
          deepLink: 'reem://coupons',
          channelId: 'reem_offers',
        ),
      );

      expect(push.collapseKey, isNull);
      expect(push.localId, greaterThanOrEqualTo(0));
    });
  });

  group('where a tap lands', () {
    test('every link the server composes folds into a real route', () {
      // The left column is exactly what `deepLinkFor` produces; the right is
      // a `RoutePaths` entry. A mismatch is a notification that arrives
      // perfectly and then drops her on the 404 page.
      const cases = <String, String>{
        'reem://order/o-1': '/order/o-1',
        'reem://orders': '/orders',
        'reem://chat-details?id=c-1': '/chat-details?id=c-1',
        'reem://chats': '/chats',
        'reem://content/x-1': '/content/x-1',
        'reem://user/u-1': '/user/u-1',
        'reem://rooms/r-1': '/rooms/r-1',
        'reem://coupons': '/coupons',
        'reem://notifications': '/notifications',
        'reem://home': '/home',
        'reem://market/drops': '/market/drops',
      };

      for (final entry in cases.entries) {
        expect(
          deepLinkPath(Uri.parse(entry.key)),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('a chat link keeps its query parameter', () {
      // The route reads the id off the query string, not a path segment, so
      // losing it here would open an empty conversation.
      final path = deepLinkPath(Uri.parse('reem://chat-details?id=c-1'));

      expect(Uri.parse(path!).queryParameters['id'], 'c-1');
    });
  });

  group('the channels', () {
    test('every channel id matches the one the server sends', () {
      // These strings are a contract with `notification-routing.ts`. Android
      // silently discards a notification naming a channel the device has not
      // created, so a drift here is invisible from the server: the delivery
      // row says SENT and the phone shows nothing.
      expect(
        PushChannel.values.map((channel) => channel.id).toList(),
        const [
          'reem_orders',
          'reem_messages',
          'reem_social',
          'reem_rooms',
          'reem_offers',
          'reem_appointments',
          'reem_system',
        ],
      );
    });

    test('every channel is named and described for the system settings', () {
      // Rendered by the operating system, where the app's localisation does
      // not reach, and unchangeable once the channel has been created.
      for (final channel in PushChannel.values) {
        expect(channel.name, isNotEmpty, reason: channel.id);
        expect(channel.description, isNotEmpty, reason: channel.id);
      }
    });
  });
}
