import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/auth/app_permissions.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/admin/presentation/widgets/admin_jump_palette.dart';
import 'package:reem/l10n/app_localizations.dart';

void main() {
  group('adminJumpDestinations', () {
    final l10n = lookupAppLocalizations(const Locale('ar'));

    test('offers only the doors this operator holds a key to', () {
      final destinations = adminJumpDestinations(
        const {AppPermissions.supportRead},
        l10n,
      );
      final paths = destinations.map((d) => d.path).toSet();
      expect(paths, contains(RoutePaths.adminSupport));
      expect(paths, isNot(contains(RoutePaths.adminFinancials)));
    });

    test('an unknown permission set offers every destination', () {
      final all = adminJumpDestinations(const {}, l10n);
      expect(all.map((d) => d.path), contains(RoutePaths.adminFinancials));
    });
  });

  testWidgets('typing a section without its hamza still finds it, and Enter '
      'goes there', (tester) async {
    String? arrived;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAdminJumpPalette(context, const [
                  AdminJumpDestination(
                    label: 'الإشراف',
                    icon: Icons.gavel_rounded,
                    path: '/moderation',
                  ),
                  AdminJumpDestination(
                    label: 'المالية',
                    icon: Icons.account_balance_rounded,
                    path: '/finance',
                    alias: 'Finance',
                  ),
                ]),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        for (final path in ['/moderation', '/finance'])
          GoRoute(
            path: path,
            builder: (_, _) {
              arrived = path;
              return const SizedBox.shrink();
            },
          ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'الاشراف');
    await tester.pumpAndSettle();
    expect(find.text('المالية'), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(arrived, '/moderation');
  });
}
