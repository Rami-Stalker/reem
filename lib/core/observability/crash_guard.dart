import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:ohara/core/observability/error_report.dart';
import 'package:ohara/core/observability/error_reporter.dart';

/// Catches everything Flutter can throw at you, in the four places it throws.
///
/// The app had none of these installed. A `RangeError` inside a card's
/// `build` painted the grey box in release and was never heard of again; an
/// unawaited future that threw took the isolate down silently. This is the
/// spine that has to exist before any of it can be fixed — you cannot fix what
/// nobody is told about.
abstract final class CrashGuard {
  /// Runs [body] with every error channel routed into [ErrorReporter].
  ///
  /// Four channels, because Flutter genuinely has four:
  ///
  /// * [FlutterError.onError] — anything thrown inside the framework: a build,
  ///   a layout, a gesture callback.
  /// * [PlatformDispatcher.onError] — errors that escape to the engine,
  ///   which is where an unawaited `Future` ends up.
  /// * [runZonedGuarded] — everything else asynchronous in our own code.
  /// * [Isolate.current.addErrorListener] — background isolates, which none of
  ///   the above can see.
  static Future<void> run(Future<void> Function() body) async {
    FlutterError.onError = (details) {
      // Keep the framework's own console dump in debug: it says which widget
      // and which constraint, which no report of ours reproduces.
      if (kDebugMode) FlutterError.presentError(details);
      ErrorReporter.report(
        details.exception,
        details.stack,
        severity: details.silent ? ErrorSeverity.warning : ErrorSeverity.fatal,
        context: details.context?.toDescription() ?? 'flutter framework',
        extra: {'library': details.library ?? 'flutter'},
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorReporter.report(error, stack, context: 'platform dispatcher');
      // True: it has been handled. Returning false re-throws to the engine and
      // kills the app, which is the behaviour this whole file exists to stop.
      return true;
    };

    _listenToIsolateErrors();

    await runZonedGuarded(body, (error, stack) {
      ErrorReporter.report(error, stack, context: 'uncaught async');
    });
  }

  static void _listenToIsolateErrors() {
    // Not available on web, where there is one isolate and no ports.
    if (kIsWeb) return;
    final port = RawReceivePort((dynamic pair) {
      final parts = pair as List<dynamic>;
      ErrorReporter.report(
        (parts.first as Object?) ?? 'isolate error',
        parts.length > 1 && parts[1] != null
            ? StackTrace.fromString('${parts[1]}')
            : null,
        context: 'background isolate',
      );
    });
    Isolate.current.addErrorListener(port.sendPort);
  }
}
