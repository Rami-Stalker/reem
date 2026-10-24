// «تقييمات من بمقاسي», pinned where it can silently drift.
//
// The matching, the band and the floors are the server's and are tested
// there — 8 unit tests and 6 integration tests against Postgres. What is
// worth pinning here is the client's half of the contract:
//
//   1. the decoders: a review written before fit existed must still decode;
//   2. the payloads: an emptied height must travel as null so it is cleared;
//   3. the fit panel and the card, which must draw the server's verdict and
//      nothing when there is none.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/reputation/data/datasources/reputation_remote_datasource.dart';
import 'package:reem/features/reputation/data/models/reputation_models.dart';
import 'package:reem/features/reputation/domain/entities/fit_entities.dart';
import 'package:reem/features/reputation/domain/repositories/reputation_repository.dart';
import 'package:reem/features/reputation/presentation/providers/reputation_provider.dart';
import 'package:reem/features/reputation/presentation/widgets/fit_labels.dart';
import 'package:reem/features/reputation/presentation/widgets/product_fit_panel.dart';
import 'package:reem/features/reputation/presentation/widgets/review_card.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;

final _ar = gen.lookupAppLocalizations(const Locale('ar'));

Map<String, dynamic> _review({Map<String, dynamic> extra = const {}}) => {
  'id': 'r-1',
  'user': {
    'id': 'u-1',
    'name': 'ليلى',
    'username': 'layla',
    'created_at': '2026-01-01T00:00:00.000Z',
  },
  'rating': 5,
  'title': 'حلو كتير',
  'body': 'القماش ثقيل',
  'verified_purchase': true,
  'status': 'approved',
  'helpful_count': 0,
  'created_at': '2026-10-20T10:00:00.000Z',
  ...extra,
};

