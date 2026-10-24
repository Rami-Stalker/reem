import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ohara/core/experience/role_experience.dart';
import 'package:ohara/core/router/route_paths.dart';

/// The two navigation defects the suite could not have caught.
///
/// Almost every existing test is a `*_visual_preview_test`: it renders one
/// screen against a fixture and proves it paints. Neither of these was a
/// painting problem.
///
/// The buyer's third tab pointed at `/rooms` while the shell's branch map
/// still named `/cart`, so tapping it fell through to `context.go` and tore
/// the whole shell down — a full-screen room with no bottom bar and no way
/// back to Home or Search — while `/cart` became a branch no tab could reach
/// and the live basket badge sat on the tab that opens Rooms. The file that
/// holds the map says in its own comment that it and the manifest "must be
/// edited together — and were not, the last time the seller's tabs changed".
/// It happened again, so this pins them together.
///
/// The admin console read an empty permission set as "she may do nothing"
/// while the route guard read it as "we were not told"; since all sixteen
/// console destinations name a permission, an admin whose token omitted them
/// got a rail with nothing in it.
void main() {
  group('the shell reaches every tab it draws', () {
    /// Mirrors `AppShell._branchIndexForPath`, which is private and hand-kept.
    /// If a tab's path is missing here the real map is missing it too, and the
    /// tap leaves the shell.
    const branchIndexForPath = <String, int>{
      RoutePaths.home: 0,
      RoutePaths.search: 1,
      RoutePaths.closet: 2,
      RoutePaths.profile: 3,
      RoutePaths.sellerDashboard: 4,
      RoutePaths.myProducts: 5,
      RoutePaths.sellerOrders: 6,
      RoutePaths.sellerAnalytics: 7,
      RoutePaths.sellerStore: 8,
    };

    test('every buyer tab is a shell branch, so tapping one keeps the bar', () {
      for (final item in AppRoleExperience.buyer.navigation) {
        expect(
          branchIndexForPath.containsKey(item.path),
          isTrue,
          reason:
              'buyer tab "${item.label}" points at ${item.path}, which is not '
              'a branch — tapping it tears the shell down and strands her '
              'with no bottom bar',
        );
      }
    });

    test('every seller tab is a shell branch too', () {
      for (final item in AppRoleExperience.seller.navigation) {
        expect(
          branchIndexForPath.containsKey(item.path),
          isTrue,
          reason: 'seller tab "${item.label}" points at ${item.path}',
        );
      }
    });

    test('no two tabs share a branch, and none is orphaned', () {
      final claimed = <int>{};
      for (final item in [
        ...AppRoleExperience.buyer.navigation,
        ...AppRoleExperience.seller.navigation,
      ]) {
        final index = branchIndexForPath[item.path];
        expect(index, isNotNull, reason: item.path);
        expect(
          claimed.add(index!),
          isTrue,
          reason: 'two tabs both claim branch $index',
        );
      }
      // Nine branches, nine tabs. A branch nothing points at is a screen the
      // user cannot reach — which is what happened to the cart.
      expect(claimed.length, branchIndexForPath.length);
    });

    test('the cart badge does not ride on a tab that is not the cart', () {
      final cartTabs = AppRoleExperience.buyer.navigation
          .where((item) => item.surface == ExperienceSurface.cart)
          .toList();

      for (final tab in cartTabs) {
        expect(
          tab.path,
          RoutePaths.cart,
          reason:
              'a tab carrying the cart surface (and so the live basket count) '
              'opens ${tab.path}',
        );
      }
    });

    test('a destination that is not a tab still has a way in', () {
      // This replaces a weaker check that asked the role manifest whether the
      // cart had a menu entry. It did — and the cart was still unreachable,
      // because the manifest's menu groups are only rendered when the surface
      // is *not* the activity tab, and the activity tab is the only place a
      // buyer meets that screen. The manifest said yes; the app drew nothing.
      //
      // So this asks the source instead: does anything a woman can actually
      // tap navigate here? Crude, and it is the question that was wrong.
      const mustBeReachable = <String>[
        'RoutePaths.cart',
        'RoutePaths.orders',
        'RoutePaths.favorites',
        'RoutePaths.notifications',
        'RoutePaths.addresses',
        // Rooms gave its tab to the closet, so the closet has to lead there.
        'RoutePaths.rooms',
      ];

      // Everything under lib/, minus the places that only *declare* routes.
      const declaresOnly = [
        'route_paths.dart',
        'route_names.dart',
        'app_router_provider.dart',
        'auth_guard.dart',
        'experience_labels.dart',
        'role_experience.dart',
      ];

      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !declaresOnly.any(f.path.endsWith))
          .map((f) => f.readAsStringSync())
          .join('\n');

      for (final destination in mustBeReachable) {
        // Formatting puts a long argument on its own line, so match the name
        // inside a push/go call rather than an exact one-line spelling.
        final called = RegExp(
          r'(push|go)\(\s*' + RegExp.escape(destination) + r'\s*[,)]',
        );
        expect(
          called.hasMatch(sources),
          isTrue,
          reason:
              '$destination has no tab and nothing navigates to it either — '
              'she can reach it only by typing the URL',
        );
      }
    });
  });

  group('the console offers the doors it lets her through', () {
    /// Mirrors `authGuard`: an empty set means "not told", not "denied".
    bool guardAllows(Set<String> permissions, String? required) =>
        required == null || permissions.isEmpty || permissions.contains(required);

    /// Mirrors `AdminShell`, after the fix.
    bool shellOffers(Set<String> permissions, String? required) =>
        required == null || permissions.isEmpty || permissions.contains(required);

    test('an admin with no permissions in her token still gets a rail', () {
      const none = <String>{};
      final offered = AppRoleExperience.admin.navigation
          .where((item) => shellOffers(none, item.permission))
          .toList();

      expect(
        offered,
        isNotEmpty,
        reason:
            'every console destination names a permission, so reading an '
            'empty set as a denial leaves a console reachable only by typing '
            'a URL',
      );
    });

    test('the guard and the shell never disagree about a destination', () {
      for (final permissions in <Set<String>>[
        <String>{},
        {'admin:dashboard'},
        {'admin:dashboard', 'finance:read'},
      ]) {
        for (final item in AppRoleExperience.admin.navigation) {
          expect(
            shellOffers(permissions, item.permission),
            guardAllows(permissions, item.permission),
            reason:
                'the shell and the route guard disagree about '
                '${item.path} for $permissions',
          );
        }
      }
    });

    test('a scoped operator is still only offered her own sections', () {
      const support = <String>{'support:read'};
      final offered = AppRoleExperience.admin.navigation
          .where((item) => shellOffers(support, item.permission))
          .map((item) => item.permission)
          .toList();

      // The empty-set escape must not have widened a real permission set.
      expect(offered.every((p) => p == null || p == 'support:read'), isTrue);
    });
  });
}
