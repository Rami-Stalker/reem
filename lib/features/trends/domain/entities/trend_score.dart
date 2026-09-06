import 'package:reem/core/shared/value_objects/money.dart';

/// The scored half of the Trend Engine: windows, stages, the nine
/// components of a score, and the products and facets they are computed for.
///
/// The rule these types exist to enforce: **a score always arrives with its
/// evidence.** The server sends the number, the components it was made of,
/// the raw window figures underneath those, and a confidence saying how much
/// of it to believe — and nothing here flattens that to the headline. A
/// seller told her product scores 63 is entitled to ask why, and the answer
/// has to be on the device already.

// ── Windows ──────────────────────────────────────────────────────────────

/// The look-back a score was computed over.
///
/// Three, because a seller deciding what to restock tonight and a merchandiser
/// planning next season are asking different questions of the same data.
enum TrendWindow {
  d7('D7', 7),
  d14('D14', 14),
  d30('D30', 30);

  const TrendWindow(this.wire, this.days);

  final String wire;
  final int days;

  static TrendWindow fromWire(String? value) => switch (value?.toUpperCase()) {
    'D14' => TrendWindow.d14,
    'D30' => TrendWindow.d30,
    _ => TrendWindow.d7,
  };
}

// ── Stage ────────────────────────────────────────────────────────────────

/// Where a subject sits on its own curve.
///
/// `emerging` is the one the whole engine exists for: climbing steeply off a
/// small base, which is the state a product is in *before* it is a best seller
/// and the only state in which acting on it is still cheap.
enum TrendStage {
  dormant('DORMANT'),
  emerging('EMERGING'),
  rising('RISING'),
  peaking('PEAKING'),
  steady('STEADY'),
  cooling('COOLING'),
  declining('DECLINING');

  const TrendStage(this.wire);

  final String wire;

  static TrendStage fromWire(String? value) => switch (value?.toUpperCase()) {
    'EMERGING' => TrendStage.emerging,
    'RISING' => TrendStage.rising,
    'PEAKING' => TrendStage.peaking,
    'STEADY' => TrendStage.steady,
    'COOLING' => TrendStage.cooling,
    'DECLINING' => TrendStage.declining,
    _ => TrendStage.dormant,
  };

  bool get isClimbing =>
      this == TrendStage.emerging ||
      this == TrendStage.rising ||
      this == TrendStage.peaking;

  bool get isFalling =>
      this == TrendStage.cooling || this == TrendStage.declining;
}

/// A stage with the Arabic label the server chose for it.
///
/// The label travels rather than being switched on in the app: the server owns
/// the vocabulary, and a stage the client has not been taught yet still
/// renders as a readable chip instead of an enum name.
class TrendStageLabel {
  const TrendStageLabel({required this.stage, required this.labelAr});

  final TrendStage stage;
  final String labelAr;

  static const TrendStageLabel unknown = TrendStageLabel(
    stage: TrendStage.dormant,
    labelAr: '—',
  );
}

// ── Score components ─────────────────────────────────────────────────────

/// One of the nine things a Trend Score is made of.
///
/// [weight] comes from the server too, so a re-weighted kernel cannot leave
/// the app quietly describing the old formula.
class TrendComponent {
  const TrendComponent({
    required this.key,
    required this.labelAr,
    required this.value,
    required this.weight,
  });

  /// `view_growth`, `conversion`, …
  final String key;
  final String labelAr;

  /// 0–1, before weighting.
  final double value;

  /// How much of the final score this component can contribute.
  final double weight;

  /// The points this component actually contributed, out of 100.
  double get points => value * weight * 100;
}

// ── Products ─────────────────────────────────────────────────────────────

/// Market-wide demand for a product. Shared by every seller who lists it,
/// because they share the page that collects it.
class ProductDemand {
  const ProductDemand({
    required this.views,
    required this.previousViews,
    required this.searchHits,
    required this.cartAdds,
    required this.favorites,
    required this.viewToCartRate,
    required this.cartToOrderRate,
    required this.viewToOrderRate,
  });

  final int views;
  final int previousViews;
  final int searchHits;
  final int cartAdds;
  final int favorites;
  final double viewToCartRate;
  final double cartToOrderRate;
  final double viewToOrderRate;

  static const ProductDemand empty = ProductDemand(
    views: 0,
    previousViews: 0,
    searchHits: 0,
    cartAdds: 0,
    favorites: 0,
    viewToCartRate: 0,
    cartToOrderRate: 0,
    viewToOrderRate: 0,
  );
}

/// What one seller sold, and holds. Hers alone.
class SellerProductOutcome {
  const SellerProductOutcome({
    required this.units,
    required this.orders,
    required this.revenue,
    required this.lifetimeUnits,
    required this.returns,
    required this.stockUnits,
    required this.price,
  });

  final int units;
  final int orders;
  final Money? revenue;
  final int lifetimeUnits;
  final int returns;
  final int stockUnits;
  final Money? price;

  static const SellerProductOutcome empty = SellerProductOutcome(
    units: 0,
    orders: 0,
    revenue: null,
    lifetimeUnits: 0,
    returns: 0,
    stockUnits: 0,
    price: null,
  );
}

