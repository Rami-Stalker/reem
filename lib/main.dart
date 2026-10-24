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
        child: MyApp(),
      ),
    );
  });
}
