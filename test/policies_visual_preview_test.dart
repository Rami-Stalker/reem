// Renders the policy surfaces to PNGs so they can be eyeballed without a
// device — the centre, one policy, and the consent gate. Not an assertion
// test; it writes `build/visual/policies_*.png`.
//
//   flutter test test/policies_visual_preview_test.dart
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/policies/domain/entities/admin_policy.dart';
import 'package:ohara/features/policies/domain/entities/policy_document.dart';
import 'package:ohara/features/policies/presentation/providers/admin_policies_provider.dart';
import 'package:ohara/features/policies/presentation/providers/policies_provider.dart';
import 'package:ohara/features/policies/presentation/screens/admin_policies_screen.dart';
import 'package:ohara/features/policies/presentation/screens/policy_centre_screen.dart';
import 'package:ohara/features/policies/presentation/screens/policy_consent_screen.dart';
import 'package:ohara/features/policies/presentation/screens/policy_detail_screen.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  // One test per capture, not a loop: a second tree in the same test leaves a
  // timer pending at teardown and the whole test fails after the PNGs have
  // already been written. Same reason as the seller-application preview.
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the policy centre in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1125, 2000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_Preview(themeMode: mode, start: _centre));
      await tester.pump(const Duration(milliseconds: 400));
      await _capture(tester, 'policies_centre_${mode.name}');
    });
  }

  testWidgets('renders one policy, with its history', (tester) async {
    tester.view.physicalSize = const Size(1125, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_Preview(themeMode: ThemeMode.light, start: _doc));
    await tester.pump(const Duration(milliseconds: 400));
    await _capture(tester, 'policies_detail_light');
  });

  testWidgets('renders the console policy desk', (tester) async {
    // Wider than a phone: this is the console, and it is operated on a laptop.
    tester.view.physicalSize = const Size(2400, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_Preview(themeMode: ThemeMode.light, start: _admin));
    await tester.pump(const Duration(milliseconds: 400));
    await _capture(tester, 'policies_admin_desk');
  });

  testWidgets('renders the consent gate', (tester) async {
    tester.view.physicalSize = const Size(1125, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _Preview(themeMode: ThemeMode.light, start: _consent),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await _capture(tester, 'policies_consent_gate');
  });
}

const _centre = RoutePaths.policies;
const _doc = '/policies/doc/returns';
const _consent = '/preview-consent';
const _admin = '/preview-admin';

/// See `media_picker_visual_preview_test.dart` — `toImage` must be awaited
/// outside the fake-async zone or the next pump never returns.
Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final dir = Directory('build/visual')..createSync(recursive: true);
    final file = File('${dir.path}/$name.png')
      ..writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path}');
  });
}

class _Preview extends StatelessWidget {
  _Preview({required this.themeMode, required this.start});

  final ThemeMode themeMode;
  final String start;

  late final GoRouter _router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: RoutePaths.policies,
        builder: (_, _) => const PolicyCentreScreen(),
      ),
      GoRoute(
        path: RoutePaths.policyDetail,
        builder: (_, state) => PolicyDetailScreen(
          slug: state.pathParameters['slug'] ?? '',
        ),
      ),
      // The gate has no route in the app — `AppChrome` renders it instead of
      // the navigator — so the preview gives it one to stand on.
      GoRoute(
        path: _consent,
        builder: (_, _) => PolicyConsentScreen(pending: [_policies[1]]),
      ),
      // A bare `Scaffold` rather than `AdminShell`: the rail is the console's
      // own chrome and what wants eyeballing here is the desk. The Scaffold is
      // not decoration — like every other console section screen this one is a
      // plain scroll view and expects the shell to provide the Material its
      // switches and dropdowns need.
      GoRoute(
        path: _admin,
        builder: (_, _) => const Scaffold(body: AdminPoliciesScreen()),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        policyCatalogueProvider.overrideWith((ref, locale) async => _policies),
        policyDetailProvider.overrideWith((ref, args) async => _detail),
        requiredPoliciesProvider.overrideWith(
          (ref, args) async => [_policies[1]],
        ),
        adminPoliciesProvider.overrideWith((ref) async => _adminDocuments),
        adminPolicyConsentProvider.overrideWith((ref) async => _adminConsent),
      ],
      child: MaterialApp.router(
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
        routerConfig: _router,
        builder: (context, child) =>
            RepaintBoundary(key: _captureKey, child: child),
      ),
    );
  }
}

