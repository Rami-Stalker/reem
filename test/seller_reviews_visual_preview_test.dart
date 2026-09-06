// Renders the seller's review desk to PNGs — the screen where she can finally
// answer what people say about her.
//
//   flutter test test/seller_reviews_visual_preview_test.dart
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
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/seller_reviews/domain/entities/seller_review.dart';
import 'package:reem/features/seller_reviews/domain/repositories/seller_reviews_repository.dart';
import 'package:reem/features/seller_reviews/presentation/providers/seller_reviews_provider.dart';
import 'package:reem/features/seller_reviews/presentation/screens/seller_reviews_screen.dart';
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
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (call) async => ['wifi'],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _stubPlatformChannels();
    await _loadFonts();
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the review desk in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_Preview(themeMode: mode));
      await _settle(tester);
      await _capture(tester, 'seller_reviews_${mode.name}');
    });
  }
}

class _Preview extends StatelessWidget {
  _Preview({required this.themeMode});

  final ThemeMode themeMode;

  late final GoRouter _router = GoRouter(
    initialLocation: '/seller/reviews',
    routes: [
      GoRoute(
        path: '/seller/reviews',
        builder: (_, _) => const SellerReviewsScreen(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sellerReviewsRepositoryProvider.overrideWithValue(
          const _FakeReviewsRepository(),
        ),
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

/// A shelf of reviews with something to say: an unanswered complaint, an
/// answered one, a shop review and a piece of praise — enough to judge the
/// ordering, the reply block and the two kinds of tag.
final class _FakeReviewsRepository implements SellerReviewsRepository {
  const _FakeReviewsRepository();

  static final _rows = [
    SellerReviewItem(
      id: '1',
      target: ReviewTarget.product,
      rating: 2,
      author: const ReviewAuthor(name: 'ليلى'),
      title: 'المقاس أصغر مما توقّعت',
      body: 'القماش جميل جداً لكن المقاس M جاء ضيّقاً عند الخصر.',
      verifiedPurchase: true,
      productTitle: 'فستان حرير بماء الورد',
      createdAt: DateTime(2026, 8, 28, 19, 20),
    ),
    SellerReviewItem(
      id: '2',
      target: ReviewTarget.seller,
      rating: 5,
      author: const ReviewAuthor(name: 'سارة'),
      body: 'تعامل راقٍ وتغليف أنيق، والتوصيل وصل قبل موعده.',
      verifiedPurchase: true,
      createdAt: DateTime(2026, 8, 27, 11, 5),
    ),
    SellerReviewItem(
      id: '3',
      target: ReviewTarget.product,
      rating: 4,
      author: const ReviewAuthor(name: 'رنا'),
      body: 'اللون أغمق قليلاً من الصورة، لكنه أجمل على الطبيعة.',
      productTitle: 'عباءة كتّان مطرّزة',
      reply: 'شكراً رنا — سنصوّر القطعة تحت إضاءة طبيعية لتظهر كما هي.',
      repliedAt: DateTime(2026, 8, 26, 9, 40),
      createdAt: DateTime(2026, 8, 25, 16, 30),
    ),
  ];

  @override
  Future<Result<SellerReviewDesk>> desk({bool unansweredOnly = false}) async =>
      Success(
        SellerReviewDesk(
          reviews: unansweredOnly
              ? _rows.where((row) => !row.isAnswered).toList()
              : _rows,
          unanswered: _rows.where((row) => !row.isAnswered).length,
        ),
      );

  @override
  Future<Result<SellerReviewItem>> reply(
    String reviewId,
    ReviewTarget target,
    String reply,
  ) async => Success(_rows.firstWhere((row) => row.id == reviewId));
}

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
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final dir = Directory('build/visual')..createSync(recursive: true);
    final file = File('${dir.path}/$name.png')
      ..writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path}');
  });
}
