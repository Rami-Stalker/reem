import assert from 'node:assert/strict';
import test from 'node:test';
import {
  TrendInsightAudience,
  TrendInsightKind,
  TrendInsightSeverity,
  TrendStage,
} from '@prisma/client';
import {
  ProductRuleInput,
  attributeFindings,
  categoryFindings,
  growthPct,
  productFindings,
  render,
  searchFindings,
} from './insight-rules';
import { DemandDay, emptyDemandDay, scoreTrend } from './trend-score';

function series(
  length: number,
  shape: (index: number) => Partial<DemandDay>,
): DemandDay[] {
  return Array.from({ length }, (_, index) => ({
    ...emptyDemandDay(new Date(Date.UTC(2026, 0, 1 + index)).toISOString().slice(0, 10)),
    inStock: true,
    stockUnits: 40,
    ...shape(index),
  }));
}

function productInput(
  overrides: Partial<ProductRuleInput> = {},
  shape: (index: number) => Partial<DemandDay> = () => ({}),
): ProductRuleInput {
  return {
    productId: 'p1',
    title: 'حقيبة سوداء',
    categoryId: 'c1',
    categoryNameAr: 'الحقائب',
    sellerId: 's1',
    windowDays: 7,
    score: scoreTrend(series(14, shape), 7, { medianUnits: 20, p75Units: 60 }),
    previousScore: null,
    stockUnits: 40,
    priceSyp: 120_000,
    categoryMedianPriceSyp: 100_000,
    peerViewToOrderRate: 0.04,
    forecast: null,
    ...overrides,
  };
}

const kinds = (findings: { kind: TrendInsightKind }[]) =>
  findings.map((finding) => finding.kind);

// ── The rules stay quiet ────────────────────────────────────────────────

test('an ordinary product produces no insights at all', () => {
  // The failure mode of an insight feed is fifty rows a morning.
  const findings = productFindings(
    productInput({}, () => ({ views: 40, cartAdds: 3, orders: 2, units: 2 })),
  );
  assert.deepEqual(findings, []);
});

test('a product with almost no traffic produces nothing, however extreme its ratios', () => {
  const findings = productFindings(
    productInput({}, (i) => ({ views: i === 13 ? 4 : 0 })),
  );
  assert.deepEqual(findings, []);
});

// ── The rules fire when they should ─────────────────────────────────────

test('high views and no orders is reported, with the numbers behind it', () => {
  const findings = productFindings(
    productInput({ peerViewToOrderRate: 0.04 }, () => ({ views: 30, cartAdds: 2 })),
  );
  const finding = findings.find(
    (f) => f.kind === TrendInsightKind.HIGH_VIEW_NO_SALES,
  );
  assert.ok(finding, `expected the rule to fire; got ${kinds(findings)}`);
  assert.equal(finding.metrics.orders, 0);
  assert.equal(finding.metrics.views, 210);
  assert.equal(finding.severity, TrendInsightSeverity.WARNING);
});

test('conversion is judged against category peers, not against an absolute', () => {
  const shape = () => ({ views: 40, cartAdds: 3, orders: 1, units: 1 });
  const behind = productFindings(
    productInput({ peerViewToOrderRate: 0.2 }, shape),
  );
  const level = productFindings(
    productInput({ peerViewToOrderRate: 0.03 }, shape),
  );

  assert.ok(kinds(behind).includes(TrendInsightKind.LOW_CONVERSION));
  assert.ok(
    !kinds(level).includes(TrendInsightKind.LOW_CONVERSION),
    'the same product is fine in a low-converting category',
  );
});

test('an emerging product is surfaced as an opportunity before it sells', () => {
  const findings = productFindings(
    productInput({}, (i) => ({
      views: i < 7 ? 8 : 40 + (i - 7) * 35,
      searchHits: i < 7 ? 2 : 10 + (i - 7) * 8,
      cartAdds: i < 7 ? 1 : 3 + (i - 7) * 3,
      orders: i >= 12 ? 1 : 0,
      units: i >= 12 ? 1 : 0,
    })),
  );
  const finding = findings.find(
    (f) => f.kind === TrendInsightKind.EMERGING_PRODUCT,
  );
  assert.ok(finding, `got ${kinds(findings)}`);
  assert.equal(finding.severity, TrendInsightSeverity.OPPORTUNITY);
  assert.equal(finding.audience, TrendInsightAudience.SELLER);
});

test('an imminent stock-out on a selling product is CRITICAL, and only with a forecast', () => {
  const shape = () => ({ views: 80, cartAdds: 10, orders: 6, units: 8 });
  const withForecast = productFindings(
    productInput(
      {
        stockUnits: 4,
        forecast: {
          horizonDays: 7,
          totalUnits: 40,
          confidence: 0.7,
          stockoutInDays: 1.5,
        },
      },
      shape,
    ),
  );
  const finding = withForecast.find((f) => f.kind === TrendInsightKind.STOCK_RISK);
  assert.ok(finding);
  assert.equal(finding.severity, TrendInsightSeverity.CRITICAL);

  const withoutForecast = productFindings(
    productInput({ stockUnits: 4, forecast: null }, shape),
  );
  assert.ok(
    !kinds(withoutForecast).includes(TrendInsightKind.STOCK_RISK),
    'no forecast, no stock-out claim',
  );
});

