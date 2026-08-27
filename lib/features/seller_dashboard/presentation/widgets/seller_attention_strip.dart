import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';
import '../providers/seller_dashboard_provider.dart';
import 'seller_format.dart';

/// **What needs her now** — the first thing on the seller's page.
///
/// The dashboard was a stack of twelve equally-weighted panels, which meant a
/// seller opening it in the morning had to read the whole thing to find out
/// whether anything was on fire. This strip answers that in one glance and
/// nothing more: orders waiting on a confirmation, stock about to run out,
/// tasks still open — each one a door to the screen that clears it.
///
/// When there is genuinely nothing to do it says so, calmly, rather than
/// inventing work to fill the space.
class SellerAttentionStrip extends ConsumerWidget {
  const SellerAttentionStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final palette = context.atelier;
    final l10n = context.l10n;

    if (state.isInitialLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
          child: DsSkeleton.box(height: 96, borderRadius: DsRadius.xxl),
        ),
      );
    }

    final data = state.data;
    if (data == null) return const SizedBox.shrink();

    // Orders that cannot move without her: brand new, plus the ones she has
    // accepted but not yet handed to a courier.
    final waitingOrders = data.orders.newOrders + data.orders.processing;
    final lowStock = data.lowStock.length;
    final openTasks = data.pendingTasks.length;

    final alerts = <_Alert>[
      if (waitingOrders > 0)
        _Alert(
          icon: Icons.receipt_long_rounded,
          label: l10n.sellerPendingOrders,
          count: waitingOrders,
          tone: _Tone.urgent,
          onTap: () => context.push(RoutePaths.sellerOrders),
        ),
      if (lowStock > 0)
        _Alert(
          icon: Icons.inventory_2_outlined,
          label: l10n.sellerRunningLow,
          count: lowStock,
          tone: _Tone.warning,
          onTap: () => context.push(RoutePaths.myProducts),
        ),
      if (openTasks > 0)
        _Alert(
          icon: Icons.checklist_rounded,
          label: l10n.sellerOpenTasks,
          count: openTasks,
          tone: _Tone.calm,
          onTap: null,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(DsRadius.xxl),
          border: Border.all(color: palette.line),
          boxShadow: palette.shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  alerts.isEmpty
                      ? Icons.verified_rounded
                      : Icons.bolt_rounded,
                  size: 16,
                  color: alerts.isEmpty ? palette.positive : palette.gold,
                ),
                const SizedBox(width: DsSpacing.xxs),
                Expanded(
                  child: Text(
                    alerts.isEmpty ? l10n.sellerAllClear : l10n.sellerNeedsYou,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.ink,
                      fontFamily: DsTypography.fontFamily,
                      fontSize: DsTypography.labelLarge,
                      fontWeight: DsTypography.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: DsSpacing.sm),
              Row(
                children: [
                  for (var i = 0; i < alerts.length; i++) ...[
                    if (i > 0) const SizedBox(width: DsSpacing.xs),
                    Expanded(child: _AlertTile(alert: alerts[i])),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _Tone { urgent, warning, calm }

class _Alert {
  const _Alert({
    required this.icon,
    required this.label,
    required this.count,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final _Tone tone;
  final VoidCallback? onTap;
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final _Alert alert;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final color = switch (alert.tone) {
      _Tone.urgent => palette.critical,
      _Tone.warning => palette.caution,
      _Tone.calm => palette.primary,
    };

    return GestureDetector(
      onTap: alert.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.xs,
          vertical: DsSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(DsRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(alert.icon, size: 18, color: color),
            const SizedBox(height: DsSpacing.xxs),
            Text(
              formatCount(alert.count),
              style: TextStyle(
                color: color,
                fontFamily: DsTypography.fontFamily,
                fontSize: DsTypography.titleSmall,
                fontWeight: DsTypography.bold,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              alert.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.muted,
                fontFamily: DsTypography.fontFamily,
                fontSize: DsTypography.labelSmall,
                fontWeight: DsTypography.medium,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
