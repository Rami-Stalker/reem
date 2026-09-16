import assert from 'node:assert/strict';
import test from 'node:test';
import { ConfigService } from '@nestjs/config';
import { NotificationCategory, NotificationType } from '@prisma/client';
import { FcmTransport } from './transports/fcm.transport';
import { summarise } from './transports/push-message';
import {
  PushChannel,
  channelFor,
  collapseKeyFor,
  deepLinkFor,
  ttlFor,
  urgencyFor,
} from './notification-routing';

/**
 * The parts of push that can be wrong without anybody noticing.
 *
 * Everything here is a pure function over a plain object, and that is the
 * point: the failures these cover are invisible from the server. A push with
 * the wrong priority is accepted by FCM, recorded SENT, and never shown; a
 * deep link naming a route that does not exist is delivered perfectly and
 * drops whoever taps it on a 404. The only other way to catch either is to
 * hold a phone.
 */

/** A configured transport, without a real credential going anywhere. */
function transport(): FcmTransport {
  const config = {
    get: (key: string) =>
      ({
        'push.fcm.projectId': 'reem-test',
        'push.fcm.clientEmail': 'push@reem-test.iam.gserviceaccount.com',
        'push.fcm.privateKey': '-----BEGIN PRIVATE KEY-----\nnot-a-key\n-----END PRIVATE KEY-----',
      })[key],
  } as unknown as ConfigService;
  return new FcmTransport(config);
}

type Envelope = {
  message: {
    token: string;
    notification: { title: string; body: string };
    data: Record<string, string>;
    android?: {
      priority: string;
      ttl?: string;
      collapse_key?: string;
      notification: { channel_id?: string; tag?: string };
    };
    apns?: {
      headers: Record<string, string>;
      payload: { aps: Record<string, unknown> };
    };
  };
};

function build(overrides: Record<string, unknown> = {}): Envelope {
  return transport().buildMessage(
    { id: 'device-1', token: 'tok', platform: null },
    {
      devices: [],
      title: 'طلبك بالطريق',
      body: 'صار بالطريق إلك',
      channelId: PushChannel.Orders,
      deepLink: 'reem://order/o-1',
      ...overrides,
    },
  ) as Envelope;
}

// ── The envelope ───────────────────────────────────────────────────────────

test('a push wakes a dozing phone on both platforms', () => {
  const { message } = build();

  // The only thing that delivers to a device in Doze. Without it the
  // notification arrives when she next unlocks — by which point she has
  // already opened the app and the notification was pointless.
  assert.equal(message.android?.priority, 'HIGH');
  // iOS silently declines to display an alert pushed at priority 5, and since
  // iOS 13 rejects outright a push carrying no apns-push-type.
  assert.equal(message.apns?.headers['apns-priority'], '10');
  assert.equal(message.apns?.headers['apns-push-type'], 'alert');
});

test('a marketing push does not claim urgency', () => {
  // Android meters senders that mark everything urgent and deprioritises
  // them, so spending the budget on promotions costs delivery of the order
  // updates — the trade nobody notices making.
  const { message } = build({ urgent: false });

  assert.equal(message.android?.priority, 'NORMAL');
  assert.equal(message.apns?.headers['apns-priority'], '5');
});

test('the channel travels, or Android drops the notification', () => {
  const { message } = build();

  // Android 8+ discards a notification naming a channel the device has not
  // created. Not an error, not a log line: the delivery row says SENT and the
  // phone shows nothing.
  assert.equal(message.android?.notification.channel_id, PushChannel.Orders);
  assert.equal(message.data.channel_id, PushChannel.Orders);
});

test('the tap destination rides in data, not only in the notification block', () => {
  const { message } = build();

  // A `notification` block alone is drawn by the operating system and hands
  // the app nothing to act on. The route has to be in `data` to survive.
  assert.equal(message.data.deep_link, 'reem://order/o-1');
  // And the sentence too, so a foreground handler renders the same words the
  // system would have drawn rather than guessing them.
  assert.equal(message.data.title, 'طلبك بالطريق');
});

test('data values are strings, which is the only shape FCM accepts', () => {
  const { message } = build({ data: { unread: 4, orderId: 'o-1' } });

  assert.equal(message.data.unread, '4');
  assert.equal(message.data.orderId, 'o-1');
  for (const value of Object.values(message.data)) {
    assert.equal(typeof value, 'string');
  }
});

