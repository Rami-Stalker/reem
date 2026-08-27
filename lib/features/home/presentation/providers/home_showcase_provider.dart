import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/l10n/app_localizations.dart';

/// The shapes a product can take on the home page.
///
/// The client's ask (and the reason this enum exists at all): the same pieces
/// should be browsable in more than one rhythm, with the **post** — the
/// Instagram-style storytelling card — as the shape everything else defers to.
enum HomeShowcaseShape {
  /// The hero shape: one product told as a social post with gallery, caption
  /// and engagement.
  posts,

  /// The magazine spread: a tall hero tile beside two companions, mirrored
  /// down the page.
  mosaic,

  /// The catalogue: two even columns, fastest to scan when she is hunting
  /// rather than browsing.
  grid,
}

extension HomeShowcaseShapeX on HomeShowcaseShape {
  IconData get icon => switch (this) {
    HomeShowcaseShape.posts => Icons.auto_awesome_motion_rounded,
    HomeShowcaseShape.mosaic => Icons.dashboard_rounded,
    HomeShowcaseShape.grid => Icons.grid_view_rounded,
  };

  String label(AppLocalizations l10n) => switch (this) {
    HomeShowcaseShape.posts => l10n.homeShapePosts,
    HomeShowcaseShape.mosaic => l10n.homeShapeMosaic,
    HomeShowcaseShape.grid => l10n.homeShapeGrid,
  };
}

/// Which shape the showcase is currently wearing. Session-scoped on purpose —
/// she picks a mood for this visit, not a setting to manage.
final homeShowcaseShapeProvider = StateProvider<HomeShowcaseShape>(
  (ref) => HomeShowcaseShape.posts,
);
