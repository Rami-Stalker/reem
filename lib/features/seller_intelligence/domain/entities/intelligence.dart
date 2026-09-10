import 'package:meta/meta.dart';

/// What the seller's intelligence screens are made of.
///
/// Three systems, one vocabulary. Every score on every screen carries the same
/// three things beside it — how it was weighted, how much evidence stood
/// behind it, and what to do about it — because the whole point of phase two
/// is that a seller can act on a number rather than only read it.
///
/// The `null` scores are load-bearing. A dimension that has not been measured
/// is `null`, never zero: the server refuses to guess and the client must not
/// quietly turn that refusal into a bad mark on a screen.

// ── Shared ───────────────────────────────────────────────────────────────

enum AdviceSeverity {
  critical,
  warning,
  opportunity;

  static AdviceSeverity parse(String? raw) => switch (raw) {
    'critical' => AdviceSeverity.critical,
    'warning' => AdviceSeverity.warning,
    _ => AdviceSeverity.opportunity,
  };
}

/// One thing to do, in her own words, with what it is worth.
@immutable
class Advice {
  const Advice({
    required this.code,
    required this.severity,
    required this.gainPoints,
    required this.ar,
    this.subject,
  });

  final String code;
  final AdviceSeverity severity;

  /// Points on the score she would recover. Zero for advice about money
  /// rather than about the score — a price note changes sales, not health.
  final double gainPoints;
  final String ar;

  /// The dimension or axis this belongs to, when there is one.
  final String? subject;

  bool get isScored => gainPoints > 0;
}

// ── Seller health ────────────────────────────────────────────────────────

enum HealthBand {
  building,
  atRisk,
  steady,
  strong,
  exemplary;

  static HealthBand parse(String? raw) => switch (raw) {
    'AT_RISK' => HealthBand.atRisk,
    'STEADY' => HealthBand.steady,
    'STRONG' => HealthBand.strong,
    'EXEMPLARY' => HealthBand.exemplary,
    _ => HealthBand.building,
  };

  /// Whether this band is a measurement or an admission that there is not
  /// enough history yet. The screen says so out loud rather than showing a
  /// number that looks like a verdict.
  bool get isProvisional => this == HealthBand.building;
}

@immutable
class HealthDimension {
  const HealthDimension({
    required this.key,
    required this.label,
    required this.blurb,
    required this.score,
    required this.weight,
    required this.evidence,
    required this.sample,
    required this.value,
    required this.counted,
  });

  final String key;
  final String label;
  final String blurb;

  /// 0-100, or null when nothing has happened to measure.
  final double? score;

  /// Its share of the total, after renormalising over what was measurable.
  final double weight;

  /// 0-1: how full the sample is.
  final double evidence;
  final int sample;

  /// The measured figure in its own units — hours, a percentage, a rating.
  final double? value;

  /// Whether it is currently moving her score at all.
  final bool counted;

  /// Measured, but on too little evidence to count yet. Worth showing
  /// differently from "not measured at all": one is a promise, the other is
  /// a gap.
  bool get isProvisional => score != null && !counted;
}

@immutable
class SellerHealth {
  const SellerHealth({
    required this.score,
    required this.band,
    required this.bandLabel,
    required this.isProvisional,
    required this.confidence,
    required this.momentum,
    required this.windowDays,
    required this.dimensions,
    required this.advice,
    required this.facts,
  });

  final double score;
  final HealthBand band;
  final String bandLabel;
  final bool isProvisional;
  final double confidence;

  /// Points gained or lost against thirty days ago.
  final double momentum;
  final int windowDays;
  final List<HealthDimension> dimensions;
  final List<Advice> advice;

  /// The counts the score was computed from, so she can check the working.
  final Map<String, num?> facts;

  List<HealthDimension> get counted =>
      dimensions.where((d) => d.counted).toList(growable: false);

  /// The ones actively costing her, worst first.
  List<HealthDimension> get needsWork =>
      (counted.where((d) => (d.score ?? 100) < 80).toList()
        ..sort((a, b) => (a.score ?? 0).compareTo(b.score ?? 0)));
}

@immutable
class HealthPoint {
  const HealthPoint({
    required this.day,
    required this.score,
    required this.band,
  });

  final DateTime day;
  final double score;
  final HealthBand band;
}

// ── Product intelligence ─────────────────────────────────────────────────

@immutable
class HealthAxis {
  const HealthAxis({
    required this.key,
    required this.label,
    required this.score,
    required this.weight,
    required this.evidence,
    required this.counted,
  });

  final String key;
  final String label;
  final double? score;
  final double weight;

  /// `measured`, `thin` or `unmeasurable` — how far to trust this one.
  final String evidence;
  final bool counted;

  bool get isUnmeasurable => score == null;
}

@immutable
class PeerPosition {
  const PeerPosition({
    required this.peers,
    required this.pricePremiumBps,
    required this.conversion,
    required this.medianConversion,
  });

  final int peers;

  /// Her price against the category median, in basis points. Positive = dearer.
  final int? pricePremiumBps;
  final double conversion;
  final double medianConversion;

  double? get pricePremiumPercent =>
      pricePremiumBps == null ? null : pricePremiumBps! / 100;
}

@immutable
class ProductHealth {
  const ProductHealth({
    required this.productId,
    required this.title,
    required this.imageUrl,
    required this.score,
    required this.confidence,
    required this.axes,
    required this.peers,
    required this.advice,
    this.views = 0,
    this.orders = 0,
    this.inStock = true,
    this.adviceCount = 0,
    this.facts = const {},
  });