final _signedOn = DateTime(2026, 9, 2);

/// Four of the eight, in the three states a card can be in: signed on the
/// current version, signed on an older one, and never signed.
final _policies = <PolicySummary>[
  PolicySummary(
    id: 'doc-customer-terms',
    kind: PolicyKind.customerTerms,
    slug: 'customer-terms',
    audience: PolicyAudience.customer,
    title: 'شروط استخدام العميل',
    summary: 'حقوقك والتزاماتك كمشترية على أوهارا: الحساب، الطلب، الدفع، الإلغاء.',
    versionId: 'v-customer-terms-1',
    version: 1,
    requiredForConsent: true,
    icon: 'terms',
    effectiveAt: DateTime(2026, 9, 1),
    acceptance: PolicyAcceptanceStamp(
      versionId: 'v-customer-terms-1',
      version: 1,
      acceptedAt: _signedOn,
      isCurrent: true,
    ),
  ),
  PolicySummary(
    id: 'doc-privacy',
    kind: PolicyKind.privacy,
    slug: 'privacy',
    audience: PolicyAudience.everyone,
    title: 'سياسة الخصوصية',
    summary: 'ما الذي نجمعه من بياناتك، ولماذا، ومع من نشاركه، وكيف تتحكمين به.',
    versionId: 'v-privacy-2',
    version: 2,
    requiredForConsent: true,
    icon: 'privacy',
    effectiveAt: DateTime(2026, 9, 14),
    changeNote: 'توضيح مدة الاحتفاظ بصور البحث البصري',
    acceptance: PolicyAcceptanceStamp(
      versionId: 'v-privacy-1',
      version: 1,
      acceptedAt: _signedOn,
      isCurrent: false,
    ),
  ),
  PolicySummary(
    id: 'doc-returns',
    kind: PolicyKind.returns,
    slug: 'returns',
    audience: PolicyAudience.everyone,
    title: 'سياسة الإرجاع والاستبدال',
    summary: 'سبعة أيام من الاستلام، ومن يتحمّل الأجور، وكيف يعود المبلغ إليك.',
    versionId: 'v-returns-1',
    version: 1,
    requiredForConsent: false,
    icon: 'returns',
    effectiveAt: DateTime(2026, 9, 1),
  ),
  PolicySummary(
    id: 'doc-seller-terms',
    kind: PolicyKind.sellerTerms,
    slug: 'seller-terms',
    audience: PolicyAudience.seller,
    title: 'شروط استخدام البائع',
    summary: 'شروط فتح متجر على أوهارا: التوثيق، البضاعة، التجهيز، المستحقات.',
    versionId: 'v-seller-terms-1',
    version: 1,
    requiredForConsent: true,
    icon: 'storefront',
    effectiveAt: DateTime(2026, 9, 1),
  ),
];

