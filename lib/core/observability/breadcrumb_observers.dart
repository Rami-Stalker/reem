import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/observability/error_reporter.dart';

/// Records what she was doing, so a crash report says more than "it threw".
///
/// A stack trace tells you the line. A breadcrumb trail tells you she came
/// from the cart, the network dropped, and the third read failed — which is
/// the difference between a bug you can reproduce and one you cannot.
///
/// Everything recorded here is a route name or a provider name. Nothing
/// carries a value, so there is no path by which her data reaches a report.

/// Route changes, from GoRouter's observer slot.
class NavigationBreadcrumbs extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('push', route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('pop', route);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _record('replace', newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  void _record(String action, Route<dynamic> route) {
    final name = route.settings.name ?? route.settings.arguments?.toString();
    if (name == null || name.isEmpty) return;
    ErrorReporter.leaveBreadcrumb('navigation', '$action $name');
  }
}

/// Provider failures.
///
/// Only failures: recording every provider that ever updated would bury the
/// twenty slots in noise, and the interesting event is always the one that
/// threw.
final class ProviderBreadcrumbs extends ProviderObserver {
  const ProviderBreadcrumbs();

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final name = context.provider.name ?? context.provider.runtimeType.toString();
    ErrorReporter.leaveBreadcrumb('provider', '$name failed: $error');
  }
}
