// Renders the seller application to PNGs so the redesign can be eyeballed
// without a device. Not an assertion test — it writes
// `build/visual/seller_verification_*.png`. Behaviour lives in
// `seller_verification_test.dart`.
//
//   flutter test test/seller_verification_visual_preview_test.dart
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/auth/domain/repositories/auth_repository.dart';
import 'package:reem/features/auth/presentation/providers/auth_account_provider.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/screens/seller_verification_screen.dart';
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

/// `CachedNetworkImage` asks `path_provider` for a cache folder to draw the
/// store logo, and the auth interceptor asks secure storage for device headers.
/// Unstubbed, either exception lands mid-pump and the capture comes out blank.
void _stubPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => Directory.systemTemp.createTempSync('reem_test').path,
  );

  messenger.setMockMethodCallHandler(
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

  // One test per theme, not a loop: a second tree in the same test leaves a
  // timer pending at teardown and the whole test fails after both captures
  // have already been written.
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the seller application in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1125, 2100);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      // The returning applicant: a reviewer has asked for more, and her
      // documents are already attached. The blank first-time form is the less
      // interesting half.
      await tester.pumpWidget(_Preview(themeMode: mode));
      await tester.pump(const Duration(milliseconds: 400));
      await _capture(tester, 'seller_verification_${mode.name}');
    });
  }

  testWidgets('renders the documents section', (tester) async {
    tester.view.physicalSize = const Size(1125, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_Preview(themeMode: ThemeMode.light));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1400));
    await tester.pump(const Duration(milliseconds: 400));
    await _capture(tester, 'seller_verification_documents');
  });
}

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
  _Preview({required this.themeMode});

  final ThemeMode themeMode;

  late final GoRouter _router = GoRouter(
    initialLocation: '/seller-verification',
    routes: [
      GoRoute(
        path: '/seller-verification',
        builder: (_, _) => const SellerVerificationScreen(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_InertAuthRepository()),
        sellerVerificationProvider.overrideWith((ref) async => _application),
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

class _InertAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future.value(const Error<Never>(ServerFailure('preview')));
}

final _application = SellerVerification(
  id: 'app-1',
  status: 'needs_more_documents',
  businessName: 'أتيليه رهف',
  legalName: 'رهف محمود الشامي',
  businessCategory: 'أزياء نسائية',
  storeDescription:
      'فساتين سهرة وخطوبة مصمّمة يدوياً في قلب دمشق، بخامات مختارة وقصّات محتشمة.',
  storeLogoUrl: 'http://host/media/files/2026/08/logo.png',
  contactPhone: '+963931000101',
  contactEmail: 'rahaf@example.com',
  businessAddress: 'دمشق، المزة، شارع الجلاء',
  warehouseAddress: 'دمشق، المزة، مستودع رقم 3',
  commercialRegistration: 'CR-99120',
  governmentIdUrl:
      'http://host/media/11111111-1111-1111-1111-111111111111/file',
  businessLicenseUrl:
      'http://host/media/33333333-3333-3333-3333-333333333333/file',
  bankName: 'بنك بيمو السعودي الفرنسي',
  accountHolder: 'رهف محمود الشامي',
  iban: 'SY000000000000000001',
  shippingMethods: const ['مندوب', 'استلام من المتجر'],
  returnPolicy: 'الإرجاع خلال سبعة أيام بشرط بقاء القطعة كما هي مع بطاقتها.',
  productCategories: const ['فساتين', 'عبايات'],
  yearsExperience: 8,
  documentUrls: const [
    'http://host/media/22222222-2222-2222-2222-222222222222/file',
  ],
  reviewReason: 'نحتاج صورة أوضح للسجل التجاري',
  submittedAt: DateTime.utc(2026, 8, 20),
);
