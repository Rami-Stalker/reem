import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/experience/role_experience.dart';
import 'package:reem/core/router/route_paths.dart';

/// The top of a console page: a band of the courtyard's sky.
///
/// Every page under the rail opens the same way the home does — the room's
/// arch emblem, its name in the display serif, what it is for, and, where the
/// room keeps a queue, its figures lit in champagne. The emblem is the rail's
/// own icon for the page, found from the route, so a page and its rail entry
/// cannot disagree; [icon] overrides it.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.icon,
    this.highlights = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final IconData? icon;
  final List<CourtHighlight> highlights;

  @override
  Widget build(BuildContext context) {
    final gutter = MediaQuery.sizeOf(context).width < 600
        ? DsSpacing.md
        : DsSpacing.xl;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, DsSpacing.xl),
      child: CourtSkyHeader(
        title: title,
        subtitle: subtitle,
        icon: icon ?? adminRouteIcon(_pathOf(context)),
        actions: actions ?? const [],
        highlights: highlights,
      ),
    );
  }

  /// The current route, when there is a router above — a page rendered on its
  /// own (a preview, a test) simply has no emblem to look up.
  static String? _pathOf(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } on Object {
      return null;
    }
  }
}

/// The rail's icon for a console route, for pages that want to wear it.
IconData? adminRouteIcon(String? path) {
  if (path == null) return null;
  for (final item in AppRoleExperience.admin.navigation) {
    if (item.path == path) return item.selectedIcon;
  }
  return switch (path) {
    RoutePaths.adminCampaigns => Icons.campaign_rounded,
    RoutePaths.adminNotificationAnalytics => Icons.query_stats_rounded,
    _ => null,
  };
}
