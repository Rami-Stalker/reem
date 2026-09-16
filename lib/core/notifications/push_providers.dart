import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/notifications/push_notification_service.dart';
import 'package:reem/core/notifications/push_registration.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';

/// The one push service for the whole app.
///
/// App-wide rather than auto-disposed for a reason that is not obvious: it
/// owns the message that launched the app from a cold start. An auto-disposing
/// provider would be rebuilt the first time nothing was watching it, taking
/// the pending launch with it, and a notification tapped from the lock screen
/// would open the home screen instead of the order it was about.
final pushServiceProvider = Provider<PushNotificationService>((ref) {
  final service = PushNotificationService();
  ref.onDispose(service.dispose);
  return service;
});

final pushRegistrarProvider = Provider<PushRegistrar>((ref) {
  return PushRegistrar(
    dio: ref.watch(dioProvider),
    push: ref.watch(pushServiceProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

/// What the phone currently allows.
///
/// A future rather than a stream because there is nothing to subscribe to:
/// neither platform tells an app that its notification permission changed in
/// the system settings. The settings screen invalidates this when it comes
/// back into view, which is the only moment the answer can have changed
/// without the app being involved.
final pushPermissionProvider = FutureProvider<PushPermission>((ref) async {
  return ref.watch(pushServiceProvider).permission();
});
