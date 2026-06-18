import 'package:equatable/equatable.dart';

/// Layout style for an admin-configured content block.
enum DynamicBlockKind { spotlight, announcement, editorial }

/// A merchandising block configured from the admin panel and rendered inline in
/// the home feed — spotlights, announcements and editorial cards. Kept generic
/// so new campaigns ship without an app release.
class DynamicContentBlock extends Equatable {
  const DynamicContentBlock({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.ctaLabel,
    this.targetRoute,
  });

  final String id;
  final DynamicBlockKind kind;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? ctaLabel;
  final String? targetRoute;

  @override
  List<Object?> get props =>
      [id, kind, title, subtitle, imageUrl, ctaLabel, targetRoute];
}
