import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:reem/core/notifications/notification_channels.dart';
import 'package:reem/core/notifications/push_config.dart';
import 'package:reem/core/notifications/push_message.dart';
import 'package:reem/core/observability/error_report.dart';
import 'package:reem/core/observability/error_reporter.dart';

/// Whether the phone will show her anything.
enum PushPermission {
  /// She has never been asked. The prompt is still available.
  notDetermined,

  /// Yes.
  granted,

  /// Yes, but quietly — iOS "deliver quietly", or Android with the channel
  /// muted. Notifications arrive in the shade without a sound or a banner.
  provisional,

  /// No. And on both platforms this is final: the system prompt never appears
  /// again, so the only remaining route is the OS settings page.
  denied,

  /// Push is not available in this build at all — no Firebase project
  /// configured, or a platform with no push story.
  unavailable,
}

/// Receives a push that arrived while the app was running in the background of
/// the operating system, in a separate isolate with no access to anything this
/// app has in memory.
///
/// Registered because Firebase requires it before `onBackgroundMessage` can be
/// used at all, and kept deliberately empty of work. When a message carries a
/// `notification` block — every one Reem sends does — the system draws it
/// without consulting this at all, so there is nothing here that needs doing.
///
/// The annotation is not optional. Without it the tree-shaker removes this
/// function from a release build and the handler registration fails at
/// runtime, in release only, which is exactly the kind of bug that ships.
@pragma('vm:entry-point')
Future<void> reemBackgroundMessageHandler(RemoteMessage message) async {
  // A background isolate has its own memory: Firebase has to be initialised
  // again here or every SDK call in this function throws.
  try {
    await Firebase.initializeApp(options: PushConfig.options);
  } catch (_) {
    // Nothing to do. The system has already drawn the notification.
  }
}

