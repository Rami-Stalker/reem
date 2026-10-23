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
import 'package:go_router/go_router.dart';
import 'package:reem/core/auth/app_permissions.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/admin/data/models/admin_briefing_model.dart';
import 'package:reem/features/admin/domain/entities/admin_console_entity.dart';
import 'package:reem/features/admin/domain/entities/admin_stats_entity.dart';
import 'package:reem/features/admin/domain/entities/analytics_dashboard_entity.dart';
import 'package:reem/features/admin/domain/repositories/admin_repository.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';
import 'package:reem/features/admin/presentation/screens/admin_analytics_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_section_screen.dart';
import 'package:reem/features/admin/presentation/screens/admin_seller_applications_screen.dart';
import 'package:reem/features/admin/presentation/shell/admin_shell.dart';
import 'package:reem/features/experience/presentation/providers/role_experience_provider.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

/// A morning with work in it: one urgent finding first, then the rest.
final _briefing = AdminBriefing(
  windowDays: 30,
  generatedAt: DateTime(2026, 8, 24, 8),
  quiet: false,
  findings: const [
    AdminFinding(
      code: 'trust.disputes',
      severity: FindingSeverity.critical,
      title: 'تضاعفت النزاعات على بائعة واحدة هذا الأسبوع',
      action: 'راجعي حالات «أتيليه الورد» المفتوحة قبل تحويل أي مستحقات.',
      weight: 90,
      href: '/admin/trust',
    ),
    AdminFinding(
      code: 'catalog.duplicates',
      severity: FindingSeverity.warning,
      title: '٣٤ منتجاً مكرّراً في قسم الفساتين',
      action: 'ادمجي النسخ أو أخفيها كي لا تتشتّت المشاهدات.',
      weight: 60,
      href: '/admin/catalog/duplicates',
    ),
    AdminFinding(
      code: 'economics.commission',
      severity: FindingSeverity.opportunity,
      title: 'العمولة على العطور أدنى من بقية الأقسام',
      action: 'قد يستحق القسم مراجعة لنسبة العمولة.',
      weight: 30,
      href: '/admin/commissions',
    ),
  ],
);

