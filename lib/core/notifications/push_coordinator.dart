import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/app/bootstrap.dart';
import 'package:ohara/core/notifications/push_message.dart';
import 'package:ohara/core/notifications/push_providers.dart';
import 'package:ohara/core/observability/error_reporter.dart';
import 'package:ohara/core/router/app_router_provider.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/providers/auth_state.dart';
import 'package:ohara/features/settings/presentation/providers/settings_provider.dart';

/// Everything that has to happen *around* a push, wrapped around the app.
///
/// A widget rather than a provider because two of its four jobs need the
/// widget lifecycle: it has to survive for as long as the app does, and it has
/// to be able to wait for the router before it navigates.
///
/// The four jobs:
///
///  1. **Start the push service**, once, at launch.
///  2. **Keep the server's idea of this handset current** — register on sign
///     in, unregister on sign out, re-register when the provider rotates the
///     token.
///  3. **Route a tap**, from all three of the states a tap can happen in.
///  4. **Refresh the inbox** when one arrives while she is looking at the app,
///     so the bell's unread badge does not disagree with her lock screen.
///
/// ## Why the cold start is held rather than acted on
///
/// A notification tapped from the lock screen launches the app, and the
/// message is waiting before the first frame is built — before the router
/// exists and long before the session has been restored from secure storage.
/// Navigating then would either throw or land on the auth guard's redirect and
/// be lost. So the message is held and flushed at the first moment auth has
/// settled, which is the earliest instant the destination can be decided
/// correctly.
class PushCoordinator extends ConsumerStatefulWidget {
  const PushCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PushCoordinator> createState() => _PushCoordinatorState();
}

class _PushCoordinatorState extends ConsumerState<PushCoordinator> {
  StreamSubscription<PushMessage>? _opened;
  StreamSubscription<PushMessage>? _received;
  ProviderSubscription<AuthState>? _auth;

  /// A tap that arrived before the app was ready to act on it.
  PushMessage? _deferred;
  bool _ready = false;

  /// Whether the signed-in account's handset is currently registered, so a
  /// rebuild of the auth state — which happens on every profile edit — does
  /// not re-send the token each time.
  String? _registeredFor;

  @override
  void initState() {
    super.initState();
    // After the first frame: `initialize` touches platform channels, and the
    // auth listener can fire synchronously, both of which are unsafe during a
    // widget's own construction.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  @override
  void dispose() {
    unawaited(_opened?.cancel());
    unawaited(_received?.cancel());
    _auth?.close();
    super.dispose();
  }

  Future<void> _start() async {
    final push = ref.read(pushServiceProvider);
    await push.initialize();
    if (!mounted) return;

    _opened = push.onOpened.listen(_handleTap);
    _received = push.onReceived.listen(_handleArrival);

    // Whatever launched the app, kept until the session has settled.
    _deferred = push.takePendingLaunch();

    _auth = ref.listenManual<AuthState>(
      authNotifierProvider,
      (previous, next) => _onAuthChanged(next),
      fireImmediately: true,
    );
  }

  // ── Keeping the server current ───────────────────────────────────────────

  void _onAuthChanged(AuthState state) {
    if (!state.isInitialized) return;

    // The session is known now, so a held tap can be routed to the screen it
    // actually belongs on rather than bounced off the auth guard.
    if (!_ready) {
      _ready = true;
      final deferred = _deferred;
      _deferred = null;
      if (deferred != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _navigate(deferred));
      }
    }

    final userId = state.user?.id;
    if (userId == null) {
      if (_registeredFor != null) {
        _registeredFor = null;
        unawaited(ref.read(pushRegistrarProvider).detach());
      }
      return;
    }

    if (_registeredFor == userId) return;
    _registeredFor = userId;
    unawaited(
      ref.read(pushRegistrarProvider).attach(
            // The server keeps this so a notification composed on its side —
            // rather than translated on this one — is written in her language.
            locale: _locale,
          ),
    );
  }

  // ── A notification arrives, or is tapped ─────────────────────────────────

  void _handleArrival(PushMessage message) {
    // The badge on the bell and the notification on her lock screen have to
    // agree. Without this they disagree for as long as she stays on whatever
    // screen she is on, which is exactly the moment she would look.
    unawaited(ref.read(notificationInboxProvider.notifier).load());
  }

  void _handleTap(PushMessage message) {
    if (!_ready) {
      // Tapped during launch, before the session was known. Held rather than
      // dropped; `_onAuthChanged` flushes it.
      _deferred = message;
      return;
    }
    _navigate(message);
  }

  void _navigate(PushMessage message) {
    final link = message.deepLink;
    if (link == null || link.isEmpty) return;

    final uri = Uri.tryParse(link);
    if (uri == null) return;

    // The same fold the router applies to a link the operating system hands
    // the app, so a notification and a pasted link reach the same screen. In
    // `reem://order/abc` the first segment is the URI's *authority*, not part
    // of its path, and GoRouter matches on the path alone.
    final path = deepLinkPath(uri) ?? (uri.hasScheme ? null : link);
    if (path == null) return;

    try {
      ref.read(goRouterProvider).go(path);
      ErrorReporter.leaveBreadcrumb('push', 'opened ${message.type}');
      // Whatever she just opened, she has now seen — and the rest of the
      // inbox may have moved on while the app was closed.
      unawaited(ref.read(notificationInboxProvider.notifier).load());
    } catch (error, stack) {
      // A link naming a route this build does not have must not crash the app
      // she just opened. It stays where it was.
      ErrorReporter.report(
        error,
        stack,
        context: 'push.navigate',
      );
    }
  }

  /// Arabic unless she has explicitly chosen otherwise. "Follow the device"
  /// means Arabic here for the same reason it does in `MyApp`: the English
  /// bundle is a deferred phase, so an English handset must not pick it up by
  /// accident.
  String get _locale =>
      AppBootstrap.localeController.locale?.languageCode ?? 'ar';

  @override
  Widget build(BuildContext context) => widget.child;
}
