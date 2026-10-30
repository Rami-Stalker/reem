// The screen behind the profile row that used to say "coming soon".
//
// Renders her reviews in both themes plus the empty state, and asserts that
// each row names what it is about — a list of bare star ratings would tell her
// nothing about which review she is looking at.
//
//   flutter test test/my_reviews_visual_preview_test.dart
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
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/reputation/domain/entities/reputation_entities.dart';
import 'package:ohara/features/reputation/domain/repositories/reputation_repository.dart';
import 'package:ohara/features/reputation/presentation/providers/reputation_provider.dart';
import 'package:ohara/features/reputation/presentation/screens/my_reviews_screen.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

final _reviews = MyReviews(
  count: 3,
  average: 3.7,
  reviews: [
    AuthoredReview(
      id: 'r-1',
      rating: 5,
      isAboutProduct: true,
      subject: const ReviewSubject(id: 'p-1', title: 'فستان سهرة مطرّز'),
      createdAt: DateTime(2026, 8, 30, 12),
      body: 'أجمل مما توقّعت، والتطريز نظيف جداً.',
      status: 'approved',
      verifiedPurchase: true,
      sellerReply: 'يسعدنا ذلك — نورتِ.',
    ),
    AuthoredReview(
      id: 'r-2',
      rating: 3,
      isAboutProduct: false,
      subject: const ReviewSubject(id: 's-1', title: 'أتيليه لجين'),
      createdAt: DateTime(2026, 8, 24, 9),
      body: 'التوصيل تأخّر يومين عن الموعد.',
      status: 'approved',
    ),
    // Still with a moderator. Hiding it would look like the app had lost it.
    AuthoredReview(
      id: 'r-3',
      rating: 4,
      isAboutProduct: true,
      subject: const ReviewSubject(id: 'p-2', title: 'شال حرير'),
      createdAt: DateTime(2026, 8, 20, 17),
      body: 'الخامة ممتازة.',
      status: 'pending',
    ),
  ],
);

void _stubPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
}

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

  setUpAll(() async {
    _stubPlatformChannels();
    await _loadFonts();
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders her reviews in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reputationRepositoryProvider
                .overrideWithValue(_FakeReputation(_reviews)),
          ],
          child: _Preview(themeMode: mode),
        ),
      );
      await _settle(tester);

      // Each row names its subject, and a shop review says it is one.
      expect(find.text('فستان سهرة مطرّز'), findsOneWidget);
      expect(find.text('أتيليه لجين'), findsOneWidget);
      expect(find.text('عن المتجر'), findsOneWidget);

      // The two figures her profile already displayed.
      expect(find.text('3 تقييمات'), findsOneWidget);
      expect(find.text('3.7'), findsOneWidget);

      // The boutique's answer is the half she came back for.
      expect(find.text('ردّ المتجر'), findsOneWidget);

      await _capture(tester, 'my_reviews_${mode.name}');

      // A review with a moderator says so rather than looking lost. It is
      // the last of the three, below the mirror's fold, so scroll to it.
      await tester.scrollUntilVisible(
        find.text('عم تنراجع'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('عم تنراجع'), findsOneWidget);
    });
  }

  testWidgets('having written nothing points her at her orders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reputationRepositoryProvider
              .overrideWithValue(const _FakeReputation(MyReviews())),
        ],
        child: const _Preview(themeMode: ThemeMode.light),
      ),
    );
    await _settle(tester);

    expect(find.text('لسّا ما كتبتِ ولا تقييم'), findsOneWidget);
    // A review starts from a delivered parcel, so that is where she is sent.
    expect(find.text('ورجيني طلباتي'), findsOneWidget);

    await _capture(tester, 'my_reviews_empty');
  });
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

class _Preview extends StatelessWidget {
  const _Preview({required this.themeMode});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/my-reviews',
      routes: [
        GoRoute(
          path: '/my-reviews',
          builder: (_, _) => RepaintBoundary(
            key: _captureKey,
            child: const MyReviewsScreen(),
          ),
        ),
      ],
    );

    return MaterialApp.router(
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
      routerConfig: router,
    );
  }
}

class _FakeReputation implements ReputationRepository {
  const _FakeReputation(this.reviews);

  final MyReviews reviews;

  @override
  Future<Result<MyReviews>> getMyReviews() async => Success(reviews);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future.value(const Error<Never>(ServerFailure('not used in this test')));
}
