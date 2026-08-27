// Renders the admin console to PNGs so the design can be eyeballed without an
// administrator session or a running backend. Not an assertion test — it
// writes `build/visual/admin_*.png` and is meant to be run on demand.
//
//   flutter test test/admin_console_visual_preview_test.dart
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/admin/domain/entities/admin_console_entity.dart';
import 'package:reem/features/admin/domain/entities/admin_stats_entity.dart';
import 'package:reem/features/admin/domain/entities/analytics_dashboard_entity.dart';
import 'package:reem/features/admin/domain/repositories/admin_repository.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';
import 'package:reem/features/admin/presentation/screens/admin_analytics_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

Future<void> _loadFonts() async {
  for (final entry in const {
    'Cairo': 'assets/fonts/Cairo-VariableFont.ttf',
    'PlayfairDisplay': 'assets/fonts/PlayfairDisplay-VariableFont.ttf',
  }.entries) {
    final loader = FontLoader(entry.key)
      ..addFont(
        File(entry.value).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    await loader.load();
  }
}

/// The console reaches for secure storage through the auth interceptor. There
/// is no implementation in a widget test, and the exception lands mid-pump and
/// derails the entrance animations, so stub it.
void _stubPlatformChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => call.method == 'readAll' ? <String, String>{} : null,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _stubPlatformChannels();
    await _loadFonts();
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the admin dashboard in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(2560, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(themeMode: mode, screen: const AdminDashboardScreen()),
      );
      await _settle(tester);
      await _capture(tester, 'admin_dashboard_${mode.name}');
    });
  }

  testWidgets('renders the admin analytics console', (tester) async {
    tester.view.physicalSize = const Size(2560, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Preview(
        themeMode: ThemeMode.light,
        screen: AdminAnalyticsScreen(),
      ),
    );
    await _settle(tester);
    await _capture(tester, 'admin_analytics');
  });
}

class _Preview extends StatelessWidget {
  const _Preview({required this.themeMode, required this.screen});

  final ThemeMode themeMode;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        adminRepositoryProvider.overrideWithValue(const _FakeAdminRepository()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        locale: const Locale('ar'),
        supportedLocales: L10nSetup.supportedLocales,
        localizationsDelegates: const [
          gen.AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: RepaintBoundary(
          key: _captureKey,
          child: Scaffold(
            body: Stack(
              children: [
                const Positioned.fill(child: AdminConsoleBackground()),
                screen,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Plausible platform figures, so the console can be judged on layout rather
/// than on zeroes. Money is SYP-scaled, matching the seed.
final class _FakeAdminRepository implements AdminRepository {
  const _FakeAdminRepository();

  @override
  Future<Result<AdminStatsEntity>> getStats() async => const Success(
    AdminStatsEntity(
      totalSales: 4820000000,
      totalOrders: 18420,
      activeUsers: 32400,
      conversionRate: 6.4,
      salesTrend: '+18.4%',
      ordersTrend: '+12.1%',
      usersTrend: '+8.6%',
      conversionTrend: '+0.4%',
    ),
  );

  @override
  Future<Result<AdminConsoleSection>> getSection({
    required String key,
    required String title,
    required String endpoint,
  }) async => Success(
    AdminConsoleSection(
      key: key,
      title: title,
      records: [
        for (var i = 1; i <= 6; i++)
          AdminRecord(
            id: '$key-$i',
            title: 'وثّقت المشرِفة بائعة جديدة',
            subtitle: 'أتيليه الورد · دمشق',
            status: 'مكتمل',
            metrics: const {},
            raw: const {},
          ),
      ],
    ),
  );

  @override
  Future<Result<AnalyticsDashboardEntity>> getAnalyticsDashboard({
    DateTime? start,
    DateTime? end,
  }) async => Success(
    AnalyticsDashboardEntity(
      grossRevenue: 4820000000,
      netRevenue: 3910000000,
      totalOrders: 18420,
      averageOrderValue: 262000,
      activeCustomers: 32400,
      repeatRate: 38.2,
      conversionRate: 6.4,
      retentionRate: 71.5,
      onlineUsers: 284,
      salesSeries: const [
        AnalyticsPoint(label: 'اث', value: 486000000),
        AnalyticsPoint(label: 'ثل', value: 542000000),
        AnalyticsPoint(label: 'أر', value: 498000000),
        AnalyticsPoint(label: 'خم', value: 631000000),
        AnalyticsPoint(label: 'جم', value: 824000000),
        AnalyticsPoint(label: 'سب', value: 712000000),
        AnalyticsPoint(label: 'أح', value: 604000000),
      ],
      funnel: const [
        AnalyticsPoint(label: 'مشاهدات', value: 482000),
        AnalyticsPoint(label: 'للمفضّلة', value: 68400),
        AnalyticsPoint(label: 'للسلة', value: 39200),
        AnalyticsPoint(label: 'شراء', value: 18420),
      ],
      topProducts: const [
        AnalyticsRankedItem(
          title: 'فستان حرير بماء الورد',
          value: 82890000,
          subtitle: '97 قطعة',
        ),
        AnalyticsRankedItem(
          title: 'عطر زهر المخمل',
          value: 57060000,
          subtitle: '134 قطعة',
        ),
        AnalyticsRankedItem(
          title: 'حقيبة كتف صغيرة مبطّنة',
          value: 44280000,
          subtitle: '76 قطعة',
        ),
      ],
      topSellers: const [
        AnalyticsRankedItem(
          title: 'أتيليه الورد',
          value: 184300000,
          subtitle: 'دمشق',
        ),
        AnalyticsRankedItem(
          title: 'دار النور',
          value: 132400000,
          subtitle: 'حلب',
        ),
        AnalyticsRankedItem(
          title: 'بتلات المخمل',
          value: 97600000,
          subtitle: 'اللاذقية',
        ),
      ],
      refreshedAt: DateTime(2026, 8, 24, 9),
    ),
  );

  @override
  Future<Result<void>> createNotificationCampaign(
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> runNotificationCampaign(String campaignId) async =>
      const Success(null);
}

/// Lets the providers resolve and every entrance animation finish, so a
/// capture never catches a panel still faded out.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final dir = Directory('build/visual')..createSync(recursive: true);
    final file = File('${dir.path}/$name.png')
      ..writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path}');
  });
}
