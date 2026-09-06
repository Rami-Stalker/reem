import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/trends/domain/entities/trend_entities.dart';

/// How the engine speaks in colour and iconography.

// ── Colour language ──────────────────────────────────────────────────────

/// The colour a stage speaks in.
///
/// `emerging` is deliberately the gold rather than the green: it is the one
/// state on the curve that is an *opportunity with a deadline*, and it should
/// not look like the same news as a product that is merely doing well.
Color stageColour(BuildContext context, TrendStage stage) {
  final palette = context.atelier;
  return switch (stage) {
    TrendStage.emerging => palette.gold,
    TrendStage.rising => palette.positive,
    TrendStage.peaking => palette.primary,
    TrendStage.steady => palette.muted,
    TrendStage.cooling => palette.caution,
    TrendStage.declining => palette.critical,
    TrendStage.dormant => palette.muted,
  };
}

Color severityColour(BuildContext context, InsightSeverity severity) {
  final palette = context.atelier;
  return switch (severity) {
    InsightSeverity.critical => palette.critical,
    InsightSeverity.warning => palette.caution,
    InsightSeverity.opportunity => palette.gold,
    InsightSeverity.info => palette.primary,
  };
}

IconData insightIcon(String kind) => switch (kind) {
  'EMERGING_PRODUCT' => Icons.auto_awesome_rounded,
  'RISING_DEMAND' ||
  'CATEGORY_MOMENTUM' ||
  'COLOR_MOMENTUM' => Icons.trending_up_rounded,
  'DECLINING_DEMAND' => Icons.trending_down_rounded,
  'LOW_CONVERSION' || 'HIGH_VIEW_NO_SALES' => Icons.visibility_off_rounded,
  'CART_ABANDONMENT' => Icons.remove_shopping_cart_rounded,
  'STOCK_RISK' => Icons.inventory_2_rounded,
  'STOCK_OPPORTUNITY' => Icons.add_business_rounded,
  'OVERSTOCK' => Icons.warehouse_rounded,
  'PRICE_OPPORTUNITY' || 'PRICE_BAND_SHIFT' => Icons.sell_rounded,
  'UNMET_DEMAND' || 'ASSORTMENT_GAP' => Icons.search_off_rounded,
  'SEARCH_SURGE' => Icons.search_rounded,
  'RATING_RISK' => Icons.star_half_rounded,
  'RETURN_RISK' => Icons.assignment_return_rounded,
  'FORECAST_SPIKE' => Icons.show_chart_rounded,
  'SELLER_PERFORMANCE' => Icons.storefront_rounded,
  _ => Icons.insights_rounded,
};