test('a collapse key replaces rather than stacks, on both platforms', () => {
  const { message } = build({ collapseKey: 'chat-c1' });

  assert.equal(message.android?.collapse_key, 'chat-c1');
  // The tag is the half that governs the shade; collapse_key only governs
  // what FCM holds while the device is offline.
  assert.equal(message.android?.notification.tag, 'chat-c1');
  assert.equal(message.apns?.headers['apns-collapse-id'], 'chat-c1');
  assert.equal(message.apns?.payload.aps['thread-id'], 'chat-c1');
});

test('an iOS token is not sent an Android block, or the reverse', () => {
  const ios = transport().buildMessage(
    { id: 'd', token: 't', platform: 'ios' },
    { devices: [], title: 't', body: 'b' },
  ) as Envelope;
  const android = transport().buildMessage(
    { id: 'd', token: 't', platform: 'android' },
    { devices: [], title: 't', body: 'b' },
  ) as Envelope;

  assert.equal(ios.message.android, undefined);
  assert.ok(ios.message.apns);
  assert.equal(android.message.apns, undefined);
  assert.ok(android.message.android);
});

test('a ttl is set, because four weeks is FCM default and never right', () => {
  const { message } = build({ ttlSeconds: 3600 });

  assert.equal(message.android?.ttl, '3600s');
  const expiry = Number(message.apns?.headers['apns-expiration']);
  assert.ok(expiry > Math.floor(Date.now() / 1000));
});

// ── Reading a refusal ──────────────────────────────────────────────────────

test('a dead token is retired and never retried', () => {
  const unregistered = FcmTransport.classify(
    404,
    '{"error":{"details":[{"errorCode":"UNREGISTERED"}]}}',
  );

  assert.equal(unregistered.invalidToken, true);
  // A retry against an uninstalled app is a request that can never succeed,
  // repeated for ever.
  assert.notEqual(unregistered.retryable, true);
});

test("somebody else's project is a dead token here too", () => {
  const mismatch = FcmTransport.classify(
    403,
    '{"error":{"details":[{"errorCode":"SENDER_ID_MISMATCH"}]}}',
  );

  assert.equal(mismatch.invalidToken, true);
});

test('a provider having a bad minute does not unsubscribe her', () => {
  for (const status of [429, 500, 503]) {
    const outcome = FcmTransport.classify(status, '{}');
    assert.equal(outcome.retryable, true, `status ${status} should retry`);
    assert.notEqual(
      outcome.invalidToken,
      true,
      `status ${status} must not retire the token`,
    );
  }
});

test('a partial success is a success, with the failures on the record', () => {
  const outcome = summarise([
    { deviceId: 'a', ok: true, providerMessageId: 'm1' },
    { deviceId: 'b', ok: false, reason: 'FCM 404 UNREGISTERED', invalidToken: true },
  ]);

  // She got it on the phone in her hand.
  assert.equal(outcome.delivered, true);
  assert.equal(outcome.providerMessageId, 'm1');
  assert.match(outcome.reason ?? '', /1 of 2/);
});

test('every device dead is terminal; one flaky device is not', () => {
  const allDead = summarise([
    { deviceId: 'a', ok: false, reason: 'gone', invalidToken: true },
  ]);
  assert.equal(allDead.delivered, false);
  assert.notEqual(allDead.retryable, true);

  const flaky = summarise([
    { deviceId: 'a', ok: false, reason: 'FCM returned 503', retryable: true },
  ]);
  assert.equal(flaky.retryable, true);
});

// ── Where a tap lands ──────────────────────────────────────────────────────

test('every notification type opens a route the client actually has', () => {
  // The paths on the right are `RoutePaths` entries in the Flutter client.
  // A link matching no route is delivered perfectly and then 404s.
  const cases: [NotificationType, Record<string, unknown>, string][] = [
    ['order', { orderId: 'o-1' }, 'reem://order/o-1'],
    ['payment', { orderId: 'o-1' }, 'reem://order/o-1'],
    ['message', { chatId: 'c-1' }, 'reem://chat-details?id=c-1'],
    ['like', { contentId: 'x-1' }, 'reem://content/x-1'],
    ['comment', { content_id: 'x-1' }, 'reem://content/x-1'],
    ['follow', { followerId: 'u-1' }, 'reem://user/u-1'],
    ['room', { room_id: 'r-1' }, 'reem://rooms/r-1'],
    ['coupon', {}, 'reem://coupons'],
    ['system', {}, 'reem://notifications'],
  ];

  for (const [type, data, expected] of cases) {
    assert.equal(deepLinkFor(type, data), expected, `${type} deep link`);
  }
});