Widget _app(Widget child, {ReputationRepository? repo}) => ProviderScope(
  overrides: [
    if (repo != null) reputationRepositoryProvider.overrideWithValue(repo),
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
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  group('decoding', () {
    test('a review written before fit existed decodes with none of it', () {
      final review = ReviewModel.fromJson(_review());
      expect(review.fit, isNull);
      expect(review.sizeBought, isNull);
      expect(review.photos, isEmpty);
      expect(review.hasFitFacts, isFalse);
    });

    test('a review with its fit facts', () {
      final review = ReviewModel.fromJson(
        _review(
          extra: {
            'fit': 'RUNS_SMALL',
            'size_bought': 'M',
            'photos': ['https://cdn/r1.jpg', 7, null],
          },
        ),
      );
      expect(review.fit, ReviewFit.runsSmall);
      expect(review.sizeBought, 'M');
      expect(review.photos, [
        'https://cdn/r1.jpg',
      ], reason: 'junk entries dropped');
      expect(review.hasFitFacts, isTrue);
    });

    test('an unknown fit is no fit, not a wrong one', () {
      expect(ReviewModel.fromJson(_review(extra: {'fit': 'SNUG'})).fit, isNull);
    });

    test('the fit summary decodes, with and without the "like you" half', () {
      final withProfile = productFitFromJson({
        'overall': {
          'runs_small': 1,
          'true_to_size': 4,
          'runs_large': 0,
          'total': 5,
          'enough': true,
          'verdict': 'TRUE_TO_SIZE',
        },
        'has_profile': true,
        'near_me': {
          'true_to_size': 2,
          'total': 2,
          'enough': false,
          'reviews_count': 3,
        },
        'suggested_size': 'L',
        'photos_count': 2,
      });
      expect(withProfile.overall.verdict, ReviewFit.trueToSize);
      expect(withProfile.nearMe?.enough, isFalse);
      expect(withProfile.nearMeReviews, 3);
      expect(withProfile.suggestedSize, 'L');

      final without = productFitFromJson({'overall': {}, 'near_me': null});
      expect(without.hasProfile, isFalse);
      expect(without.nearMe, isNull);
      expect(without.isEmpty, isTrue);
    });
  });

  group('payloads', () {
    test('saving the profile sends a cleared height as null', () {
      final json = const FitProfileDraft(usualSize: 'M').toJson();
      expect(json.containsKey('height_cm'), isTrue);
      expect(json['height_cm'], isNull);
      expect(json['usual_size'], 'M');
    });

    test('the fit half of a review sends only what she gave', () {
      expect(const ReviewFitDraft().toJson(), isEmpty);
      expect(
        const ReviewFitDraft(
          fit: ReviewFit.runsLarge,
          photoUrls: ['a'],
          shareFit: false,
        ).toJson(),
        {
          'fit': 'RUNS_LARGE',
          'photo_urls': ['a'],
          'share_fit': false,
        },
      );
    });
  });

  test('every fit has a label, an icon and a verdict sentence', () {
    for (final fit in ReviewFit.values) {
      expect(FitLabels.fit(_ar, fit), isNotEmpty);
      expect(FitLabels.verdict(_ar, fit), isNotEmpty);
      expect(FitLabels.icon(fit), isNotNull);
      expect(ReviewFit.fromWire(fit.wire), fit);
    }
  });

  group('drawing', () {
    testWidgets('the card shows how it fit and the size that shipped, nothing about her', (
      tester,
    ) async {
      final review = ReviewModel.fromJson(
        _review(
          extra: {
            'fit': 'TRUE_TO_SIZE',
            'size_bought': 'M',
          },
        ),
      );
      await tester.pumpWidget(_app(ReviewCard(review: review)));
      await tester.pumpAndSettle();

      expect(find.text(_ar.fitTrueToSize), findsOneWidget);
      expect(find.text(_ar.fitBoughtSize('M')), findsOneWidget);
      expect(find.textContaining('160'), findsNothing);
    });

    testWidgets(
      'the panel draws the verdict and the size women like her kept',
      (tester) async {
        final repo = _FakeFit(
          const ProductFit(
            overall: FitTally(
              trueToSize: 4,
              runsSmall: 1,
              total: 5,
              enough: true,
              verdict: ReviewFit.trueToSize,
            ),
            hasProfile: true,
            nearMe: FitTally(trueToSize: 2, total: 2),
            nearMeReviews: 2,
            suggestedSize: 'L',
          ),
        );
        await tester.pumpWidget(
          _app(const ProductFitPanel(productId: 'p-1'), repo: repo),
        );
        await tester.pumpAndSettle();

        expect(find.text(_ar.fitVerdictTrue), findsOneWidget);
        expect(find.text(_ar.fitLikeYou(2)), findsOneWidget);
        expect(find.text(_ar.fitSuggestedSize('L')), findsOneWidget);
      },
    );

    testWidgets('below the floor there are counts and no verdict', (
      tester,
    ) async {
      final repo = _FakeFit(
        const ProductFit(overall: FitTally(runsSmall: 2, total: 2)),
      );
      await tester.pumpWidget(
        _app(const ProductFitPanel(productId: 'p-1'), repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text(_ar.fitVerdictSmall), findsNothing);
      expect(find.text(_ar.fitOpinionsDiffer), findsNothing);
      expect(
        find.text(_ar.fitSeeLikeYou),
        findsOneWidget,
        reason: 'no profile yet',
      );
    });

    testWidgets('nothing at all for a piece nobody has spoken about', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ProductFitPanel(productId: 'p-1'),
          repo: const _FakeFit(ProductFit()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_ar.fitPanelTitle), findsNothing);
    });
  });
}

/// Serves one fit summary and an empty profile; nothing else is asked.
class _FakeFit implements ReputationRepository {
  const _FakeFit(this.fit);

  final ProductFit fit;

  @override
  Future<Result<ProductFit>> getProductFit(String productId) async =>
      Success(fit);

  @override
  Future<Result<FitProfile>> getFitProfile() async =>
      const Success(FitProfile());

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future.value(const Error<Never>(ServerFailure('not used in this test')));
}
