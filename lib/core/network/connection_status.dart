import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/presentation/providers/core_providers.dart';

/// Whether the handset currently has a route to the network.
///
/// The app has always had [NetworkInfo] for a one-off check. This is the live
/// signal, and it exists because the response cache now serves the last known
/// answer when a request fails: a screen that quietly shows this morning's
/// prices is a good screen, but only if it says so.
///
/// `connectivity_plus` reports the *interface*, not reachability — a phone on
/// a captive-portal wifi reads as online. That is acceptable here: the banner
/// is a hint, and the stale-serving path is driven by real request failures,
/// not by this.
final connectionStatusProvider = StreamProvider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);

  Future<bool> resolve() async {
    final results = await connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  final controller = StreamController<bool>();
  unawaited(resolve().then(controller.add).catchError((_) {
    // A platform that cannot answer is treated as online: a false offline
    // banner on every screen is worse than no banner.
    controller.add(true);
  }));

  final subscription = connectivity.onConnectivityChanged.listen(
    (results) => controller.add(
      results.any((r) => r != ConnectivityResult.none),
    ),
    onError: (_) => controller.add(true),
  );

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream.distinct();
});