test('a sold-out product with climbing demand is an opportunity, not a warning', () => {
  const findings = productFindings(
    productInput({ stockUnits: 0 }, (i) => ({
      views: i < 7 ? 20 : 120,
      searchHits: i < 7 ? 4 : 30,
      cartAdds: i < 7 ? 2 : 12,
      inStock: false,
      stockUnits: 0,
    })),
  );
  const finding = findings.find(
    (f) => f.kind === TrendInsightKind.STOCK_OPPORTUNITY,
  );
  assert.ok(finding, `got ${kinds(findings)}`);
  assert.equal(finding.actionTarget, 'inventory');
});

test('a price finding needs a peer median, high views and weak cart-through together', () => {
  const shape = () => ({ views: 60, cartAdds: 1 });
  assert.ok(
    kinds(
      productFindings(
        productInput({ priceSyp: 300_000, categoryMedianPriceSyp: 100_000 }, shape),
      ),
    ).includes(TrendInsightKind.PRICE_OPPORTUNITY),
  );
  assert.ok(
    !kinds(
      productFindings(
        productInput({ priceSyp: 105_000, categoryMedianPriceSyp: 100_000 }, shape),
      ),
    ).includes(TrendInsightKind.PRICE_OPPORTUNITY),
    'a product priced at the median is not a price problem',
  );
});

// ── Audience routing ────────────────────────────────────────────────────

test('a finding with no seller is admin-only; with a seller it is hers', () => {
  const shape = () => ({ views: 40, cartAdds: 2 });
  const [platform] = productFindings(productInput({ sellerId: null }, shape));
  const [sellers] = productFindings(productInput({ sellerId: 's9' }, shape));
  assert.equal(platform.audience, TrendInsightAudience.ADMIN);
  assert.equal(platform.sellerId, undefined);
  assert.equal(sellers.audience, TrendInsightAudience.SELLER);
  assert.equal(sellers.sellerId, 's9');
});

test('the dedupe key separates audiences, kinds, subjects and windows', () => {
  const keys = new Set<string>();
  for (const windowDays of [7, 30]) {
    for (const sellerId of ['s1', null]) {
      const findings = productFindings(
        productInput({ windowDays, sellerId }, () => ({ views: 40, cartAdds: 2 })),
      );
      for (const finding of findings) keys.add(finding.dedupeKey);
    }
  }
  assert.equal(keys.size, 4, 'four distinct findings, four distinct keys');
});

// ── Category, attribute and search rules ────────────────────────────────

test('a category with climbing demand and empty shelves is an assortment gap', () => {
  const findings = categoryFindings({
    categoryId: 'c1',
    nameAr: 'الحقائب',
    windowDays: 7,
    score: scoreTrend(
      series(14, (i) => ({
        views: i < 7 ? 200 : 900,
        searchHits: i < 7 ? 30 : 140,
        cartAdds: i < 7 ? 15 : 70,
        orders: i < 7 ? 4 : 18,
        units: i < 7 ? 5 : 20,
      })),
      7,
    ),
    previousScore: 40,
    liveProducts: 30,
    inStockProducts: 9,
  });
  assert.ok(kinds(findings).includes(TrendInsightKind.ASSORTMENT_GAP));
  assert.ok(kinds(findings).includes(TrendInsightKind.CATEGORY_MOMENTUM));
});

test('an attribute is judged on share, so a busy week does not promote every colour', () => {
  // Volume doubled, but the share is unchanged — nothing happened to black.
  assert.deepEqual(
    attributeFindings({
      dimension: 'COLOR',
      value: 'black',
      labelAr: 'أسود',
      scopeKey: 'ALL',
      scopeLabelAr: null,
      windowDays: 7,
      current: 400,
      previous: 200,
      share: 0.3,
      previousShare: 0.3,
      orders: 40,
    }),
    [],
  );

  const shifted = attributeFindings({
    dimension: 'COLOR',
    value: 'black',
    labelAr: 'أسود',
    scopeKey: 'ALL',
    scopeLabelAr: null,
    windowDays: 7,
    current: 300,
    previous: 200,
    share: 0.34,
    previousShare: 0.22,
    orders: 40,
  });
  assert.deepEqual(kinds(shifted), [TrendInsightKind.COLOR_MOMENTUM]);
});

