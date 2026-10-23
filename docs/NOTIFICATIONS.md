# Notifications

How Reem tells a woman something, and how that reaches her when the app is
closed.

---

## What this is

Reem has always had *notifications* in the sense of rows in a table. It did not
have notifications in the sense that matters: something that appears on a phone
whose owner is not looking at it. The server collected device tokens through an
endpoint no client ever called, stamped `PUSH` deliveries `SENT` without
anything leaving the building, and the app rendered an inbox — a record of
things she was never told.

The notifications with the most reason to exist were precisely the ones that
reached nobody. The whole point of *"your parcel is downstairs"* is that she is
not in the app when it happens.

This document is the map of the system that now does that.

---

## The shape of it

```
 something happens                                        her phone
 ─────────────────                                        ─────────
 order ships ─┐
 she is DM'd ─┤                    ┌─ Notification row ──► in-app inbox
 new follower ├─► NotificationsService
 room vote   ─┤       │            └─ NotificationDelivery(PUSH)
 campaign    ─┘       │                      │
                      │                      ▼
              ContactPolicyService     delivery worker
              (quiet hours, caps)            │
                                             ▼
                                       PushTransport
                                        ├── FcmTransport ──► FCM ──► APNs ─► iOS
                                        └── WebhookPush   ──► …    └──────► Android
```

Two writes, not one. The **in-app row is written first and directly**, because
the inbox is expected to be instantaneous and a push that fails must never take
the record with it. The **push is queued behind it** and, for anything she is
waiting for, sent in the same request rather than on the next minute boundary.

---

## Backend

| File | What it is |
|---|---|
| `notifications.service.ts` | The engine: event fan-out, the delivery worker, retries |
| `notification-routing.ts` | Channel, deep link, collapse key, TTL, urgency — per notification type |
| `contact-policy.service.ts` | Quiet hours and frequency caps. The one gate every marketing message passes |
| `transports/push.transport.ts` | The façade. Picks a backend, or honestly reports that there is none |
| `transports/fcm.transport.ts` | Firebase Cloud Messaging, HTTP v1 |
| `transports/webhook-push.transport.ts` | The fallback, for a provider contracted later |

### The three endings of a push

A delivery row never lies about what happened:

- **`SENT`** — at least one of her handsets took it.
- **`SKIPPED`** — there was nowhere to send it. No provider contracted, no
  registered device, every token dead. Nothing went wrong, so a retry would
  chase it for ever.
- **`QUEUED` again, later** — the provider was rate-limiting or broken.
  Exponential backoff from 30 seconds, up to `PUSH_MAX_ATTEMPTS` (5) attempts.
  This is the case that used to be lost outright: a ninety-second FCM outage
  permanently dropped every order-shipped message sent during it.

### Dead addresses are retired

FCM answering `UNREGISTERED`, `SENDER_ID_MISMATCH` or `400` means the app was
uninstalled or the token was rotated. The row is disabled, not retried. Three
*transient* failures in a row with no success between them retires it too —
some providers never say the word.

Without this the table only grows: every uninstall leaves behind an address
that is politely refused for ever, so reaching one woman's one phone gradually
costs four requests, three of them guaranteed to fail.

### Only signed-in handsets ring

Each push token is tied to the session that registered it (`push_tokens.session_id`),
and a push only goes to a token whose session is still `ACTIVE` on an account
that is not disabled (`liveTokenWhere`). So signing out, "sign out other
devices", removing a lost phone, an admin cutting sessions, and a session
expiring all stop that phone showing her messages, without each of those paths
having to remember the push table. Deleting the session deletes the token.
Tokens registered before this have no session and keep working until the app
re-registers them on its next launch.

### Each delivery is sent once

The minute cron and the inline send after a dispatch both read `QUEUED` rows.
Each row is claimed with a short lease on `next_attempt_at` before it is sent,
so two workers cannot push the same message twice, and a worker that dies
mid-send leaves the row to be retried when the lease runs out. A campaign runs
once: only `DRAFT` or `SCHEDULED` can become `RUNNING`, and the status route
cannot set `RUNNING` or `COMPLETED` by hand.

### Who may broadcast

Dispatch and campaigns (create, schedule, run) are `SUPER_ADMIN` and `ADMIN`
only. Support staff can read the analytics. A campaign's `deep_link` must be a
`reem://` link.

### Transactional or marketing

`NotificationCategory` is the whole basis of frequency capping, and it is not
decoration:

- **`TRANSACTIONAL`** — something happened to her. Never held for quiet hours,
  never counted against a cap, sent at high priority. Orders, messages, room
  activity, moderation outcomes.
- **`MARKETING`** — the platform wants something. Held between 22:00 and 09:00
  local, capped at one a day and three a week across *all* senders, sent at
  normal priority.

The cap is cumulative and invisible from any single sender. An abandoned-basket
reminder, a win-back, a price drop and a flash-sale announcement are each
defensible alone; four of them on one Tuesday is why she turns notifications
off.

---

## Client

| File | What it is |
|---|---|
| `lib/core/notifications/push_notification_service.dart` | The engine: init, permission, token, the four delivery states |
| `lib/core/notifications/push_coordinator.dart` | Wraps the app. Registration, tap routing, inbox refresh |
| `lib/core/notifications/notification_channels.dart` | The six Android channels. **Contract with the server** |
| `lib/core/notifications/push_config.dart` | Which Firebase project this build talks to |
| `lib/core/notifications/push_registration.dart` | Telling the server where this handset is |

