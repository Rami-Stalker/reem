import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/app/app.dart';
import 'package:ohara/app/bootstrap.dart';
import 'package:ohara/core/observability/breadcrumb_observers.dart';
import 'package:ohara/core/observability/crash_guard.dart';
import 'package:ohara/core/observability/error_widget.dart';

Future<void> main() async {
  // Everything runs inside the guard, initialisation included: a failure while
  // loading the theme or the locale is exactly the kind that used to leave a
  // blank screen and no trace of why.
  await CrashGuard.run(() async {
    await AppBootstrap.initialize();
    OharaErrorWidget.install();
    runApp(
      const ProviderScope(
        observers: [ProviderBreadcrumbs()],
        retry: noProviderRetry,
        child: MyApp(),
      ),
    );
  });
}

/// Riverpod's automatic retry, switched off.
///
/// By default a provider that fails is rebuilt up to ten times, with delays
/// growing to 6.4 s, and stays *loading* the whole time — every attempt a new
/// request with its own 30 s timeout. A failed read therefore never reached
/// its error state: the product's reviews, among others, showed a spinner for
/// minutes and looked like they would never load. The network layer already
/// retries what is safe to retry (`RetryInterceptor`); a screen should show
/// the failure, with its own retry button, as soon as that has given up.
Duration? noProviderRetry(int retryCount, Object error) => null;
