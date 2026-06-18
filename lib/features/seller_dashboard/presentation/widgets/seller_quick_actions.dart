import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design_system/design_system.dart';
import '../../../../../core/router/route_paths.dart';

class SellerQuickActions extends StatelessWidget {
  const SellerQuickActions({super.key});

  static const _actions = [
    _Action(
      icon: Icons.add_box_outlined,
      label: 'Add\nProduct',
      route: RoutePaths.productForm,
      color: Color(0xFF5B8DEF),
    ),
    _Action(
      icon: Icons.receipt_long_outlined,
      label: 'Manage\nOrders',
      route: RoutePaths.orders,
      color: Color(0xFF3FA86F),
    ),
    _Action(
      icon: Icons.local_offer_outlined,
      label: 'Create\nCoupon',
      route: RoutePaths.coupons,
      color: Color(0xFFE0A23C),
    ),
    _Action(
      icon: Icons.campaign_outlined,
      label: 'Send\nAnnouncement',
      route: null,
      color: Color(0xFF8F5C99),
    ),
    _Action(
      icon: Icons.inventory_2_outlined,
      label: 'My\nProducts',
      route: RoutePaths.myProducts,
      color: Color(0xFFF56B59),
    ),
    _Action(
      icon: Icons.bar_chart_rounded,
      label: 'View\nAnalytics',
      route: RoutePaths.adminAnalytics,
      color: Color(0xFFE85A8A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick actions',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: DsTypography.bold),
          ),
          const SizedBox(height: DsSpacing.sm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: DsSpacing.sm,
              crossAxisSpacing: DsSpacing.sm,
              childAspectRatio: 1.1,
            ),
            itemCount: _actions.length,
            itemBuilder: (context, i) {
              return _actions[i]
                  .build(context, c)
                  .animate(delay: (i * 60).ms)
                  .fadeIn(duration: 300.ms)
                  .scale(begin: const Offset(0.88, 0.88), duration: 300.ms,
                      curve: Curves.easeOutBack);
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

  Widget build(BuildContext context, DsColorScheme c) {
    return GestureDetector(
      onTap: () {
        if (route != null) context.push(route!);
      },
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: DsRadius.borderLg,
          border: Border.all(color: c.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: DsRadius.borderMd,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: DsSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: DsTypography.fontFamily,
                fontSize: 11,
                fontWeight: DsTypography.semiBold,
                color: c.onSurface,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
