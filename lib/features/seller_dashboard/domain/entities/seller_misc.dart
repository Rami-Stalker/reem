import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/tokens/ds_tone.dart';

// ── Store Performance Score ───────────────────────────────────────────────────

class SellerStoreScore extends Equatable {
  const SellerStoreScore({
    required this.overall,
    required this.fulfillment,
    required this.responsiveness,
    required this.productQuality,
    required this.rating,
  });

  final int overall; // 0–100
  final int fulfillment;

  /// Null when she has never been messaged.
  ///
  /// Nullable rather than zero, because those are different claims and the
  /// server can now tell them apart: this used to arrive as a hardcoded 90
  /// for every seller, and rendering an unmeasured reply time as `0` would
  /// swap one wrong number for a crueller one.
  final int? responsiveness;
  final int productQuality;
  final double rating;

  String get grade => switch (overall) {
        >= 90 => 'Excellent',
        >= 75 => 'Good',
        >= 60 => 'Fair',
        _ => 'Needs work',
      };

  /// What the grade *means*. The colour that draws it belongs to the theme,
  /// so the widget resolves this with `context.toneColor(...)`.
  DsTone get gradeTone => switch (overall) {
        >= 90 => DsTone.positive,
        >= 75 => DsTone.info,
        >= 60 => DsTone.caution,
        _ => DsTone.critical,
      };

  @override
  List<Object?> get props => [overall, fulfillment, responsiveness, productQuality];
}

// ── Conversion Metrics ────────────────────────────────────────────────────────

class SellerConversionMetrics extends Equatable {
  const SellerConversionMetrics({
    required this.productViews,
    required this.wishlistAdds,
    required this.cartAdds,
    required this.purchases,
    required this.viewsTrend,
    required this.wishlistTrend,
    required this.cartTrend,
    required this.conversionRate,
    required this.cartAbandonRate,
  });

  final int productViews;
  final int wishlistAdds;
  final int cartAdds;
  final int purchases;
  final double viewsTrend;
  final double wishlistTrend;
  final double cartTrend;
  final double conversionRate;
  final double cartAbandonRate;

  @override
  List<Object?> get props => [
        productViews,
        wishlistAdds,
        cartAdds,
        purchases,
        conversionRate,
      ];
}

// ── AI Insight ────────────────────────────────────────────────────────────────

enum AiInsightKind { revenue, product, inventory, customer, warning }

class SellerAiInsight extends Equatable {
  const SellerAiInsight({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.action,
  });

  final String id;
  final AiInsightKind kind;
  final String title;
  final String body;
  final String action;

  DsTone get kindTone => switch (kind) {
        AiInsightKind.revenue => DsTone.positive,
        AiInsightKind.product => DsTone.info,
        AiInsightKind.inventory => DsTone.caution,
        AiInsightKind.customer => DsTone.accent,
        AiInsightKind.warning => DsTone.critical,
      };

  IconData get kindIcon => switch (kind) {
        AiInsightKind.revenue => Icons.trending_up_rounded,
        AiInsightKind.product => Icons.inventory_2_outlined,
        AiInsightKind.inventory => Icons.warning_amber_rounded,
        AiInsightKind.customer => Icons.people_outline_rounded,
        AiInsightKind.warning => Icons.error_outline_rounded,
      };

  @override
  List<Object?> get props => [id, kind, title];
}

// ── Task ──────────────────────────────────────────────────────────────────────

enum TaskPriority { high, medium, low }

class SellerTask extends Equatable {
  const SellerTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.priority,
    required this.icon,
    this.count,
  });

  final String id;
  final String title;
  final String subtitle;
  final TaskPriority priority;
  final IconData icon;
  final int? count;

  DsTone get priorityTone => switch (priority) {
        TaskPriority.high => DsTone.critical,
        TaskPriority.medium => DsTone.caution,
        TaskPriority.low => DsTone.info,
      };

  @override
  List<Object?> get props => [id, priority];
}

// ── Goal ─────────────────────────────────────────────────────────────────────

class SellerGoal extends Equatable {
  const SellerGoal({
    required this.id,
    required this.label,
    required this.current,
    required this.target,
    required this.unit,
    required this.icon,
  });

  final String id;
  final String label;
  final double current;
  final double target;
  final String unit;
  final IconData icon;

  double get progress => (current / target).clamp(0.0, 1.0);
  bool get isComplete => current >= target;

  @override
  List<Object?> get props => [id, current, target];
}

// ── Recent Review ─────────────────────────────────────────────────────────────

class SellerRecentReview extends Equatable {
  const SellerRecentReview({
    required this.id,
    required this.customerName,
    required this.customerAvatarUrl,
    required this.productTitle,
    required this.rating,
    required this.body,
    required this.timeAgo,
  });

  final String id;
  final String customerName;
  final String customerAvatarUrl;
  final String productTitle;
  final double rating;
  final String body;
  final String timeAgo;

  @override
  List<Object?> get props => [id, rating];
}

// ── Coupon / Campaign Performance ─────────────────────────────────────────────

class SellerCampaignStat extends Equatable {
  const SellerCampaignStat({
    required this.id,
    required this.name,
    required this.kind,
    required this.uses,
    required this.revenue,
    required this.endsAt,
    required this.isActive,
  });

  final String id;
  final String name;
  final String kind;
  final int uses;
  final double revenue;
  final DateTime? endsAt;
  final bool isActive;

  @override
  List<Object?> get props => [id, uses, revenue];
}
