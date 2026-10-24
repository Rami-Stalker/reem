import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/router/app_router_provider.dart';
import 'package:ohara/core/router/auth_guard.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/services/share_links.dart';
import 'package:ohara/features/auth/presentation/providers/auth_notifier.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/providers/auth_state.dart';

/// A shared link, followed all the way to a screen — against the real route
/// table, not a stand-in.
///
/// `share_links_test.dart` proves the link shapes agree with the server's.
/// This proves the other half: that the route each one resolves to is a route
/// the app actually declares, and that a woman without an account is allowed
/// to reach it.
///
/// Both halves were broken, and separately. `/p/<id>` mapped to `/content/:id`,
/// which had a path constant, a route name and no route — so the destination
/// existed only as a string. And `_publicRoutes` is written in route patterns
/// (`/user/:id`) while the guard compared them against concrete locations
/// (`/user/abc`), so ten routes deliberately listed as public were in fact
/// gated. A shared link is precisely a stranger arriving at one of them.
void main() {
  /// The router as the app builds it, with a settled signed-out session —
  /// which is the state a link arriving from WhatsApp finds.
  GoRouter buildRouter() {
    final container = ProviderContainer(
      overrides: [authNotifierProvider.overrideWith((ref) => _SignedOut())],
    );
    addTearDown(container.dispose);
    return container.read(goRouterProvider);
  }

  /// Where the top-level redirect sends [url], following the chain to a
  /// fixed point the way GoRouter does.
  String resolve(String url) {
    var location = Uri.parse(url).path;
    final query = Uri.parse(url).query;
    if (query.isNotEmpty) location = '$location?$query';

    for (var hop = 0; hop < 5; hop++) {
      final next = ShareLinks.routeFor(Uri.parse(location));
      if (next == null || next == location) return location;
      location = next;
    }
    fail('$url never settled — the redirect is looping');
  }

  group('a shared link reaches a real screen', () {
    test('every share path resolves to a route the app declares', () {
      final router = buildRouter();

      final links = {
        'product': ShareLinks.product('3f2504e0-4f89-11d3-9a0c-0305e82c3301'),
        'post': ShareLinks.content('3f2504e0-4f89-11d3-9a0c-0305e82c3302'),
        'profile': ShareLinks.profile('3f2504e0-4f89-11d3-9a0c-0305e82c3303'),
        'storefront': ShareLinks.storefront('3f2504e0-4f89-11d3-9a0c-0305e82c3304'),
        'collection': ShareLinks.collection('new_arrivals'),
        'room invite': ShareLinks.roomInvite('abc123'),
      };

      for (final entry in links.entries) {
        final location = resolve(entry.value);
        final match = router.configuration.findMatch(Uri.parse(location));
        expect(
          match.isError,
          isFalse,
          reason:
              'a shared ${entry.key} link (${entry.value}) resolved to '
              '$location, which matches no route — she lands on the 404 screen',
        );
      }
    });

    test('the short profile form lands on the same screen as the long one', () {
      expect(resolve('https://x.test/u/u1'), '/user/u1');
    });

    test('a product link ends on the product page, not on itself', () {
      // The share path and the app's route are different strings; resolving one
      // to the other and stopping is the whole job.
      expect(
        resolve('https://x.test/product/abc'),
        '/product-details?id=abc',
      );
    });
  });

  group('a stranger is let in', () {
    /// The guard's answer for [location] with no session: null means "carry
    /// on", anything else is a redirect — in practice the sign-in wall.
    ///
    /// A widget test only because `authGuard` takes a `BuildContext`; it reads
    /// nothing from it on any path here, but one has to exist.
    Future<String?> Function(String) guardWith(BuildContext context) {
      final router = buildRouter();
      return (String location) {
        final match = router.configuration.findMatch(Uri.parse(location));
        expect(
          match.isError,
          isFalse,
          reason:
              '$location matches no route, so the guard was never the issue',
        );
        final state = router.configuration.buildTopLevelGoRouterState(match);
        return Future<String?>.value(
          authGuard(context, state, const AuthState(isInitialized: true)),
        );
      };
    }

    Future<void> withGuard(
      WidgetTester tester,
      Future<void> Function(Future<String?> Function(String)) body,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await body(guardWith(captured));
    }

    testWidgets(
      'she can open a post, a profile and a boutique without an account',
      (tester) async {
        // The whole commerce case: she follows a link into a look, sees the
        // dress and reaches the boutique before she has signed up for anything.
        await withGuard(tester, (guard) async {
          for (final location in [
            '/content/3f2504e0-4f89-11d3-9a0c-0305e82c3302',
            '/user/3f2504e0-4f89-11d3-9a0c-0305e82c3303',
            '/user/3f2504e0-4f89-11d3-9a0c-0305e82c3304/products',
            '/product-details?id=3f2504e0-4f89-11d3-9a0c-0305e82c3301',
            '/collection/new_arrivals',
          ]) {
            expect(
              await guard(location),
              isNull,
              reason: '$location sent a signed-out visitor to the sign-in wall',
            );
          }
        });
      },
    );

    testWidgets('the parameterised routes listed as public really are', (
      tester,
    ) async {
      // These were all listed in `_publicRoutes`, each with a comment saying
      // why it had to be, and none of them matched: the set is written in
      // route patterns and the guard compared concrete locations.
      await withGuard(tester, (guard) async {
        for (final location in [
          '/category/dresses',
          '/policies/doc/terms',
          '/track/RM-123456',
          '/order/3f2504e0-4f89-11d3-9a0c-0305e82c3301',
        ]) {
          expect(await guard(location), isNull, reason: '$location is gated');
        }
      });
    });

    testWidgets('a private screen still asks her to sign in', (tester) async {
      // The guard is not simply answering null to everything, which is the
      // failure mode a looser fix would have had.
      await withGuard(tester, (guard) async {
        expect(
          await guard(RoutePaths.wallet),
          startsWith(RoutePaths.authRequired),
        );
        expect(
          await guard(RoutePaths.closet),
          startsWith(RoutePaths.authRequired),
        );
      });
    });
  });
}

class _SignedOut extends StateNotifier<AuthState> implements AuthNotifier {
  _SignedOut() : super(const AuthState(isInitialized: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
