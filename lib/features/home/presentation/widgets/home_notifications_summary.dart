import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../domain/entities/home_notification.dart';
import '../providers/home_content_provider.dart';

/// A glanceable summary of the notifications centre — unread count and the most
/// recent few, each routed into the full centre.
class HomeNotificationsSummary extends ConsumerWidget {
  const HomeNotificationsSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      homeContentNotifierProvider.select((s) => s.isInitialLoading),
    );
    final summary = ref.watch(
      homeContentNotifierProvider.select(
          (s) => s.content?.notifications ?? const NotificationSummary()),
    );

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
            child: DsSkeleton.box(height: 140, borderRadius: DsRadius.xxl)),
      );
    }
    if (summary.previews.isEmpty) return const SizedBox.shrink();

    final c = context.dsColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SurfaceCard(
        onTap: () => context.push(RoutePaths.notifications),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_rounded,
                    size: 20, color: c.primary),
                const SizedBox(width: DsSpacing.xs),
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontWeight: DsTypography.bold,
                    fontSize: DsTypography.titleSmall,
                    color: c.onSurface,
                  ),
                ),
                const SizedBox(width: DsSpacing.xs),
                if (summary.hasUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: DsRadius.borderFull,
                    ),
                    child: Text(
                      '${summary.unreadCount} new',
                      style: TextStyle(
                        color: c.onPrimary,
                        fontSize: 10,
                        fontWeight: DsTypography.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: c.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: DsSpacing.xs),
            for (final n in summary.previews.take(3)) _NotificationRow(item: n),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item});

  final HomeNotificationPreview item;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final (icon, tint) = switch (item.kind) {
      HomeNotificationKind.order => (Icons.local_shipping_outlined, c.info),
      HomeNotificationKind.promo => (Icons.local_offer_outlined, c.discount),
      HomeNotificationKind.social => (Icons.favorite_border_rounded, c.secondary),
      HomeNotificationKind.system => (Icons.info_outline_rounded, c.onSurfaceVariant),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: DsRadius.borderMd,
            ),
            child: Icon(icon, size: 17, color: tint),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: DsTypography.labelLarge,
                fontWeight: item.unread ? DsTypography.semiBold : DsTypography.regular,
                color: item.unread ? c.onSurface : c.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: DsSpacing.xs),
          Text(
            item.timeAgo,
            style: TextStyle(
                fontSize: DsTypography.labelSmall, color: c.onSurfaceVariant),
          ),
          if (item.unread) ...[
            const SizedBox(width: DsSpacing.xs),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  color: c.primary, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }
}
