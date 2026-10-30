// The reviews at the foot of a product page.
//
// What the client reported as "reviews don't work": the page offered
// «اكتبي» to everyone and refused only after the whole form was filled in —
// reviews are for women who received the piece — and on an ordinary phone the
// heading row and each review's star row overflowed. Pinned here: the action
// is decided before she writes, and the section lays out at phone width.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_reviews_section.dart';
import 'package:ohara/features/reputation/data/models/reputation_models.dart';
import 'package:ohara/features/reputation/domain/entities/fit_entities.dart';
import 'package:ohara/features/reputation/domain/entities/reputation_entities.dart';
import 'package:ohara/features/reputation/domain/repositories/reputation_repository.dart';
import 'package:ohara/features/reputation/presentation/providers/reputation_provider.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _ar = gen.lookupAppLocalizations(const Locale('ar'));

Map<String, dynamic> _review(String id, String name, int rating) => {
  'id': id,
  'user': {
    'id': 'u-$id',
    'name': name,
    'username': 'u$id',
    'created_at': '2026-01-01T00:00:00.000Z',
  },
  'rating': rating,
  'title': 'تجربة ممتازة',
  'body': 'الجودة ممتازة والسعر مناسب',
  'verified_purchase': true,
  'status': 'approved',
  'helpful_count': 0,
  'created_at': '2026-10-20T10:00:00.000Z',
};

class _Repo implements ReputationRepository {
  _Repo(this.eligibility);

  final Map<String, dynamic> eligibility;

  @override
  Future<Result<ReviewEligibility>> getProductReviewEligibility(
    String productId,
  ) async => Success(reviewEligibilityFromJson(eligibility));

  @override
  Future<Result<List<ReviewEntity>>> getProductReviews(
    String productId, {
    ReviewFilter filter = ReviewFilter.all,
  }) async => Success([
    ReviewModel.fromJson(_review('1', 'فرح الخطيب', 5)),
    ReviewModel.fromJson(_review('2', 'سُها ناصر', 2)),
  ]);

  @override
  Future<Result<ProductFit>> getProductFit(String productId) async =>
      const Success(ProductFit(overall: FitTally()));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, Map<String, dynamic> eligibility) async {
  // An ordinary phone: 390dp wide.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reputationRepositoryProvider.overrideWithValue(_Repo(eligibility)),
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
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(DsSpacing.lg),
                sliver: SliverList.list(
                  children: const [
                    ProductReviewsSection(
                      productId: 'p-1',
                      rating: 3.5,
                      reviewsCount: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a woman who received the piece is offered the review', (
    tester,
  ) async {
    await _pump(tester, {'can_review': true, 'reason': null});
    expect(find.text(_ar.reviewsWriteAction), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'nothing overflows');
  });

  testWidgets('a guest is asked to sign in, not handed the form', (
    tester,
  ) async {
    await _pump(tester, {'can_review': false, 'reason': 'sign_in'});
    expect(find.text(_ar.reviewsSignInToWrite), findsOneWidget);
    expect(find.text(_ar.reviewsWriteAction), findsNothing);
  });

  testWidgets('before it arrives she is told when she can review', (
    tester,
  ) async {
    await _pump(tester, {'can_review': false, 'reason': 'not_delivered'});
    expect(find.text(_ar.reviewsAfterDeliveryTitle), findsOneWidget);
    expect(find.text(_ar.reviewsWriteAction), findsNothing);
  });

  testWidgets('after reviewing she sees where her review stands', (
    tester,
  ) async {
    await _pump(tester, {
      'can_review': false,
      'reason': 'already_reviewed',
      'review': {..._review('9', 'مها', 4), 'status': 'pending'},
    });
    expect(find.text(_ar.reviewsYoursPendingTitle), findsOneWidget);
    expect(find.text(_ar.reviewsWriteAction), findsNothing);
  });

  testWidgets('the reviews themselves are listed, with the real stars', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, {'can_review': true, 'reason': null});
    expect(find.text('فرح الخطيب'), findsOneWidget);
    expect(find.text('سُها ناصر'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(_ar.reviewsRatedOutOfFive(2)))),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