/// The five things that can be wrong with a product, precomputed server-side.
///
/// Booleans rather than thresholds the app re-applies: the rule that decides
/// "low conversion" lives next to the peer median it is judged against, and
/// two copies of it would drift.
class TrendAlerts {
  const TrendAlerts({
    this.lowConversion = false,
    this.weakCartThrough = false,
    this.stockRisk = false,
    this.soldOutWithDemand = false,
    this.overstock = false,
  });

  final bool lowConversion;
  final bool weakCartThrough;
  final bool stockRisk;
  final bool soldOutWithDemand;
  final bool overstock;

  bool get any =>
      lowConversion ||
      weakCartThrough ||
      stockRisk ||
      soldOutWithDemand ||
      overstock;

  static const TrendAlerts none = TrendAlerts();
}

/// A product on the seller's dashboard.
class SellerTrendProduct {
  const SellerTrendProduct({
    required this.productId,
    required this.title,
    required this.slug,
    required this.imageUrl,
    required this.categoryNameAr,
    required this.score,
    required this.previousScore,
    required this.delta,
    required this.stage,
    required this.confidence,
    required this.rank,
    required this.components,
    required this.demand,
    required this.mine,
    required this.forecastUnits,
    required this.forecastHorizonDays,
    required this.stockoutInDays,
    required this.alerts,
  });

  final String productId;
  final String title;
  final String slug;
  final String? imageUrl;
  final String categoryNameAr;

  /// 0–100.
  final double score;
  final double? previousScore;
  final double delta;
  final TrendStageLabel stage;

  /// 0–1. How much evidence is behind the score.
  final double confidence;
  final int? rank;
  final List<TrendComponent> components;

  final ProductDemand demand;
  final SellerProductOutcome mine;

  final double? forecastUnits;
  final int? forecastHorizonDays;

  /// Days until the shelf is empty at the forecast rate.
  final double? stockoutInDays;
  final TrendAlerts alerts;

  bool get isUp => delta > 0;
}

/// A product on the admin dashboard — the platform's view of the same row.
class AdminTrendProduct {
  const AdminTrendProduct({
    required this.productId,
    required this.title,
    required this.imageUrl,
    required this.categoryNameAr,
    required this.sellers,
    required this.score,
    required this.delta,
    required this.stage,
    required this.confidence,
    required this.rank,
    required this.views,
    required this.viewsGrowthPct,
    required this.searchHits,
    required this.cartAdds,
    required this.units,
    required this.unitsGrowthPct,
    required this.revenue,
    required this.viewToOrderRate,
    required this.stockUnits,
    required this.daysOfCover,
    required this.components,
  });

  final String productId;
  final String title;
  final String? imageUrl;
  final String categoryNameAr;
  final List<String> sellers;

  final double score;
  final double delta;
  final TrendStageLabel stage;
  final double confidence;
  final int? rank;

  final int views;
  final double viewsGrowthPct;
  final int searchHits;
  final int cartAdds;
  final int units;
  final double unitsGrowthPct;
  final Money? revenue;
  final double viewToOrderRate;
  final int stockUnits;
  final double? daysOfCover;
  final List<TrendComponent> components;
}

// ── Categories and facets ────────────────────────────────────────────────

class CategoryTrend {
  const CategoryTrend({
    required this.categoryId,
    required this.nameAr,
    required this.level,
    required this.score,
    required this.delta,
    required this.stage,
    required this.views,
    required this.viewsGrowthPct,
    required this.units,
    required this.unitsGrowthPct,
    required this.revenue,
    required this.liveProducts,
    required this.inStockProducts,
    required this.medianPrice,
  });

  final String categoryId;
  final String nameAr;
  final int level;
  final double score;
  final double delta;
  final TrendStageLabel stage;
  final int views;
  final double viewsGrowthPct;
  final int units;
  final double unitsGrowthPct;
  final Money? revenue;
  final int liveProducts;
  final int inStockProducts;
  final Money? medianPrice;

  /// How much of the subtree a customer could actually buy today.
  double get inStockRate =>
      liveProducts == 0 ? 1 : inStockProducts / liveProducts;
}

/// A colour, a price band, a brand — demand for one facet value.
///
/// [shareDeltaPct] is the number that matters and the reason this type exists
/// separately from a growth figure. In a week when the whole platform is up
/// forty percent every colour is up forty percent, and "الأسود ارتفع" is then
/// a statement about the week. A colour whose *share* moved has taken
/// something from the others.
class AttributeTrend {
  const AttributeTrend({
    required this.dimension,
    required this.value,
    required this.labelAr,
    required this.demand,
    required this.growthPct,
    required this.sharePct,
    required this.previousSharePct,
    required this.shareDeltaPct,
    required this.orders,
    required this.units,
    required this.revenue,
    required this.products,
  });

  final String dimension;
  final String value;
  final String labelAr;
  final int demand;
  final double growthPct;
  final double sharePct;
  final double previousSharePct;
  final double shareDeltaPct;
  final int orders;
  final int units;
  final Money? revenue;
  final int products;
}
