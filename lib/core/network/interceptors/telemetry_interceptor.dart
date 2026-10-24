import 'package:dio/dio.dart';

import 'package:ohara/core/observability/error_report.dart';
import 'package:ohara/core/observability/error_reporter.dart';

/// Turns request failures into breadcrumbs, and server faults into reports.
///
/// The distinction is the whole point of this file:
///
/// * A **4xx** is the server working correctly. A 401 on an expired session, a
///   422 on a bad phone number — these are the API doing its job, and paging
///   anyone about them would bury the signal. They leave a breadcrumb.
/// * A **5xx** or a malformed body is the platform failing. Those are
///   reported, because nobody else is going to notice.
/// * A **connection error** is her network, not ours. Breadcrumb only —
///   otherwise every commuter on a bad connection files a bug report.
class TelemetryInterceptor extends Interceptor {
  const TelemetryInterceptor();

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // Only the shape of the call, never the body: a successful cart read is
    // not something a report should be able to carry.
    ErrorReporter.leaveBreadcrumb(
      'network',
      '${response.requestOptions.method} ${response.requestOptions.path} '
          '→ ${response.statusCode}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final status = err.response?.statusCode;
    ErrorReporter.leaveBreadcrumb(
      'network',
      '${options.method} ${options.path} → ${status ?? err.type.name}',
    );

    if (status != null && status >= 500) {
      ErrorReporter.report(
        err,
        err.stackTrace,
        severity: ErrorSeverity.warning,
        context: 'server fault on ${options.method} ${options.path}',
        extra: {'status': status},
      );
    }

    handler.next(err);
  }
}
