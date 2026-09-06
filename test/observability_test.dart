// The reporting spine. Redaction is the part that matters most: this app
// serves women shopping in Syria, and a crash report carrying a phone number
// or a bearer token is a safety problem, not a privacy footnote.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/network/interceptors/telemetry_interceptor.dart';
import 'package:reem/core/observability/error_report.dart';
import 'package:reem/core/observability/error_reporter.dart';

class _RecordingSink implements ErrorSink {
  final List<ErrorReport> reports = [];

  @override
  void report(ErrorReport report) => reports.add(report);
}

void main() {
  late _RecordingSink sink;

  setUp(() {
    sink = _RecordingSink();
    ErrorReporter.configure([sink]);
    ErrorReporter.clearBreadcrumbs();
  });

  tearDown(() => ErrorReporter.clearBreadcrumbs());

  group('redaction', () {
    test('a bearer token never survives', () {
      const raw = 'failed with Authorization: Bearer abc.DEF-123_xyz';
      expect(ErrorRedaction.text(raw), isNot(contains('abc.DEF-123_xyz')));
      expect(ErrorRedaction.text(raw), contains('[redacted]'));
    });

    test('a JWT never survives', () {
      const raw = 'token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9payload';
      expect(ErrorRedaction.text(raw), isNot(contains('eyJhbGci')));
    });

    test('a Syrian mobile number never survives', () {
      for (final number in ['+963987654321', '0987654321', '987654321']) {
        final out = ErrorRedaction.text('customer $number could not check out');
        expect(out, isNot(contains(number)), reason: number);
        expect(out, contains('[phone]'));
      }
    });

    test('an email never survives', () {
      final out = ErrorRedaction.text('leen@example.com failed');
      expect(out, isNot(contains('leen@example.com')));
    });

    test('a sensitive query parameter is stripped, the key is kept', () {
      final out = ErrorRedaction.text('/auth/otp/verify?code=418823&id=7');
      expect(out, isNot(contains('418823')));
      expect(out, contains('code='));
      expect(out, contains('id=7'), reason: 'harmless parameters stay legible');
    });

    test('sensitive map keys are dropped whole, nested included', () {
      final out = ErrorRedaction.map({
        'productId': 'p-1',
        'password': 'hunter2',
        'body': {'phone': '0987654321', 'quantity': 2},
        'headers': ['Authorization: Bearer secret-token'],
      });

      expect(out['productId'], 'p-1');
      expect(out['password'], '[redacted]');
      expect((out['body']! as Map)['phone'], '[redacted]');
      expect((out['body']! as Map)['quantity'], 2);
      expect('${out['headers']}', isNot(contains('secret-token')));
    });

    test('a report redacts its extras on the way out', () {
      ErrorReporter.report(
        'boom',
        StackTrace.empty,
        extra: {'phone': '0987654321'},
      );
      expect(sink.reports.single.extra['phone'], '[redacted]');
    });
  });

  group('breadcrumbs', () {
    test('a report carries what led to it, oldest first', () {
      ErrorReporter.leaveBreadcrumb('navigation', 'push /cart');
      ErrorReporter.leaveBreadcrumb('network', 'POST /orders → 500');

      ErrorReporter.report('boom', StackTrace.empty);

      final crumbs = sink.reports.single.breadcrumbs;
      expect(crumbs, hasLength(2));
      expect(crumbs.first.message, 'push /cart');
      expect(crumbs.last.category, 'network');
    });

    test('the trail is bounded, keeping the most recent', () {
      for (var i = 0; i < ErrorReporter.breadcrumbLimit + 5; i++) {
        ErrorReporter.leaveBreadcrumb('action', 'step $i');
      }
      final crumbs = ErrorReporter.breadcrumbs;
      expect(crumbs, hasLength(ErrorReporter.breadcrumbLimit));
      expect(crumbs.last.message, 'step ${ErrorReporter.breadcrumbLimit + 4}');
      expect(crumbs.first.message, 'step 5');
    });

    test('a breadcrumb is redacted as it is recorded', () {
      ErrorReporter.leaveBreadcrumb('network', 'GET /users/0987654321');
      expect(ErrorReporter.breadcrumbs.single.message, isNot(contains('0987654321')));
    });
  });

  test('a failing sink cannot take the app down with it', () {
    ErrorReporter.configure([_ThrowingSink(), sink]);
    expect(() => ErrorReporter.report('boom', StackTrace.empty), returnsNormally);
    expect(sink.reports, hasLength(1), reason: 'the healthy sink still ran');
  });

  group('network telemetry', () {
    Dio client(int status) {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.interceptors.add(const TelemetryInterceptor());
      dio.httpClientAdapter = _StatusAdapter(status);
      return dio;
    }

    test('a 4xx leaves a breadcrumb and reports nothing', () async {
      await client(422).get<dynamic>('/orders').catchError(
            (Object _) => Response<dynamic>(
              requestOptions: RequestOptions(path: '/orders'),
            ),
          );

      expect(sink.reports, isEmpty, reason: 'the server was working correctly');
      expect(ErrorReporter.breadcrumbs.single.message, contains('422'));
    });

    test('a 5xx is reported: nobody else will notice', () async {
      await client(500).get<dynamic>('/orders').catchError(
            (Object _) => Response<dynamic>(
              requestOptions: RequestOptions(path: '/orders'),
            ),
          );

      expect(sink.reports, hasLength(1));
      expect(sink.reports.single.severity, ErrorSeverity.warning);
      expect(sink.reports.single.extra['status'], 500);
    });
  });
}

class _ThrowingSink implements ErrorSink {
  @override
  void report(ErrorReport report) => throw StateError('sink is broken');
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString('{"message":"no"}', status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}