  final String productId;
  final String title;
  final String? imageUrl;
  final double score;
  final double confidence;
  final List<HealthAxis> axes;
  final PeerPosition? peers;
  final List<Advice> advice;
  final int views;
  final int orders;
  final bool inStock;
  final int adviceCount;
  final Map<String, num?> facts;

  Advice? get topAdvice => advice.isEmpty ? null : advice.first;

  /// Health as a band, for colour only. Deliberately not shown as a word —
  /// a listing is not "failing", it has specific things missing from it.
  bool get isWeak => score < 45;
  bool get isStrong => score >= 75;
}

@immutable
class ProductHealthList {
  const ProductHealthList({
    required this.windowDays,
    required this.averageScore,
    required this.rows,
  });

  final int windowDays;
  final double? averageScore;
  final List<ProductHealth> rows;

  bool get isEmpty => rows.isEmpty;

  /// Listings with something critical wrong — the ones worth interrupting for.
  List<ProductHealth> get urgent => rows
      .where((r) => r.topAdvice?.severity == AdviceSeverity.critical)
      .toList(growable: false);
}

// ── Demand radar ─────────────────────────────────────────────────────────

enum OpportunityKind {
  restock,
  unmetInCategory,
  risingCategory,
  enterCategory;

  static OpportunityKind parse(String? raw) => switch (raw) {
    'RESTOCK_DEMAND' => OpportunityKind.restock,
    'UNMET_IN_CATEGORY' => OpportunityKind.unmetInCategory,
    'RISING_CATEGORY' => OpportunityKind.risingCategory,
    _ => OpportunityKind.enterCategory,
  };
}

@immutable
class Opportunity {
  const Opportunity({
    required this.kind,
    required this.score,
    required this.ar,
    this.categoryId,
    this.productId,
    this.termKey,
  });

  final OpportunityKind kind;
  final double score;
  final String ar;
  final String? categoryId;
  final String? productId;
  final String? termKey;
}

@immutable
class RisingCategory {
  const RisingCategory({
    required this.categoryId,
    required this.name,
    required this.growth,
    required this.recent,
    required this.isSelling,
    required this.relevance,
  });

  final String categoryId;
  final String name;

  /// A ratio: 0.25 is +25%.
  final double growth;
  final int recent;

  /// Whether she already has listings here.
  final bool isSelling;
  final double relevance;

  int get growthPercent => (growth * 100).round();
}

@immutable
class UnmetDemand {
  const UnmetDemand({
    required this.termKey,
    required this.display,
    required this.searches,
    required this.missRate,
    required this.inHerCategories,
    required this.opportunity,
  });

  final String termKey;
  final String display;
  final int searches;
  final double missRate;
  final bool inHerCategories;
  final double opportunity;
}

@immutable
class StockAlert {
  const StockAlert({
    required this.productId,
    required this.title,
    required this.stockUnits,
    required this.coverDays,
    required this.severity,
    required this.ar,
  });

  final String productId;
  final String title;
  final int stockUnits;
  final double? coverDays;
  final AdviceSeverity severity;
  final String ar;
}

@immutable
class PriceTrend {
  const PriceTrend({
    required this.categoryId,
    required this.name,
    required this.changeBps,
    required this.sellerPremiumBps,
    required this.ar,
  });

  final String categoryId;
  final String name;
  final int changeBps;
  final int? sellerPremiumBps;
  final String ar;

  bool get isRising => changeBps > 300;
  bool get isFalling => changeBps < -300;
}

@immutable
class DemandRadar {
  const DemandRadar({
    required this.asOf,
    required this.windowDays,
    required this.categoryCount,
    required this.opportunities,
    required this.rising,
    required this.unmet,
    required this.stockAlerts,
    required this.priceTrends,
  });

  final DateTime asOf;
  final int windowDays;
  final int categoryCount;
  final List<Opportunity> opportunities;
  final List<RisingCategory> rising;
  final List<UnmetDemand> unmet;
  final List<StockAlert> stockAlerts;
  final List<PriceTrend> priceTrends;

  /// Nothing to say yet. Distinct from an error: the radar reads a nightly
  /// pipeline, and a brand-new shop genuinely has no signal in it.
  bool get isEmpty =>
      opportunities.isEmpty &&
      rising.isEmpty &&
      unmet.isEmpty &&
      stockAlerts.isEmpty &&
      priceTrends.isEmpty;

  /// She sells nothing, so there is nothing to read the market against.
  bool get hasNoListings => categoryCount == 0;
}

/// Why one listing stopped selling.
///
/// A single named cause, not a list of things that correlate. The server
/// deliberately picks one — out of stock beats undercut beats a cooling
/// category — because a seller handed five possible reasons acts on none of
/// them. Where a second cause was close, it arrives in [also] as context
/// rather than as a competing instruction.
@immutable
class ListingDiagnosis {
  const ListingDiagnosis({
    required this.code,
    required this.title,
    required this.action,
    this.also,
    this.evidence = const {},
  });

  /// Machine-readable cause, e.g. `out_of_stock`, `undercut`.
  final String code;

  /// What happened, already phrased in Arabic by the server.
  final String title;

  /// What she could do about it.
  final String action;

  /// The runner-up cause, when one was close. May be null.
  final String? also;

  final Map<String, num?> evidence;
}

/// A listing that was selling and stopped, with its cause.
@immutable
class DecliningListing {
  const DecliningListing({
    required this.productId,
    required this.title,
    required this.ordersNow,
    required this.ordersBefore,
    required this.diagnosis,
  });

  final String productId;
  final String title;
  final int ordersNow;
  final int ordersBefore;
  final ListingDiagnosis diagnosis;

  /// Orders lost against the previous window. Always positive here — the
  /// server only returns listings that fell by at least a quarter.
  int get lost => ordersBefore - ordersNow;
}
