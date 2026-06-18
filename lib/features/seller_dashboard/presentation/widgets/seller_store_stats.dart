import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design_system/design_system.dart';
import '../providers/seller_dashboard_provider.dart';

class SellerStoreStats extends ConsumerWidget {
  const SellerStoreStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final c = context.dsColors;
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
          color: c.card,
          borderRadius: DsRadius.borderXxl,
          border: Border.all(color: c.border.withValues(alpha: 0.5)),
          boxShadow: context.softShadow,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(DsSpacing.md),
              child: Row(
                children: [
                  _Stat(
                      label: 'Revenue',
                      value: '\$${_fmt(store.totalRevenue)}',
                      icon: Icons.attach_money_rounded,
                      color: c.success),
                  _Divider(c: c),
                  _Stat(
                      label: 'Orders',
                      value: _fmtInt(store.totalOrders),
                      icon: Icons.shopping_bag_outlined,
                      color: c.info),
                  _Divider(c: c),
                  _Stat(
                      label: 'Products',
                      value: '${store.productsCount}',
                      icon: Icons.inventory_2_outlined,
                      color: c.secondary),
                  _Divider(c: c),
                  _Stat(
                      label: 'Followers',
                      value: _fmtInt(store.followersCount),
                      icon: Icons.people_outline_rounded,
                      color: c.primary),
                ],
              ),
            ),
            Divider(height: 1, color: c.divider),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.md, vertical: DsSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, size: 14, color: c.rating),
                  const SizedBox(width: 4),
                  Text(
                    '${store.rating} · ${store.reviewsCount} reviews',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: DsTypography.semiBold,
                      color: c.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today_outlined,
                      size: 12, color: c.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Member since ${store.memberSince.year}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: c.onSurfaceVariant),
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

  static String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  static String _fmtInt(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return '$v';
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
    final c = context.dsColors;
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
          Text(
            value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: DsTypography.bold, fontSize: 13),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: 10,
              color: c.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.c});

  final DsColorScheme c;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 48, color: c.divider);
}