/// Push notifications: the half of this app's notification system that reaches
/// a woman who is not looking at her phone.
///
/// ## What was here before
///
/// Nothing. The server collected device tokens through an endpoint no client
/// ever called, wrote delivery rows, and the app rendered an in-app inbox —
/// which is a record of things she was never told. The notifications with the
/// most reason to exist were precisely the ones that reached nobody: the whole
/// point of "your parcel is downstairs" is that she is not in the app when it
/// happens.
///
/// ## The four states a notification has to survive
///
/// This is the part that is easy to half-build, because three of the four look
/// fine in a debug session:
///
///  - **Foreground.** Neither platform draws anything; the app is told and is
///    expected to decide. Handled by [_onForegroundMessage], which draws it
///    with `flutter_local_notifications` so it looks identical to the other
///    three cases.
///  - **Background.** The system draws it. The app is woken on tap through
///    `onMessageOpenedApp`.
///  - **Terminated, tapped.** The app is launched cold by the tap, and the
///    message is waiting in `getInitialMessage()`. Missing this case is why so
///    many apps open their home screen when you tap a notification that was
///    sitting on the lock screen overnight — the routing information was read
///    before the router existed and thrown away.
///  - **Terminated, not tapped.** Nothing runs. The system drew it, which is
///    why the server always sends a `notification` block and never relies on
///    a data-only message.
///
/// ## Degrading to nothing, on purpose
///
/// Every entry point here is safe to call in a build with no Firebase project
/// configured. `initialize` gives up quietly, [permission] answers
/// `unavailable`, and registration is a no-op. That matters because a
/// developer running the app against a local API has no Firebase project, and
/// an app that will not start without one is an app nobody can work on.
class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? local,
  })  : _injectedMessaging = messaging,
        _injectedLocal = local;

  final FirebaseMessaging? _injectedMessaging;
  final FlutterLocalNotificationsPlugin? _injectedLocal;

  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _local;

  bool _initialized = false;
  bool _available = false;

  /// The message that launched the app from a cold start, held until somebody
  /// is ready to route it.
  ///
  /// This is the whole reason it is a field. The tap happens before the first
  /// frame, long before GoRouter exists; reading it and discarding it is what
  /// makes a notification open the home screen instead of the order it was
  /// about.
  PushMessage? _pendingLaunch;

  final StreamController<PushMessage> _opened =
      StreamController<PushMessage>.broadcast();
  final StreamController<PushMessage> _received =
      StreamController<PushMessage>.broadcast();
  final StreamController<String> _tokenRefreshed =
      StreamController<String>.broadcast();

  /// She tapped a notification. Carries the route to open.
  Stream<PushMessage> get onOpened => _opened.stream;

  /// One arrived while the app was in the foreground — for refreshing the
  /// inbox badge and whatever screen she is looking at.
  Stream<PushMessage> get onReceived => _received.stream;

  /// The provider reissued this device's address; it has to be re-registered.
  Stream<String> get onTokenRefreshed => _tokenRefreshed.stream;

  /// Whether push works in this build.
  bool get isAvailable => _available;

  /// Takes the cold-start message, once.
  ///
  /// Consuming it is the point: a second reader must not route her a second
  /// time, and rotating the device would otherwise replay the navigation.
  PushMessage? takePendingLaunch() {
    final pending = _pendingLaunch;
    _pendingLaunch = null;
    return pending;
  }

  /// Wires everything up. Safe to call more than once; safe to call in a build
  /// with no Firebase project.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!PushConfig.isSupportedPlatform) return;

    try {
      // `options` is null when this build was given no project, in which case
      // `initializeApp` falls back to google-services.json / the plist. Either
      // may be absent, which is what the catch is for.
      await Firebase.initializeApp(options: PushConfig.options);
    } catch (error) {
      // Not reported as a crash: a build without Firebase is a legitimate
      // configuration, not a failure, and a developer running against a local
      // API sees this every time.
      if (kDebugMode) {
        debugPrint('Push disabled — Firebase is not configured: $error');
      }
      return;
    }

    _messaging = _injectedMessaging ?? FirebaseMessaging.instance;
    _local = _injectedLocal ?? FlutterLocalNotificationsPlugin();

    try {
      await _createChannels();
      await _initializeLocalPlugin();

      FirebaseMessaging.onBackgroundMessage(reemBackgroundMessageHandler);
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromBackground);
      _messaging!.onTokenRefresh.listen(_tokenRefreshed.add);

      // iOS draws nothing in the foreground unless asked. Asked for the badge
      // and nothing else: the banner is drawn by the local plugin below, on
      // both platforms, so that one code path decides what a foreground
      // notification looks like instead of two that drift apart.
      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      // The cold-start case, captured before anything can ask for it.
      final launch = await _messaging!.getInitialMessage();
      if (launch != null) _pendingLaunch = PushMessage.from(launch);

      _available = true;
    } catch (error, stack) {
      ErrorReporter.report(
        error,
        stack,
        severity: ErrorSeverity.warning,
        context: 'push.initialize',
      );
    }
  }

  // ── Permission ───────────────────────────────────────────────────────────

  /// What the phone currently allows, without asking her anything.
  Future<PushPermission> permission() async {
    final messaging = _messaging;
    if (!_available || messaging == null) return PushPermission.unavailable;
    try {
      return _read(await messaging.getNotificationSettings());
    } catch (_) {
      return PushPermission.unavailable;
    }
  }

  /// Asks her.
  ///
  /// Worth being deliberate about *when* this is called, which is why it is
  /// not called from [initialize]: both platforms show this prompt once and
  /// once only, and a "no" is permanent — the system dialog never appears
  /// again. Asking on first launch, before she has any reason to want
  /// notifications, is how an app spends its one question and gets a no.
  ///
  /// On Android 13 and later this also requests `POST_NOTIFICATIONS`; on
  /// earlier versions it resolves immediately as granted.
  Future<PushPermission> request() async {
    final messaging = _messaging;
    if (!_available || messaging == null) return PushPermission.unavailable;
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        // No provisional authorisation. It sounds attractive — notifications
        // without asking — but it delivers them silently into the notification
        // centre, which for "your parcel is downstairs" is indistinguishable
        // from not sending it.
        provisional: false,
      );
      return _read(settings);
    } catch (error, stack) {
      ErrorReporter.report(
        error,
        stack,
        severity: ErrorSeverity.warning,
        context: 'push.request',
      );
      return PushPermission.denied;
    }
  }

  static PushPermission _read(NotificationSettings settings) {
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => PushPermission.granted,
      AuthorizationStatus.provisional => PushPermission.provisional,
      AuthorizationStatus.denied => PushPermission.denied,
      AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      // iOS 17 and later: she turned them off in Settings after granting.
      // Indistinguishable from a refusal as far as this app can act on it —
      // the system prompt will not appear again either way.
      _ => PushPermission.denied,
    };
  }

  // ── The address of this handset ──────────────────────────────────────────

  /// This device's push token, or null if there is not one to be had.
  ///
  /// On iOS this can legitimately return null for a while after launch: the
  /// FCM token is only issued once APNs has handed over a device token, which
  /// happens asynchronously and not at all in the simulator. A null here is
  /// not an error and must not be treated as one — the `onTokenRefresh`
  /// stream delivers it when it arrives.
  Future<String?> token() async {
    final messaging = _messaging;
    if (!_available || messaging == null) return null;
    try {
      return await messaging.getToken();
    } catch (error) {
      if (kDebugMode) debugPrint('Push token unavailable: $error');
      return null;
    }
  }

  /// Forgets this device's address locally.
  ///
  /// Called on sign-out, after the server has been told. The order matters:
  /// deleting first would leave the server holding a token it will keep
  /// pushing to, and the next woman to sign in on this handset would receive
  /// the previous one's notifications.
  Future<void> deleteToken() async {
    final messaging = _messaging;
    if (!_available || messaging == null) return;
    try {
      await messaging.deleteToken();
    } catch (error) {
      if (kDebugMode) debugPrint('Push token delete failed: $error');
    }
  }

  // ── Drawing one ──────────────────────────────────────────────────────────

  Future<void> _createChannels() async {
    final android = _local?.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    for (final channel in PushChannel.values) {
      await android.createNotificationChannel(channel.androidChannel);
    }
  }

  Future<void> _initializeLocalPlugin() async {
    await _local!.initialize(
      settings: const InitializationSettings(
        // `@mipmap/ic_launcher` is wrong here and is what most projects use:
        // Android draws the small icon as a silhouette, so a full-colour
        // launcher icon renders as a white square. `ic_stat_reem` is a white
        // -on-transparent glyph; see `android/app/src/main/res/drawable`.
        android: AndroidInitializationSettings('ic_stat_reem'),
        iOS: DarwinInitializationSettings(
          // Permission is requested through firebase_messaging, once, at the
          // moment she opts in — not here, at startup, where it would spend
          // the app's one prompt before she has any reason to say yes.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );
  }

  /// A push arrived while she is looking at the app.
  ///
  /// Drawn rather than swallowed. The tempting alternative — show an in-app
  /// banner instead — loses the one thing that matters when she switches away
  /// two seconds later: a real notification stays in the shade, and an in-app
  /// banner does not.
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final push = PushMessage.from(message);
    _received.add(push);

    if (push.body.isEmpty && push.title.isEmpty) return;

    final channel = push.channel;
    try {
      await _local?.show(
        id: push.localId,
        title: push.title,
        body: push.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: channel.importance,
            priority: Priority.high,
            // Same tag replaces rather than stacks, matching what the system
            // does for a push that arrives while the app is closed.
            tag: push.collapseKey,
            // Arabic bodies run long; without this they are truncated to one
            // line with no way to expand.
            styleInformation: BigTextStyleInformation(push.body),
          ),
          iOS: DarwinNotificationDetails(
            threadIdentifier: push.collapseKey,
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        // The whole payload, so a tap on this one routes exactly like a tap on
        // one the system drew.
        payload: push.deepLink,
      );
    } catch (error, stack) {
      ErrorReporter.report(
        error,
        stack,
        severity: ErrorSeverity.warning,
        context: 'push.foreground',
      );
    }
  }

  void _onOpenedFromBackground(RemoteMessage message) {
    _opened.add(PushMessage.from(message));
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    final link = response.payload;
    if (link == null || link.isEmpty) return;
    _opened.add(
      PushMessage(
        title: '',
        body: '',
        channel: PushChannel.system,
        deepLink: link,
        data: const {},
      ),
    );
  }

  Future<void> dispose() async {
    await _opened.close();
    await _received.close();
    await _tokenRefreshed.close();
  }
}
