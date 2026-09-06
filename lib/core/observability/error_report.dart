import 'package:flutter/foundation.dart';

/// How much a failure matters.
enum ErrorSeverity {
  /// Recoverable and expected — a request failed, a parse fell back. Useful
  /// as context around a later crash, not worth waking anyone for.
  info,

  /// Something is broken but the app carried on: a widget subtree failed to
  /// build, a background sync gave up.
  warning,

  /// The app could not continue doing what it was asked to do.
  fatal,
}

/// One failure, ready to be sent somewhere.
@immutable
class ErrorReport {
  const ErrorReport({
    required this.error,
    required this.stackTrace,
    required this.severity,
    required this.timestamp,
    this.context,
    this.breadcrumbs = const [],
    this.extra = const {},
  });

  final Object error;
  final StackTrace? stackTrace;
  final ErrorSeverity severity;
  final DateTime timestamp;

  /// Where this happened, in words: `'product page: add to bag'`.
  final String? context;

  /// What led here, oldest first.
  final List<Breadcrumb> breadcrumbs;

  /// Anything else worth carrying. Runs through [ErrorRedaction] before it
  /// leaves the device.
  final Map<String, Object?> extra;

  @override
  String toString() => '[${severity.name}] ${context ?? 'unhandled'}: $error';
}

/// A thing that happened before the failure.
///
/// Kept deliberately thin — a category, a short message, a timestamp. A
/// breadcrumb is for reconstructing *what she was doing*, not for logging her
/// data, and the fields are narrow so that distinction stays easy to hold.
@immutable
class Breadcrumb {
  const Breadcrumb({
    required this.category,
    required this.message,
    required this.timestamp,
  });

  /// `navigation`, `network`, `auth`, `action`.
  final String category;
  final String message;
  final DateTime timestamp;

  @override
  String toString() => '$category: $message';
}

/// Strips anything that identifies a person before a report leaves the device.
///
/// This app serves women shopping in Syria. A crash report that carries a
/// phone number, an address or a bearer token is a safety problem, not a
/// privacy footnote — so redaction happens here, once, on the way out, rather
/// than being each caller's job to remember.
abstract final class ErrorRedaction {
  static final _patterns = <RegExp, String>{
    // Bearer tokens and anything that looks like a JWT.
    RegExp(r'Bearer\s+[A-Za-z0-9._\-]+'): 'Bearer [redacted]',
    RegExp(r'\beyJ[A-Za-z0-9._\-]{10,}'): '[jwt]',
    // Syrian mobile numbers, in the shapes the app accepts.
    RegExp(r'(\+?963|0)?9\d{8}\b'): '[phone]',
    RegExp(r'\b[\w.\-]+@[\w\-]+\.[\w.\-]+\b'): '[email]',
    // Anything a query string calls a token, key, secret or code.
    RegExp(
      r'([?&](?:token|key|secret|code|otp|password)=)[^&\s]+',
      caseSensitive: false,
    ): r'$1[redacted]',
  };

  /// The keys whose values are dropped outright rather than pattern-matched.
  static const _blockedKeys = {
    'password',
    'token',
    'access_token',
    'refresh_token',
    'otp',
    'code',
    'phone',
    'email',
    'address',
    'card',
    'authorization',
  };

  static String text(String input) {
    var out = input;
    for (final MapEntry(key: pattern, value: replacement)
        in _patterns.entries) {
      out = out.replaceAllMapped(
        pattern,
        (m) => replacement.replaceAll(r'$1', m.groupCount >= 1 ? '${m[1]}' : ''),
      );
    }
    return out;
  }

  static Map<String, Object?> map(Map<String, Object?> input) {
    return {
      for (final entry in input.entries)
        entry.key: _blockedKeys.contains(entry.key.toLowerCase())
            ? '[redacted]'
            : _value(entry.value),
    };
  }

  static Object? _value(Object? value) {
    if (value is String) return text(value);
    if (value is Map<String, Object?>) return map(value);
    if (value is Iterable<Object?>) {
      return value.map(_value).toList(growable: false);
    }
    return value;
  }
}