/// Two documents in the two states the desk has to distinguish: one with an
/// open draft waiting to be published, one with nothing but a live version.
final _adminDocuments = <AdminPolicyDocument>[
  AdminPolicyDocument(
    id: 'doc-customer-terms',
    kind: 'CUSTOMER_TERMS',
    slug: 'customer-terms',
    audience: 'CUSTOMER',
    requiredForConsent: true,
    isActive: true,
    sortOrder: 10,
    acceptanceCount: 1284,
    icon: 'terms',
    versions: [
      AdminPolicyVersion(
        id: 'v-ct-2',
        version: 2,
        status: AdminPolicyStatus.draft,
        requiresReacceptance: false,
        changeNote: 'توضيح بند رفض الاستلام',
        translations: const [
          AdminPolicyTranslation(
            locale: 'ar',
            title: 'شروط استخدام العميل',
            summary: 'حقوقك والتزاماتك كمشترية على أوهارا.',
            body: '## من نحن. منصة تسوّق اجتماعية نسائية.',
          ),
        ],
      ),
      AdminPolicyVersion(
        id: 'v-ct-1',
        version: 1,
        status: AdminPolicyStatus.published,
        requiresReacceptance: false,
        publishedAt: DateTime(2026, 9, 1),
        effectiveAt: DateTime(2026, 9, 1),
        changeNote: 'الإصدار الأول',
        translations: const [
          AdminPolicyTranslation(
            locale: 'ar',
            title: 'شروط استخدام العميل',
            summary: 'حقوقك والتزاماتك كمشترية على أوهارا.',
            body: '## من نحن. منصة تسوّق اجتماعية نسائية.',
          ),
        ],
      ),
    ],
  ),
  AdminPolicyDocument(
    id: 'doc-commissions',
    kind: 'COMMISSIONS',
    slug: 'commissions',
    audience: 'SELLER',
    requiredForConsent: true,
    isActive: true,
    sortOrder: 50,
    acceptanceCount: 96,
    icon: 'commission',
    versions: [
      AdminPolicyVersion(
        id: 'v-co-1',
        version: 1,
        status: AdminPolicyStatus.published,
        requiresReacceptance: false,
        publishedAt: DateTime(2026, 9, 1),
        effectiveAt: DateTime(2026, 9, 1),
        changeNote: 'الإصدار الأول',
        translations: const [
          AdminPolicyTranslation(
            locale: 'ar',
            title: 'سياسة العمولات',
            summary: 'كم تأخذ المنصة، وعلى ماذا تُحتسب.',
            body: '## ما هي العمولة. حصة المنصة من كل بيع.',
          ),
        ],
      ),
    ],
  ),
];

const _adminConsent = <AdminPolicyConsentStat>[
  AdminPolicyConsentStat(
    documentId: 'doc-customer-terms',
    slug: 'customer-terms',
    version: 1,
    requiresReacceptance: false,
    acceptedCurrent: 1284,
    acceptedAnyVersion: 1284,
  ),
  AdminPolicyConsentStat(
    documentId: 'doc-commissions',
    slug: 'commissions',
    version: 1,
    requiresReacceptance: false,
    acceptedCurrent: 96,
    acceptedAnyVersion: 96,
  ),
];

final _detail = PolicyDetail(
  summary: _policies[2],
  body: '''
## المهلة

يحقّ لك طلب إرجاع المنتج **خلال 7 أيام من تاريخ تسليم الطرد إليك**. تُحتسب المهلة من لحظة التسليم المسجّلة في التطبيق.

## شروط قبول الإرجاع

- أن يكون المنتج بحالته الأصلية، غير مستعمل، وبكامل ملحقاته وبطاقاته وتغليفه.
- أن يُطلَب الإرجاع من صفحة الطلب داخل التطبيق، لا عبر البائعة مباشرة.
- أن يُرفَق دليل مصوَّر عندما يكون سبب الطلب عيبًا أو خطأ في الإرسال.

## المسار الزمني

1. تفتحين طلب الإرجاع من صفحة الطلب وتختارين السبب والكمية.
2. تردّ البائعة بالقبول أو الرفض **خلال 48 ساعة**.
3. عند القبول تُرتَّب إعادة الطرد، ويُفحَص عند الاستلام.

| المرحلة | المهلة |
| --- | --- |
| ردّ البائعة | 48 ساعة |
| صرف المبلغ | 3 أيام عمل |
''',
  contentHash: '8687a21a9a40',
  availableLocales: const ['ar', 'en'],
  history: [
    PolicyVersionRef(
      id: 'v-returns-1',
      version: 1,
      isCurrent: true,
      effectiveAt: DateTime(2026, 9, 1),
      changeNote: 'الإصدار الأول',
    ),
  ],
);
