import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/profile/domain/entities/orders_overview.dart';
import 'package:reem/features/profile/presentation/providers/profile_overview_provider.dart';
import 'package:reem/features/profile/presentation/widgets/profile_section_header.dart';

/// "My orders" — four status tiles (pending / processing / delivered /
/// cancelled) with live counts, each routing into the orders list.
class ProfileOrdersOverview extends ConsumerWidget {
  const ProfileOrdersOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      profileOverviewNotifierProvider.select((s) => s.isInitialLoading),
    );
    final orders = ref.watch(
      profileOverviewNotifierProvider
          .select((s) => s.overview?.orders ?? const OrdersOverview()),
    );
    final c = context.dsColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeader(
          title: context.l10n.myOrders,
          onSeeAll: () => context.push(RoutePaths.orders),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: isLoading
              ? const DsShimmer(
                  child: DsSkeleton.box(height: 84, borderRadius: DsRadius.xxl))
              : Row(
                  children: [
                    _StatusTile(
                      icon: Icons.schedule_rounded,
                      count: orders.pending,
                      label: context.l10n.statusPending,
                      color: c.warning,
                      bucket: 'pending',
                    ),
                    const SizedBox(width: DsSpacing.sm),
                    _StatusTile(
                      icon: Icons.autorenew_rounded,
                      count: orders.processing,
                      label: context.l10n.statusProcessing,
                      color: c.info,
                      bucket: 'processing',
                    ),
                    const SizedBox(width: DsSpacing.sm),
                    _StatusTile(
                      icon: Icons.local_shipping_outlined,
                      count: orders.delivered,
                      label: context.l10n.statusDelivered,
                      color: c.success,
                      bucket: 'delivered',
                    ),
                    const SizedBox(width: DsSpacing.sm),
                    _StatusTile(
                      icon: Icons.cancel_outlined,
                      count: orders.cancelled,
                      label: context.l10n.statusCancelled,
                      color: c.error,
                      bucket: 'cancelled',
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
    required this.bucket,
  });

  final IconData icon;
  final int count;
  final String label;
  final Color color;

  /// Which pile this tile counts — carried into the orders list so tapping
  /// «ملغاة» opens the cancelled orders rather than all of them.
  final String bucket;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Expanded(
      child: GestureDetector(
        onTap: () => context.push(RoutePaths.ordersInBucket(bucket)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: DsRadius.borderXl,
            border: Border.all(color: c.border.withValues(alpha: 0.5)),
            boxShadow: context.shadowXs,
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: DsRadius.borderMd,
                    ),
                    child: Icon(icon, size: 19, color: color),
                  ),
                  if (count > 0)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: DsSpacing.xxs, vertical: DsSpacing.xxxs),
                        constraints: const BoxConstraints(minWidth: 17),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: DsRadius.borderFull,
                          border: Border.all(color: c.surface, width: 1.5),
                        ),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: context.dsText.micro.bold.tint(DsColors.onMedia),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: DsSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.caption.tint(c.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
