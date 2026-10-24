import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:ohara/core/observability/error_report.dart';

/// Where reports go.
///
/// Deliberately an interface with a console default rather than a Sentry
/// dependency: the app needs the *spine* — handlers installed, breadcrumbs
/// kept, PII stripped — before it needs a vendor, and picking one is a
/// commercial decision. Adding Crashlytics later is a class that implements
/// this and one line in `main`.
abstract interface class ErrorSink {
  void report(ErrorReport report);
}

/// The default: prints in debug, silent in release.
///
/// Silent rather than printing, because a release build with no sink attached
/// should not be writing anything to the device log — that log is readable by
/// other software on some Android builds.
final class DebugConsoleSink implements ErrorSink {
  const DebugConsoleSink();

  @override
  void report(ErrorReport report) {
    if (!kDebugMode) return;
    debugPrint('── ${report.severity.name.toUpperCase()} ─────────────────');
    debugPrint(ErrorRedaction.text('${report.context ?? 'unhandled'}: '
        '${report.error}'));
    for (final crumb in report.breadcrumbs) {
      debugPrint('   · ${ErrorRedaction.text(crumb.toString())}');
    }
    final trace = report.stackTrace;
    if (trace != null) {
      debugPrint(ErrorRedaction.text(
        trace.toString().split('\n').take(12).join('\n'),
      ));
    }
  }
}

/// The one place the app reports a failure.
///
/// Holds the breadcrumb trail, redacts on the way out, and fans out to
/// whatever sinks are attached. Static because failures happen in places that
/// have no `ref` — a zone handler, an `ErrorWidget.builder`, an isolate.
abstract final class ErrorReporter {
  /// How much history a report carries. Twenty is enough to see the route she
  /// came from and the request that failed, and small enough that holding it
  /// costs nothing.
  static const int breadcrumbLimit = 20;

  static final List<ErrorSink> _sinks = [const DebugConsoleSink()];
  static final Queue<Breadcrumb> _breadcrumbs = Queue<Breadcrumb>();

  /// Replaces the sink list. Call once from `main`.
  static void configure(List<ErrorSink> sinks) {
    _sinks
      ..clear()
      ..addAll(sinks);
  }

  static void addSink(ErrorSink sink) => _sinks.add(sink);

  /// Records something that happened, for the next report to carry.
  static void leaveBreadcrumb(String category, String message) {
    _breadcrumbs.add(
      Breadcrumb(
        category: category,
        message: ErrorRedaction.text(message),
        timestamp: DateTime.now(),
      ),
    );
    while (_breadcrumbs.length > breadcrumbLimit) {
      _breadcrumbs.removeFirst();
    }
  }

  static List<Breadcrumb> get breadcrumbs =>
      List.unmodifiable(_breadcrumbs);

  static void clearBreadcrumbs() => _breadcrumbs.clear();

  /// Reports a failure. Never throws: a reporter that can crash turns one bug
  /// into two, and the second one has no handler above it.
  static void report(
    Object error,
    StackTrace? stackTrace, {
    ErrorSeverity severity = ErrorSeverity.fatal,
    String? context,
    Map<String, Object?> extra = const {},
  }) {
    final report = ErrorReport(
      error: error,
      stackTrace: stackTrace,
      severity: severity,
      timestamp: DateTime.now(),
      context: context,
      breadcrumbs: breadcrumbs,
      extra: ErrorRedaction.map(extra),
    );
    for (final sink in _sinks) {
      try {
        sink.report(report);
      } on Object catch (sinkError) {
        if (kDebugMode) debugPrint('error sink failed: $sinkError');
      }
    }
  }
}