test('a notification missing its id still opens something readable', () => {
  // The fallback is the point: a notification that opens *something* worked.
  assert.equal(deepLinkFor(NotificationType.order, {}), 'reem://orders');
  assert.equal(deepLinkFor(NotificationType.message, {}), 'reem://chats');
  assert.equal(deepLinkFor(NotificationType.like, null), 'reem://notifications');
});

test("a campaign cannot smuggle a link out of the app's scheme", () => {
  // An operator typing a destination is caught here rather than on a phone.
  assert.equal(
    deepLinkFor(NotificationType.promo, { deep_link: 'https://example.com' }),
    'reem://home',
  );
  assert.equal(
    deepLinkFor(NotificationType.promo, { deep_link: 'reem://market/drops' }),
    'reem://market/drops',
  );
});

test('notifications land in the drawer their kind belongs to', () => {
  assert.equal(channelFor(NotificationType.order), PushChannel.Orders);
  assert.equal(channelFor(NotificationType.message), PushChannel.Messages);
  assert.equal(channelFor(NotificationType.like), PushChannel.Social);
  assert.equal(channelFor(NotificationType.room), PushChannel.Rooms);
  assert.equal(channelFor(NotificationType.promo), PushChannel.Offers);
  assert.equal(channelFor(NotificationType.system), PushChannel.System);
});

test('activity on one thing collapses; unrelated things do not', () => {
  assert.equal(
    collapseKeyFor(NotificationType.like, { contentId: 'x-1' }),
    'content-x-1',
  );
  assert.notEqual(
    collapseKeyFor(NotificationType.like, { contentId: 'x-2' }),
    collapseKeyFor(NotificationType.like, { contentId: 'x-1' }),
  );
  // A coupon is one of a kind and must never replace another one.
  assert.equal(collapseKeyFor(NotificationType.coupon, {}), undefined);
  assert.equal(collapseKeyFor(NotificationType.follow, { followerId: 'u' }), undefined);
});

test('a message expires long before an order update does', () => {
  // A chat push delivered on Thursday about Monday is not late, it is wrong.
  assert.equal(ttlFor(NotificationType.message), 3600);
  assert.ok(ttlFor(NotificationType.order) > ttlFor(NotificationType.message));
  assert.ok(ttlFor(NotificationType.promo) < ttlFor(NotificationType.order));
});

test('what she is waiting for is urgent; what the platform wants is not', () => {
  assert.equal(urgencyFor(NotificationCategory.TRANSACTIONAL), true);
  assert.equal(urgencyFor(NotificationCategory.MARKETING), false);
});

// ── Configuration ──────────────────────────────────────────────────────────

test('no credential means not configured, never a silent no-op send', () => {
  const empty = new FcmTransport({ get: () => undefined } as unknown as ConfigService);

  assert.equal(empty.isConfigured(), false);
});

test('a service-account key pasted with literal backslash-n still works', () => {
  // The single commonest way this credential arrives broken: an environment
  // editor that will not accept a real newline.
  const config = {
    get: (key: string) =>
      key === 'push.fcm.serviceAccount'
        ? JSON.stringify({
            project_id: 'reem-test',
            client_email: 'push@reem-test.iam.gserviceaccount.com',
            private_key: '-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----',
          })
        : undefined,
  } as unknown as ConfigService;

  assert.equal(new FcmTransport(config).isConfigured(), true);
});

test('an unusable service account disables push rather than crashing boot', () => {
  const config = {
    get: (key: string) =>
      key === 'push.fcm.serviceAccount' ? 'not json at all' : undefined,
  } as unknown as ConfigService;

  assert.equal(new FcmTransport(config).isConfigured(), false);
});

test('a configured transport refuses a send with no devices', async () => {
  const outcome = await transport().send({
    devices: [],
    title: 't',
    body: 'b',
  });

  // A skip, not a failure: nothing went wrong, there was nowhere to send.
  assert.equal(outcome.delivered, false);
  assert.equal(outcome.reason, 'No registered device');
  assert.notEqual(outcome.retryable, true);
});
