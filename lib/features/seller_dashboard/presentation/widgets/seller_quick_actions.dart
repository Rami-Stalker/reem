import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';

/// The six doors a seller uses most.
///
/// Localized (it was English-only on an Arabic-first app) and re-coloured from
/// the atelier's data-series palette, so the tiles read as one family instead
/// of six unrelated brand colours — the old set mixed a stock blue, a teal, an
/// amber, a violet and a red, which made every tile look like a status.
class SellerQuickActions extends StatelessWidget {
  const SellerQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    final actions = <_Action>[
      _Action(
        icon: Icons.add_box_outlined,
        label: l10n.sellerAddProduct,
        route: RoutePaths.productForm,
        color: palette.series[0],
      ),
      _Action(
        icon: Icons.receipt_long_outlined,
        label: l10n.sellerManageOrders,
        route: RoutePaths.sellerOrders,
        color: palette.series[1],
      ),
      _Action(
        icon: Icons.inventory_2_outlined,
        label: l10n.myProducts,
        route: RoutePaths.myProducts,
        color: palette.series[3],
      ),
      // «إنشاء كوبون» used to sit here and opened `/coupons` — the CUSTOMER's
      // coupon wallet. Sellers cannot create coupons at all; that stays with
      // the platform. Her returns desk is the work that actually waits.
      _Action(
        icon: Icons.assignment_return_outlined,
        label: l10n.sellerReturnsTitle,
        route: RoutePaths.sellerReturns,
        color: palette.series[2],
      ),
      _Action(
        icon: Icons.campaign_outlined,
        label: l10n.sellerAnnouncement,
        route: RoutePaths.addPost,
        color: palette.series[4],
      ),
      _Action(
        icon: Icons.bar_chart_rounded,
        label: l10n.sellerAnalytics,
        route: RoutePaths.sellerAnalytics,
        color: palette.primary,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sellerQuickActions,
            style: context.dsText.tileTitle.bold.tint(palette.ink),
          ),
          const SizedBox(height: DsSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 760 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: DsSpacing.sm,
                  crossAxisSpacing: DsSpacing.sm,
                  // Arabic labels wrap more readily than English ones; the
                  // shorter tile gives the second line somewhere to go.
                  childAspectRatio: 2.45,
                ),
                itemCount: actions.length,
                itemBuilder: (context, i) => actions[i]
                    .build(context)
                    .animate(delay: (i * 55).ms)
                    .fadeIn(duration: 260.ms)
                    .scale(
                      begin: const Offset(0.96, 0.96),
                      duration: 260.ms,
                      curve: Curves.easeOutCubic,
                    ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Action {
  const _Action({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String? route;
  final Color color;

  Widget build(BuildContext context) {
    final palette = context.atelier;
    final path = route;

    return GestureDetector(
      onTap: path == null ? null : () => context.push(path),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.sm),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(DsRadius.lg),
          border: Border.all(color: palette.line),
          boxShadow: palette.shadow,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: DsRadius.borderMd,
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.labelMedium.bold.tint(palette.ink).copyWith(height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
