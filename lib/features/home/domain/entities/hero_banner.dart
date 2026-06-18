import 'package:equatable/equatable.dart';

/// The editorial intent of a hero banner — drives its gradient + badge styling.
enum HeroBannerKind { promotion, campaign, seasonal, personalized }

/// A full-bleed hero slide shown at the top of the home page. Promotions,
/// campaigns, seasonal moments and personalized offers all flow through here so
/// the carousel stays one cohesive, swipeable surface.
class HeroBanner extends Equatable {
  const HeroBanner({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.imageUrl,
    this.eyebrow,
    this.badge,
    this.targetRoute,
  });

  final String id;
  final HeroBannerKind kind;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String imageUrl;

  /// Small label above the title (e.g. "Spring Atelier").
  final String? eyebrow;

  /// Optional pill badge (e.g. "Limited", "−40%").
  final String? badge;

  /// Where the CTA navigates (a [RoutePaths] value). Null = no-op.
  final String? targetRoute;

  @override
  List<Object?> get props =>
      [id, kind, title, subtitle, ctaLabel, imageUrl, eyebrow, badge, targetRoute];
}