/// A review queue that reads like real work rather than six identical rows.
const _applications = <Map<String, dynamic>>[
  {
    'id': 'app-1',
    'status': 'PENDING',
    'business_name': 'أتيليه الورد',
    'legal_name': 'ريم الحلبي',
    'business_category': 'أزياء نسائية',
    'commercial_registration': 'DMS-44821',
    'contact_phone': '+963 933 118 204',
    'contact_email': 'rose@atelier.sy',
    'business_address': 'دمشق · المزة · شارع الجلاء',
    'bank_name': 'بنك بيمو السعودي الفرنسي',
    'account_holder': 'ريم الحلبي',
    'iban': 'SY86 0021 0000 0000 0011 2233',
    'government_id_url': 'https://example.invalid/id.pdf',
    'business_license_url': 'https://example.invalid/licence.pdf',
    'years_experience': '6',
    'history': [
      {
        'status': 'PENDING',
        'admin_name': 'سلمى',
        'reason': 'وصل الطلب وبانتظار قراءة المستندات',
      },
    ],
  },
  {
    'id': 'app-2',
    'status': 'UNDER_REVIEW',
    'business_name': 'دار النور',
    'legal_name': 'نور العطار',
    'contact_phone': '+963 944 771 006',
  },
  {
    'id': 'app-3',
    'status': 'NEEDS_MORE_DOCUMENTS',
    'business_name': 'بتلات المخمل',
    'legal_name': 'ليلى منصور',
    'contact_email': 'layla@velvet.sy',
  },
  {
    'id': 'app-4',
    'status': 'APPROVED',
    'business_name': 'خيوط الياسمين',
    'legal_name': 'هدى شامية',
    'contact_phone': '+963 991 442 887',
  },
];

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
  // Material's icon font ships with the SDK, not the app, so a widget test
  // draws every icon as a box unless it is loaded by hand.
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (root != null && icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
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
      tester.view.physicalSize = const Size(2560, 3000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(themeMode: mode, screen: const AdminDashboardScreen()),
      );
      await _settle(tester);
      await _capture(tester, 'admin_dashboard_${mode.name}');
    });
  }

  testWidgets('renders the admin dashboard on a phone', (tester) async {
    tester.view.physicalSize = const Size(1170, 7400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Preview(
        themeMode: ThemeMode.light,
        screen: AdminDashboardScreen(),
      ),
    );
    await _settle(tester);
    await _capture(tester, 'admin_dashboard_phone');
  });

  testWidgets('renders the seller review queue', (tester) async {
    tester.view.physicalSize = const Size(2000, 2200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Preview(
        themeMode: ThemeMode.light,
        screen: AdminSellerApplicationsScreen(),
      ),
    );
    await _settle(tester);
    await _capture(tester, 'admin_seller_applications');
  });

  testWidgets('renders the moderation console with its actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2000, 2000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        screen: AdminSectionScreen(config: adminSectionConfigs['moderation']!),
      ),
    );
    await _settle(tester);
    await _capture(tester, 'admin_moderation');
  });

  for (final (name, size) in const [
    ('admin_shell_wide', Size(2800, 2000)),
    ('admin_shell_narrow', Size(1800, 2000)),
  ]) {
    testWidgets('renders the console shell: $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(
          themeMode: ThemeMode.light,
          shellPath: RoutePaths.adminModeration,
          screen: AdminSectionScreen(
            config: adminSectionConfigs['moderation']!,
          ),
        ),
      );
      await _settle(tester);
      await _capture(tester, name);
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
  const _Preview({
    required this.themeMode,
    required this.screen,
    this.shellPath,
  });

  final ThemeMode themeMode;
  final Widget screen;

  /// When set, the screen is drawn inside the real console shell at this
  /// route, so the rail can be judged too.
  final String? shellPath;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        adminRepositoryProvider.overrideWithValue(const _FakeAdminRepository()),
        adminBriefingProvider.overrideWith((ref) async => _briefing),
        adminOperatorNameProvider.overrideWithValue('سلمى'),
        // A super administrator, so a capture shows every action the console
        // is capable of offering rather than a role's subset of them.
        currentPermissionsProvider.overrideWithValue(const {
          AppPermissions.adminDashboard,
          AppPermissions.userManage,
          AppPermissions.sellerVerificationReview,
          AppPermissions.productManage,
          AppPermissions.contentModerate,
          AppPermissions.orderRead,
          AppPermissions.supportRead,
          AppPermissions.supportWrite,
          AppPermissions.financeRead,
          AppPermissions.financeWrite,
          AppPermissions.analyticsRead,
          AppPermissions.auditRead,
          AppPermissions.authorizationManage,
        }),
      ],
      child: shellPath != null
          ? MaterialApp.router(
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
              routerConfig: GoRouter(
                initialLocation: shellPath,
                routes: [
                  GoRoute(
                    path: shellPath!,
                    builder: (_, _) => RepaintBoundary(
                      key: _captureKey,
                      child: AdminShell(child: screen),
                    ),
                  ),
                ],
              ),
            )
          : MaterialApp(
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
    int page = 1,
    int limit = 25,
    String? query,
    String? status,
  }) async => Success(switch (key) {
    'sellerApplications' => AdminConsoleSection(
      key: key,
      title: title,
      total: 14,
      hasMore: true,
      summary: const {'pending': '9'},
      records: [
        for (final application in _applications)
          AdminRecord(
            id: application['id']! as String,
            title: application['business_name']! as String,
            subtitle: application['legal_name']! as String,
            status: application['status']! as String,
            metrics: const {},
            raw: application,
          ),
      ],
    ),
    'accountVerifications' => AdminConsoleSection(
      key: key,
      title: title,
      total: 3,
      summary: const {'pending': '3'},
      records: const [],
    ),
    'support' => AdminConsoleSection(
      key: key,
      title: title,
      total: 5,
      summary: const {'open': '5'},
      records: const [],
    ),
    'reports' => AdminConsoleSection(
      key: key,
      title: title,
      total: 0,
      summary: const {'open': '0'},
      records: const [],
    ),
    'moderation' => AdminConsoleSection(
      key: key,
      title: title,
      total: 23,
      hasMore: true,
      summary: const {'open': '11'},
      records: [
        for (var i = 1; i <= 6; i++)
          AdminRecord(
            id: 'case-$i',
            title: 'صورة تخالف سياسة الاحتشام',
            subtitle: 'منشور · أتيليه الورد',
            status: i.isEven ? 'OPEN' : 'ESCALATED',
            metrics: {'created_at': '2026-08-2$i'},
            raw: {'id': 'case-$i', 'status': 'OPEN'},
          ),
      ],
    ),
    'audit' => AdminConsoleSection(
      key: key,
      title: title,
      total: 5,
      records: [
        for (final (i, (t, sub)) in const [
          ('وثّقت سلمى بائعة جديدة', 'أتيليه الورد · دمشق'),
          ('أُغلقت تذكرة دعم', 'طلب استرجاع · #4821'),
          ('أُخفي منشور بعد بلاغ', 'بتلات المخمل'),
          ('عُدّلت نسبة عمولة', 'قسم العطور · من ٨٪ إلى ١٠٪'),
          ('تسجيل دخول من جهاز جديد', 'دمشق · Chrome'),
        ].indexed)
          AdminRecord(
            id: 'audit-$i',
            title: t,
            subtitle: sub,
            status: 'APPROVED',
            metrics: const {},
            raw: const {},
            createdAt: DateTime.now().subtract(Duration(minutes: 7 + i * 41)),
          ),
      ],
    ),
    _ => AdminConsoleSection(
      key: key,
      title: title,
      total: 6,
      records: [
        for (var i = 1; i <= 6; i++)
          AdminRecord(
            id: '$key-$i',
            title: 'وثّقت المشرِفة بائعة جديدة',
            subtitle: 'أتيليه الورد · دمشق',
            status: 'APPROVED',
            metrics: const {},
            raw: const {},
          ),
      ],
    ),
  });

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
          units: 97,
        ),
        AnalyticsRankedItem(
          title: 'عطر زهر المخمل',
          value: 57060000,
          units: 134,
        ),
        AnalyticsRankedItem(
          title: 'حقيبة كتف صغيرة مبطّنة',
          value: 44280000,
          units: 76,
        ),
      ],
      topSellers: const [
        AnalyticsRankedItem(
          title: 'أتيليه الورد',
          value: 184300000,
          units: 612,
        ),
        AnalyticsRankedItem(title: 'دار النور', value: 132400000, units: 448),
        AnalyticsRankedItem(title: 'بتلات المخمل', value: 97600000, units: 331),
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

  // The console's governance actions are exercised by
  // `admin_console_actions_test.dart`; this fake exists to paint pixels, so
  // every write is a no-op that simply must not throw.
  @override
  Future<Result<void>> updateUser(
    String id,
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> updateProduct(
    String id,
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> updateSupportTicket(
    String id,
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> updateModerationCase(
    String id,
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> updateReport(
    String id,
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> createCommissionRule(
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> updateCommissionLedger(
    String id,
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> upsertSystemSetting(
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<Map<String, dynamic>>> getSellerApplication(String id) async =>
      Success(_applications.first);

  @override
  Future<Result<void>> reviewSellerApplication(
    String id,
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> decideAccountVerification(
    String id,
    Map<String, dynamic> payload,
  ) async => const Success(null);
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
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final dir = Directory('build/visual')..createSync(recursive: true);
    final file = File('${dir.path}/$name.png')
      ..writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path}');
  });
}
