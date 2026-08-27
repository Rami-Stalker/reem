import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/localization/l10n_extension.dart';

/// Commerce hub — quick links to the customer's orders, saved items and
/// account settings. All destinations are real registered routes.
class ProfileHub extends StatelessWidget {
  const ProfileHub({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_HubItem>[
      _HubItem(Icons.local_mall_outlined, context.l10n.myOrders, RoutePaths.orders),
      _HubItem(
          Icons.favorite_border_rounded, context.l10n.savedItems, RoutePaths.favorites),
      _HubItem(
          Icons.location_on_outlined, context.l10n.addresses, RoutePaths.addresses),
      _HubItem(Icons.credit_card_outlined, context.l10n.paymentMethods,
          RoutePaths.paymentMethods),
      _HubItem(
          Icons.confirmation_number_outlined, context.l10n.coupons, RoutePaths.coupons),
      _HubItem(
          Icons.card_giftcard_rounded, context.l10n.rewardsAndOffers, RoutePaths.rewards),
    ];

    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(height: 1, indent: 64, color: c.divider),
              _HubRow(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _HubRow extends StatelessWidget {
  const _HubRow({required this.item});

  final _HubItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push(item.route),
      borderRadius: DsRadius.borderCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.md, vertical: DsSpacing.sm + 2),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.primaryContainer.withValues(alpha: 0.6),
                borderRadius: DsRadius.borderMd,
              ),
              child: Icon(item.icon, size: 20, color: c.primary),
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Text(item.label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: DsTypography.medium)),
            ),
            Icon(Icons.chevron_right_rounded, color: c.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _HubItem {
  const _HubItem(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
}
