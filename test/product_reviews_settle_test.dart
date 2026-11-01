// The reviews on a product page settle: into the reviews, into «ما في تقييمات
// لسّا», or into an error she can retry — never into a spinner that stays.
//
// The spinner that stayed was Riverpod's automatic retry: a failed read was
// rebuilt up to ten times, loading all the while, so the error never showed.
// The app switches it off (`noProviderRetry`); these tests run with the same
// setting and pin each of the three ends.
//
//   flutter test test/product_reviews_settle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_reviews_section.dart';
import 'package:ohara/features/reputation/domain/entities/fit_entities.dart';
import 'package:ohara/features/reputation/domain/entities/reputation_entities.dart';
import 'package:ohara/features/reputation/presentation/providers/reputation_provider.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;
import 'package:ohara/l10n/app_localizations_ar.dart';
import 'package:ohara/main.dart' show noProviderRetry;

const _id = 'p-1';
const _all = (productId: _id, filter: ReviewFilter.all);
final _l10n = AppLocalizationsAr();

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => call.method == 'readAll' ? <String, String>{} : null,
      );
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      retry: noProviderRetry,
      overrides: [
        productFitProvider(_id).overrideWith((ref) async => const ProductFit()),
        productReviewEligibilityProvider(
          _id,
        ).overrideWith((ref) async => const ReviewEligibility(canReview: false)),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: L10nSetup.supportedLocales,
        localizationsDelegates: const [
          gen.AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ProductReviewsSection(productId: _id),
          ),
        ),
      ),
    ),
  );
  // Long enough for the default retry schedule to have kicked in, had it
  // been left on.
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the app does not retry failed providers behind a spinner', () {
    expect(noProviderRetry(0, Exception('offline')), isNull);
  });

  testWidgets('no reviews says so', (tester) async {
    await _pump(tester, [
      productReviewsProvider(_all).overrideWith((ref) async => const []),
    ]);
    expect(find.text(_l10n.reviewsNoneTitle), findsOneWidget);
    expect(find.byType(DsShimmer), findsNothing);
  });

  testWidgets('reviews are listed', (tester) async {
    await _pump(tester, [
      productReviewsProvider(_all).overrideWith(
        (ref) async => [
          ReviewEntity(
            id: 'r-1',
            user: User(
              id: 'u-1',
              name: 'ريم',
              username: 'reem',
              phone: '',
              createdAt: DateTime(2026),
            ),
            rating: 5,
            body: 'القماش أحلى من الصورة.',
            status: 'approved',
            createdAt: DateTime(2026, 10, 1),
          ),
        ],
      ),
    ]);
    expect(find.text('القماش أحلى من الصورة.'), findsOneWidget);
    expect(find.text(_l10n.reviewsNoneTitle), findsNothing);
  });

  testWidgets('a failed read shows the error and a retry', (tester) async {
    await _pump(tester, [
      productReviewsProvider(
        _all,
      ).overrideWith((ref) async => throw 'تعذّر الاتصال'),
    ]);
    expect(find.text(_l10n.reviewsUnavailable), findsOneWidget);
    expect(find.text(_l10n.retry), findsOneWidget);
    expect(find.byType(DsShimmer), findsNothing);
  });
}
