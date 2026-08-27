import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../providers/seller_dashboard_provider.dart';
import 'seller_format.dart';

class SellerStoreStats extends ConsumerWidget {
  const SellerStoreStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final palette = context.atelier;
    final l10n = context.l10n;
    final theme = Theme.of(context);

    if (state.isInitialLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
            child: DsSkeleton.box(height: 120, borderRadius: DsRadius.xxl)),
      );
    }

    final store = state.data?.storeInfo;
    if (store == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: DsRadius.borderXxl,
          border: Border.all(color: palette.line),
          boxShadow: palette.shadow,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(DsSpacing.md),
              child: Row(
                children: [
                  _Stat(
                    label: l10n.sellerRevenue,
                    value: store.totalRevenue.sypCompact,
                    icon: Icons.payments_outlined,
                    color: palette.gold,
                  ),
                  _Divider(color: palette.line),
                  _Stat(
                    label: l10n.orders,
                    value: formatCount(store.totalOrders),
                    icon: Icons.shopping_bag_outlined,
                    color: palette.series[0],
                  ),
                  _Divider(color: palette.line),
                  _Stat(
                    label: l10n.products,
                    value: formatCount(store.productsCount),
                    icon: Icons.inventory_2_outlined,
                    color: palette.series[1],
                  ),
                  _Divider(color: palette.line),
                  _Stat(
                    label: l10n.followers,
                    value: formatCount(store.followersCount),
                    icon: Icons.people_outline_rounded,
                    color: palette.series[3],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.line),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.md, vertical: DsSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: context.dsColors.rating,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      l10n.sellerRatingSummary(
                        store.rating.toStringAsFixed(1),
                        formatCount(store.reviewsCount),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: DsTypography.semiBold,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: palette.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.sellerMemberSince('${store.memberSince.year}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .slideY(begin: 0.04, end: 0, duration: 380.ms);
  }

}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.atelier;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: DsRadius.borderSm,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: DsSpacing.xxs),
          // A quarter of a phone width is not enough for «184 ألف ل.س», which
          // wrapped and pushed the currency onto its own line. Scale it down
          // instead — a slightly smaller figure beats a broken one.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: DsTypography.bold,
                fontSize: 13,
                color: palette.ink,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: 10,
              color: palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 48, color: color);
}
