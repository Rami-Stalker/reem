import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/seller_intelligence/presentation/providers/intelligence_providers.dart';
import 'package:reem/features/seller_intelligence/presentation/widgets/intelligence_pieces.dart';

/// The way into the three intelligence screens, from her dashboard.
///
/// One card with three doors rather than three panels. The seller home already
/// carries a dozen widgets, and phase two adding three more would make the
/// page longer without making it more useful — the brief asked for something
/// that feels considered, not a wall of numbers.
///
/// The health score is live on the card because it is the one figure that
/// belongs on a morning dashboard: it is the shop's own state, it moves
/// slowly, and if it has fallen she should not have to open a page to find
/// out. The other two doors are plain: what the market is doing and which
/// listings need work are questions she goes looking for, not ones that should
/// interrupt her.
class IntelligenceEntryCard extends ConsumerWidget {
  const IntelligenceEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.atelier;
    final health = ref.watch(sellerHealthProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SellerPanel(
        padding: const EdgeInsets.all(DsSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, size: 18, color: palette.primary),
                const SizedBox(width: DsSpacing.xs),
                Text(
                  context.l10n.siShopIntelligence,
                  style: context.dsText.cardTitle.tint(palette.ink),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),

            // The shop's own state, live.
            health.when(
              loading: () => _Door(
                icon: Icons.favorite_rounded,
                title: context.l10n.siShopHealth,
                subtitle: context.l10n.siCalculating,
                path: RoutePaths.sellerHealth,
              ),
              error: (_, _) => _Door(
                icon: Icons.favorite_rounded,
                title: context.l10n.siShopHealth,
                subtitle: context.l10n.siEightMetrics,
                path: RoutePaths.sellerHealth,
              ),
              data: (data) => _Door(
                icon: Icons.favorite_rounded,
                title: context.l10n.siShopHealth,
                subtitle: data.isProvisional
                    ? context.l10n.siGettingToKnow
                    : '${data.score.round()} · ${data.bandLabel}',
                path: RoutePaths.sellerHealth,
                trailing: data.isProvisional
                    ? null
                    : IntelligenceDial(
                        score: data.score,
                        confidence: data.confidence,
                        size: 44,
                      ),
              ),
            ),

            Divider(color: palette.line, height: DsSpacing.lg),
            _Door(
              icon: Icons.radar_rounded,
              title: context.l10n.siDemandRadar,
              subtitle: context.l10n.siDemandRadarSubtitle,
              path: RoutePaths.sellerRadar,
            ),
            Divider(color: palette.line, height: DsSpacing.lg),
            _Door(
              icon: Icons.inventory_2_rounded,
              title: context.l10n.siProductIntelligence,
              subtitle: context.l10n.siProductIntelligenceSubtitle,
              path: RoutePaths.sellerProductIntelligence,
            ),
          ],
        ),
      ),
    );
  }
}

class _Door extends StatelessWidget {
  const _Door({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String path;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;

    return InkWell(
      onTap: () => context.push(path),
      borderRadius: DsRadius.borderMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
        child: Row(
          children: [
            Icon(icon, size: 18, color: palette.muted),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.dsText.body.semibold.tint(palette.ink),
                  ),
                  Text(
                    subtitle,
                    style: context.dsText.caption.tint(palette.muted),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: palette.muted,
              ),
          ],
        ),
      ),
    );
  }
}
