/// What the engine has to say, and the searches it could not answer.
///
/// An insight is a *rendering of arithmetic*, never a claim on its own:
/// `metrics` is always populated and `narrator` always says whether an
/// Arabic template or a model wrote the sentence.

library;

// ── Search intelligence ──────────────────────────────────────────────────

class SearchTermTrend {
  const SearchTermTrend({
    required this.termKey,
    required this.display,
    required this.facetsAr,
    required this.searches,
    required this.previousSearches,
    required this.zeroResults,
    required this.missRate,
    required this.clickRate,
    required this.orders,
  });

  final String termKey;

  /// The spelling most women used. Never the key.
  final String display;

  /// What the normaliser understood, as an Arabic noun phrase.
  final String facetsAr;
  final int searches;
  final int previousSearches;
  final int zeroResults;

  /// zeroResults / searches. 1.0 means the catalogue never had an answer.
  final double missRate;
  final double clickRate;
  final int orders;
}

/// A question the catalogue could not answer.
enum UnmetDemandStatus {
  open('OPEN'),
  acknowledged('ACKNOWLEDGED'),
  sourcing('SOURCING'),
  addressed('ADDRESSED'),
  dismissed('DISMISSED');

  const UnmetDemandStatus(this.wire);

  final String wire;

  static UnmetDemandStatus fromWire(String? value) =>
      switch (value?.toUpperCase()) {
        'ACKNOWLEDGED' => UnmetDemandStatus.acknowledged,
        'SOURCING' => UnmetDemandStatus.sourcing,
        'ADDRESSED' => UnmetDemandStatus.addressed,
        'DISMISSED' => UnmetDemandStatus.dismissed,
        _ => UnmetDemandStatus.open,
      };
}

class UnmetDemand {
  const UnmetDemand({
    required this.id,
    required this.termKey,
    required this.display,
    required this.searches,
    required this.zeroResults,
    required this.missRate,
    required this.demandScore,
    required this.suggestionAr,
    required this.suggestedCategoryNameAr,
    required this.status,
  });

  final String id;
  final String termKey;
  final String display;
  final int searches;
  final int zeroResults;
  final double missRate;

  /// 0–100. Volume × miss rate × growth. What the list sorts by.
  final double demandScore;

  /// The sentence written for the buying team.
  final String? suggestionAr;
  final String? suggestedCategoryNameAr;
  final UnmetDemandStatus status;
}

// ── Insights ─────────────────────────────────────────────────────────────

enum InsightSeverity {
  info('INFO'),
  opportunity('OPPORTUNITY'),
  warning('WARNING'),
  critical('CRITICAL');

  const InsightSeverity(this.wire);

  final String wire;

  static InsightSeverity fromWire(String? value) =>
      switch (value?.toUpperCase()) {
        'OPPORTUNITY' => InsightSeverity.opportunity,
        'WARNING' => InsightSeverity.warning,
        'CRITICAL' => InsightSeverity.critical,
        _ => InsightSeverity.info,
      };
}

enum InsightStatus {
  open('OPEN'),
  acknowledged('ACKNOWLEDGED'),
  actioned('ACTIONED'),
  dismissed('DISMISSED'),
  expired('EXPIRED');

  const InsightStatus(this.wire);

  final String wire;

  static InsightStatus fromWire(String? value) =>
      switch (value?.toUpperCase()) {
        'ACKNOWLEDGED' => InsightStatus.acknowledged,
        'ACTIONED' => InsightStatus.actioned,
        'DISMISSED' => InsightStatus.dismissed,
        'EXPIRED' => InsightStatus.expired,
        _ => InsightStatus.open,
      };
}

/// One thing worth telling someone, in her language.
///
/// [metrics] is always populated, and the card always offers to show it. The
/// sentence is a rendering of arithmetic, and a reader who wants to check the
/// claim rather than trust it should be one tap away from the numbers.
///
/// [narrator] says who phrased it — an Arabic template, or the model. It is
/// carried so the distinction is never invisible.
class TrendInsight {
  const TrendInsight({
    required this.id,
    required this.kind,
    required this.severity,
    required this.status,
    required this.titleAr,
    required this.bodyAr,
    required this.actionAr,
    required this.actionTarget,
    required this.productId,
    required this.productTitle,
    required this.categoryId,
    required this.categoryNameAr,
    required this.metrics,
    required this.confidence,
    required this.priority,
    required this.narrator,
  });

  /// `EMERGING_PRODUCT`, `STOCK_RISK`, `UNMET_DEMAND`, …
  final String kind;
  final String id;
  final InsightSeverity severity;
  final InsightStatus status;
  final String titleAr;
  final String bodyAr;

  /// The one thing to do about it. Null when the finding is an observation.
  final String? actionAr;

  /// A route hint: `product`, `category`, `inventory`, `search`, `pricing`.
  final String? actionTarget;

  final String? productId;
  final String? productTitle;
  final String? categoryId;
  final String? categoryNameAr;

  /// The evidence the sentence was built from.
  final Map<String, dynamic> metrics;
  final double confidence;
  final double priority;

  /// `reem-trend-templates-v1`, or the model that phrased this row.
  final String narrator;

  bool get isTemplatePhrased => narrator.startsWith('reem-trend-templates');
}