test('an attribute with too little volume behind it says nothing', () => {
  assert.deepEqual(
    attributeFindings({
      dimension: 'COLOR',
      value: 'lilac',
      labelAr: 'ليلكي',
      scopeKey: 'ALL',
      scopeLabelAr: null,
      windowDays: 7,
      current: 12,
      previous: 2,
      share: 0.5,
      previousShare: 0.1,
      orders: 0,
    }),
    [],
  );
});

test('a search term that misses often enough becomes unmet demand', () => {
  const findings = searchFindings({
    termKey: 'اخضر سهره فستان',
    display: 'فستان سهرة أخضر طويل',
    facetSummary: 'فستان · سهرة · أخضر',
    windowDays: 30,
    searches: 64,
    previousSearches: 20,
    zeroResults: 58,
    missRate: 58 / 64,
    clicks: 2,
    orders: 0,
    demandScore: 82,
    suggestedCategoryId: 'c-dresses',
  });
  const unmet = findings.find((f) => f.kind === TrendInsightKind.UNMET_DEMAND);
  assert.ok(unmet);
  assert.equal(unmet.severity, TrendInsightSeverity.CRITICAL);
  assert.equal(unmet.categoryId, 'c-dresses');
  assert.ok(kinds(findings).includes(TrendInsightKind.SEARCH_SURGE));
});

test('a well-served search term is not reported', () => {
  assert.deepEqual(
    searchFindings({
      termKey: 'حقيبه سوداء',
      display: 'حقيبة سوداء',
      facetSummary: 'حقيبة · أسود',
      windowDays: 30,
      searches: 120,
      previousSearches: 110,
      zeroResults: 3,
      missRate: 0.025,
      clicks: 90,
      orders: 22,
      demandScore: 12,
      suggestedCategoryId: null,
    }),
    [],
  );
});

// ── Rendering ───────────────────────────────────────────────────────────

test('every kind renders Arabic with no placeholder left behind', () => {
  const findings = [
    ...productFindings(
      productInput(
        {
          stockUnits: 2,
          forecast: { horizonDays: 7, totalUnits: 30, confidence: 0.8, stockoutInDays: 2 },
        },
        () => ({ views: 90, cartAdds: 20, orders: 2, units: 9, returns: 3, reviews: 6, ratingSum: 15 }),
      ),
    ),
    ...searchFindings({
      termKey: 'k',
      display: 'فستان سهرة أخضر',
      facetSummary: 'فستان · سهرة',
      windowDays: 30,
      searches: 50,
      previousSearches: 10,
      zeroResults: 45,
      missRate: 0.9,
      clicks: 1,
      orders: 0,
      demandScore: 90,
      suggestedCategoryId: null,
    }),
  ];
  assert.ok(findings.length >= 4, `only got ${kinds(findings)}`);

  for (const finding of findings) {
    const rendered = render(finding);
    assert.ok(rendered.titleAr.length > 0, `${finding.kind} has no title`);
    assert.ok(rendered.bodyAr.length > 10, `${finding.kind} has no body`);
    assert.ok(
      !/undefined|null|NaN|\{|\}/.test(rendered.titleAr + rendered.bodyAr),
      `${finding.kind} leaked a placeholder: ${rendered.bodyAr}`,
    );
    assert.ok(/[؀-ۿ]/.test(rendered.bodyAr), `${finding.kind} is not Arabic`);
  }
});

test('the rendering quotes only figures the finding actually carries', () => {
  const [finding] = productFindings(
    productInput({}, () => ({ views: 40, cartAdds: 2 })),
  );
  const rendered = render(finding);
  assert.ok(rendered.bodyAr.includes(String(finding.metrics.views)));
});

// ── Priority and growth ─────────────────────────────────────────────────

test('priority orders a confident critical above a speculative opportunity', () => {
  const critical = productFindings(
    productInput(
      {
        stockUnits: 1,
        forecast: { horizonDays: 7, totalUnits: 40, confidence: 0.9, stockoutInDays: 1 },
      },
      () => ({ views: 200, cartAdds: 30, orders: 20, units: 25 }),
    ),
  ).find((f) => f.kind === TrendInsightKind.STOCK_RISK);

  const opportunity = productFindings(
    productInput({}, (i) => ({
      views: i < 7 ? 8 : 40 + (i - 7) * 20,
      cartAdds: i < 7 ? 1 : 3,
      searchHits: i < 7 ? 2 : 9,
    })),
  ).find((f) => f.kind === TrendInsightKind.EMERGING_PRODUCT);

  assert.ok(critical && opportunity);
  assert.ok(critical.priority > opportunity.priority);
});

test('growth from zero is a finite, capped number', () => {
  assert.equal(growthPct(0, 0), 0);
  assert.ok(Number.isFinite(growthPct(500, 0)));
  assert.ok(growthPct(100_000, 0) <= 999);
  assert.ok(growthPct(0, 100) >= -99);
  // Smoothed, so the printed figure is (201/101 − 1), not a clean doubling.
  assert.equal(growthPct(200, 100), 99);
});
