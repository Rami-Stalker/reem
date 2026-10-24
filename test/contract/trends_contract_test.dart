// The Trend Engine's wire contract, checked against real server payloads.
//
// `test/fixtures/trends_*_overview.json` are verbatim captures of what
// `GET /trends/seller/overview` and `GET /trends/admin/overview` returned
// after the pipeline was run over the seeded shop — produced by
// `backend/prisma/demo/capture-trend-fixtures.ts`, through the same
// serializers the controller uses. So this fails if either side of the
// contract drifts: a renamed field, a Money shape that stops being
// `{amount, currency}`, a score that stops carrying its components.
//
// It also asserts the properties the whole feature rests on, and they are not
// cosmetic:
//
//   · every score arrives with the evidence for it,
//   · every insight arrives with the numbers its sentence was built from,
//   · a forecast that has nothing to say says so rather than drawing a zero.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/trends/data/models/trend_mappers.dart';
import 'package:ohara/features/trends/domain/entities/trend_entities.dart';

void main() {
  late Map<String, dynamic> sellerPayload;
  late Map<String, dynamic> adminPayload;

  setUpAll(() {
    sellerPayload =
        jsonDecode(
              File('test/fixtures/trends_seller_overview.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    adminPayload =
        jsonDecode(
              File('test/fixtures/trends_admin_overview.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  // ── The seller dashboard ────────────────────────────────────────────────

  group('the seller overview', () {
    late SellerTrendOverview overview;

    setUp(() => overview = TrendMappers.sellerOverview(sellerPayload));

    test('decodes the window it was computed for', () {
      expect(overview.window, TrendWindow.d7);
      expect(overview.window.days, 7);
      expect(overview.asOf.year, greaterThan(2020));
    });

    test('separates market demand from her own sales', () {
      // The distinction the whole page rests on: two sellers share a product
      // page, so the views on it are demand for the bag, and only the units
      // are hers. Collapsing them would have her read another shop's traffic
      // as her own performance.
      expect(overview.demandSignals.views, isNonNegative);
      expect(overview.headline.units, isNonNegative);
      expect(overview.headline.revenue?.currency.wire, anyOf('SYP', isNull));
    });

    test('every scored product carries the evidence for its score', () {
      final products = [
        ...overview.trending,
        ...overview.emerging,
        ...overview.lowConversion,
        ...overview.stockOpportunities,
      ];
      expect(products, isNotEmpty, reason: 'the fixture has no scored products');

      for (final product in products) {
        expect(product.productId, isNotEmpty);
        expect(product.title, isNotEmpty);
        expect(product.score, inInclusiveRange(0, 100));
        expect(product.confidence, inInclusiveRange(0, 1));

        // Nine components, each with the weight it contributes — shipped from
        // the server so a re-weighted kernel cannot leave the app describing
        // the old formula.
        expect(product.components, hasLength(9));
        final total = product.components.fold<double>(
          0,
          (sum, component) => sum + component.weight,
        );
        expect(total, closeTo(1, 1e-6));
        for (final component in product.components) {
          expect(component.key, isNotEmpty);
          expect(component.labelAr, isNotEmpty);
          expect(component.value, inInclusiveRange(0, 1));
        }

        expect(product.stage.labelAr, isNotEmpty);
      }
    });

    test('a money field is always a currency-tagged amount, never a bare number', () {
      for (final product in overview.trending) {
        for (final money in [product.mine.revenue, product.mine.price]) {
          if (money == null) continue;
          expect(money.currency, Currency.syp);
          expect(double.tryParse(money.raw), isNotNull, reason: money.raw);
        }
      }
    });

    test('the series is a complete calendar, oldest first', () {
      expect(overview.series, isNotEmpty);
      for (var i = 1; i < overview.series.length; i += 1) {
        expect(
          overview.series[i].date.isAfter(overview.series[i - 1].date),
          isTrue,
          reason: 'the daily series is out of order or has a duplicate day',
        );
      }
    });
  });

  // ── The admin dashboard ─────────────────────────────────────────────────

  group('the admin overview', () {
    late AdminTrendOverview overview;

    setUp(() => overview = TrendMappers.adminOverview(adminPayload));

    test('reports the platform with its window-over-window change', () {
      expect(overview.headline.views, greaterThan(0));
      expect(overview.headline.viewsGrowthPct, isNot(equals(0)));
      expect(overview.headline.stages, isNotEmpty);
      // Every stage the app can render is present, even at zero, so a chart
      // does not have to guess whether a missing key means none or unknown.
      for (final stage in TrendStage.values) {
        expect(
          overview.headline.stages.containsKey(stage.wire),
          isTrue,
          reason: 'no count reported for ${stage.wire}',
        );
      }
    });

    test('catches products climbing before they are best sellers', () {
      // The claim the engine exists for. The seeded shop plants a handful of
      // deliberate climbers; if the pipeline stops finding them this fails.
      expect(overview.emergingProducts, isNotEmpty);
      for (final product in overview.emergingProducts) {
        expect(product.stage.stage, TrendStage.emerging);
        expect(product.title, isNotEmpty);
        expect(product.components, hasLength(9));
      }
    });

    test('a facet trend carries share, not just growth', () {
      // Growth alone is a statement about the week. In a week when everything
      // is up forty percent, every colour is up forty percent.
      expect(overview.colourTrends, isNotEmpty);
      for (final colour in overview.colourTrends) {
        expect(colour.labelAr, isNotEmpty);
        expect(colour.sharePct, inInclusiveRange(0, 100));
        expect(colour.previousSharePct, inInclusiveRange(0, 100));
        expect(
          colour.shareDeltaPct,
          closeTo(colour.sharePct - colour.previousSharePct, 0.05),
        );
      }
      final shares = overview.colourTrends.fold<double>(
        0,
        (sum, colour) => sum + colour.sharePct,
      );
      expect(shares, lessThanOrEqualTo(100.5));
    });

    test('unmet demand is a specification, not a search string', () {
      expect(overview.unmetDemand, isNotEmpty);
      for (final signal in overview.unmetDemand) {
        expect(signal.display, isNotEmpty);
        expect(signal.searches, greaterThan(0));
        expect(signal.missRate, inInclusiveRange(0, 1));
        expect(signal.demandScore, inInclusiveRange(0, 100));
        // The sentence the buying team acts on.
        expect(signal.suggestionAr, isNotNull);
        expect(signal.suggestionAr, isNotEmpty);
      }
      // The exact case the feature was specified against.
      expect(
        overview.unmetDemand.any(
          (signal) => signal.display.contains('فستان سهرة أخضر'),
        ),
        isTrue,
        reason: 'the green evening dress gap is not being reported',
      );
    });

    test('a search term reports how often it missed, not just how often it ran', () {
      for (final term in overview.searchTrends) {
        expect(term.display, isNotEmpty);
        expect(term.searches, greaterThan(0));
        expect(term.missRate, inInclusiveRange(0, 1));
        expect(term.zeroResults, lessThanOrEqualTo(term.searches));
      }
    });
  });

  // ── Insights ────────────────────────────────────────────────────────────

  group('insights', () {
    test('every insight is Arabic prose over numbers it carries with it', () {
      final insights = [
        ...TrendMappers.adminOverview(adminPayload).insights,
        ...TrendMappers.sellerOverview(sellerPayload).recommendedActions,
      ];
      expect(insights, isNotEmpty, reason: 'the fixture has no insights');

      for (final insight in insights) {
        expect(insight.kind, isNotEmpty);
        expect(insight.titleAr, isNotEmpty);
        expect(insight.bodyAr.length, greaterThan(10));
        expect(
          RegExp(r'[؀-ۿ]').hasMatch(insight.bodyAr),
          isTrue,
          reason: '${insight.kind} is not Arabic: ${insight.bodyAr}',
        );
        // No template placeholder ever reaches a reader.
        expect(
          insight.bodyAr,
          isNot(matches(RegExp(r'undefined|null|NaN|\{|\}'))),
        );
        // The evidence under the sentence. Without it the card cannot show
        // its working, and a reader is asked to take the claim on faith.
        expect(insight.metrics, isNotEmpty, reason: insight.kind);
        expect(insight.confidence, inInclusiveRange(0, 1));
        expect(insight.priority, isNonNegative);
      }
    });

    test('with no model configured every insight says a template phrased it', () {
      // The fallback is a complete implementation, not a stub — and the row
      // records which renderer produced it, so the distinction is never
      // invisible to a reader or to an auditor.
      final insights = TrendMappers.adminOverview(adminPayload).insights;
      for (final insight in insights) {
        expect(insight.isTemplatePhrased, isTrue, reason: insight.narrator);
      }
    });

    test('an insight that prompts an action says what the action is', () {
      final insights = TrendMappers.adminOverview(adminPayload).insights;
      final actionable = insights.where((i) => i.actionAr != null);
      expect(actionable, isNotEmpty);
      for (final insight in actionable) {
        expect(insight.actionAr!.length, greaterThan(5));
      }
    });
  });

  // ── Forecast ────────────────────────────────────────────────────────────

  group('the forecast', () {
    test('names the method it used and how much to believe it', () {
      final forecast = TrendMappers.adminOverview(adminPayload).forecast;
      expect(forecast.horizonDays, greaterThan(0));
      expect(forecast.confidence, inInclusiveRange(0, 1));
      expect(forecast.method, isNotNull);
      expect(
        forecast.method,
        anyOf(
          'HOLT_DAMPED',
          'SEASONAL_NAIVE',
          'MOVING_AVERAGE',
          'INSUFFICIENT_DATA',
          'MODEL',
        ),
      );
    });

    test('every point is bounded by its own interval and never negative', () {
      final forecast = TrendMappers.adminOverview(adminPayload).forecast;
      for (final point in forecast.points) {
        expect(point.units, isNonNegative);
        expect(point.low, lessThanOrEqualTo(point.units));
        expect(point.high, greaterThanOrEqualTo(point.units));
        expect(point.low, isNonNegative);
      }
    });

    test('a forecast with nothing behind it reports as having no data', () {
      const empty = TrendForecast.empty;
      expect(empty.hasData, isFalse);
      // `INSUFFICIENT_DATA` is a real answer the UI is expected to say out
      // loud, not something to dress up as a confident zero.
      final parsed = TrendMappers.forecast(const {
        'horizon_days': 7,
        'total_units': 0,
        'confidence': 0,
        'method': 'INSUFFICIENT_DATA',
        'points': [],
      });
      expect(parsed.hasData, isFalse);
      expect(parsed.method, 'INSUFFICIENT_DATA');
    });
  });

  // ── The mappers themselves ──────────────────────────────────────────────

  group('the mappers', () {
    test('an absent section costs one panel, not the page', () {
      // Fifteen independent panels; one malformed field must not take the
      // whole dashboard down with it.
      final sparse = TrendMappers.adminOverview(const {});
      expect(sparse.headline.views, 0);
      expect(sparse.categoryTrends, isEmpty);
      expect(sparse.insights, isEmpty);
      expect(sparse.isEmpty, isTrue);

      final sparseSeller = TrendMappers.sellerOverview(const {});
      expect(sparseSeller.trending, isEmpty);
      expect(sparseSeller.isEmpty, isTrue);
    });

    test('a number sent as a string still parses', () {
      // SYP figures run into the millions and are sent as decimal strings; a
      // reader that only accepted JSON numbers would silently zero them.
      final forecast = TrendMappers.forecast(const {
        'horizon_days': '14',
        'total_units': '42.5',
        'confidence': '0.8',
        'points': [],
      });
      expect(forecast.horizonDays, 14);
      expect(forecast.totalUnits, 42.5);
      expect(forecast.confidence, 0.8);
    });

    test('an unknown stage renders as its label rather than as an enum name', () {
      final stage = TrendMappers.stage(const {
        'key': 'SOMETHING_NEW',
        'label_ar': 'حالة جديدة',
      });
      expect(stage.labelAr, 'حالة جديدة');
      expect(stage.stage, TrendStage.dormant);
    });
  });
}
