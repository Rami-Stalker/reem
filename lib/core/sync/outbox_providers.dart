import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/network/connection_status.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/core/sync/outbox.dart';
import 'package:ohara/core/sync/outbox_intent.dart';
import 'package:ohara/features/social_posts/data/outbox_handlers.dart';

/// The app's one outbox, with its handlers registered.
final outboxProvider = Provider<Outbox>((ref) {
  final dio = ref.watch(dioProvider);
  final outbox = Outbox()
    ..register(
      PostEngagementOutboxHandler(dio, kind: EngagementIntents.like),
    )
    ..register(
      PostEngagementOutboxHandler(dio, kind: EngagementIntents.save),
    );
  ref.onDispose(outbox.dispose);
  return outbox;
});

/// Drains the queue the moment the connection comes back.
///
/// Watched once from the app shell. Without something holding it, the provider
/// is never created and the queue only drains when a screen happens to ask —
/// which is exactly when she is not looking.
final outboxDrainProvider = Provider<void>((ref) {
  final outbox = ref.watch(outboxProvider);

  // The first drain covers the case that matters most: she tapped, the app was
  // killed in her pocket, and this is the next launch.
  unawaited(outbox.drain());

  bool? online(AsyncValue<bool>? value) => switch (value) {
        AsyncData(:final value) => value,
        _ => null,
      };

  ref.listen<AsyncValue<bool>>(connectionStatusProvider, (previous, next) {
    // Only the transition matters. Draining on every emission would re-run
    // the whole queue each time the radio flickers between wifi and mobile.
    if (online(previous) == false && online(next) == true) {
      unawaited(outbox.drain());
    }
  });
});

/// What is still waiting, for a "syncing" mark in the UI.
final pendingIntentsProvider = StreamProvider<List<OutboxIntent>>((ref) {
  final outbox = ref.watch(outboxProvider);
  return outbox.changes;
});