### The four states a notification has to survive

Three of the four look fine in a debug session, which is why this is the part
that is usually half-built:

1. **Foreground.** Neither platform draws anything. The app is told and
   decides; Reem draws it with `flutter_local_notifications` so it looks
   identical to the other three.
2. **Background.** The system draws it. The app is woken on tap.
3. **Terminated, tapped.** The app is launched cold by the tap and the message
   is waiting in `getInitialMessage()` — before the router exists and before
   the session has been restored. It is *held* and flushed once auth settles.
   Reading it early and discarding it is why so many apps open their home
   screen when you tap a notification from the lock screen.
4. **Terminated, not tapped.** Nothing of ours runs. The system drew it, which
   is why the server always sends a `notification` block and never relies on a
   data-only message.

### The eight channels

A channel is the unit Android gives *her* to control. One channel means the
only choice is all or nothing, so the woman tired of "a shop you follow posted
something" turns off the one switch there is — silencing the message from a
seller she is waiting on and the news that her parcel is downstairs.

| id | Arabic | Importance |
|---|---|---|
| `reem_orders` | الطلبات | max — heads-up banner |
| `reem_messages` | الرسائل | max — heads-up banner |
| `reem_social` | التفاعلات | default |
| `reem_rooms` | غرف التسوّق | default |
| `reem_offers` | العروض والكوبونات | default |
| `reem_appointments` | مواعيد الصالونات | max — heads-up banner |
| `reem_occasions` | مناسباتي | high |
| `reem_system` | تنبيهات التطبيق | high |

**These ids are a contract.** Android **silently discards** a notification
naming a channel the device has not created — not an error, not a log line. The
delivery table says `SENT` and the phone shows nothing. `PushChannel` exists on
both sides for exactly this reason.

### Asking for permission

Not at launch. Both platforms show the system prompt **once**, and a refusal is
permanent — the dialog never appears again. Asking on first run, before she has
any reason to want notifications, is how an app spends its one question and
gets a no.

So the ask happens when she turns the switch on in
`/settings/notifications`, and a permanent refusal opens the OS settings page
rather than leaving a switch that silently does nothing.

---

## Setting it up

### 1. Firebase project

Create one (or three — local, staging, production). In it:

- Register an **Android** app with applicationId `shop.reem.app`. Download
  `google-services.json` into `android/app/`.
- Register an **iOS** app with the same bundle id. Download
  `GoogleService-Info.plist` into `ios/Runner/` and add it to the Runner target
  in Xcode.
- Under **Cloud Messaging → Apple app configuration**, upload an **APNs
  authentication key** (`.p8`) from the Apple Developer portal. Without it iOS
  pushes are accepted by FCM and never delivered.

Both config files are git-ignored: they name one specific project.

### 2. The API's credential

**Project settings → Service accounts → Generate new private key** downloads a
JSON file. Paste it whole into `FCM_SERVICE_ACCOUNT_JSON` (raw JSON on one
line, or base64 — both are accepted, because a dashboard's environment editor
and a shell disagree about newlines).

```
FCM_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"reem-prod",...}
PUSH_MAX_ATTEMPTS=5
```

Or the three fields separately: `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`,
`FCM_PRIVATE_KEY` (literal `\n` is normalised).

Note what is **not** here: a server key. The legacy `Authorization: key=`
credential and the `/fcm/send` endpoint it went to were decommissioned by
Google in June 2024 and answer 404 to everything — so a deployment could be
configured perfectly and still never ring a phone.

### 3. The app build

Android reads `google-services.json`; it genuinely needs the file rather than
only the defines, because the Firebase SDK's `ContentProvider` initialises the
default app from the generated resources *before any Dart runs* — which is the
case when a push arrives at a terminated app.

iOS can use either. Per-build configuration, when you want it:

```
flutter build apk --release --split-per-abi \
  --dart-define=APP_ENV=production \
  --dart-define=API_BASE_URL=https://reem-api.onrender.com \
  --dart-define=FIREBASE_PROJECT_ID=reem-prod \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=000000000000 \
  --dart-define=FIREBASE_ANDROID_API_KEY=AIza... \
  --dart-define=FIREBASE_ANDROID_APP_ID=1:000000000000:android:abc
```

### 4. Check it

```
GET /notifications/admin/analytics
```

Every `push` delivery `SKIPPED` with `No push provider configured` means step 2
did not take. `SKIPPED` with `No registered device` means the client never
registered — check that she granted the permission and that
`POST /notifications/push-tokens` is being called.

---

## Degrading to nothing, on purpose

Every path is safe with no Firebase project anywhere:

- The Android build logs one line and skips the google-services plugin.
- `PushNotificationService.initialize` gives up quietly; `isAvailable` is false.
- The API logs one warning at boot and records every push as `SKIPPED`.
- The in-app inbox, the preferences screen and everything else work unchanged.

A developer running against a local API has no Firebase project, and an app
that will not start without one is an app nobody can work on.

---

## Known gaps

- **Huawei handsets have no FCM.** `WebhookPushTransport` is the seam for
  contracting HMS or another provider; nothing is contracted today, and those
  customers get the in-app inbox only.
- **No notification-service extension on iOS.** `mutable-content` is set, so
  one can be added later to decorate a notification (a product thumbnail, a
  seller's avatar) without a server change.
- **Web push is not implemented.** `PushConfig.isSupportedPlatform` is Android
  and iOS; the desktop builds are a seller's console that is either open or not
  running.
