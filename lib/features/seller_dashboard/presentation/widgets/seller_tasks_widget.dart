import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_misc.dart';
import 'package:reem/features/seller_dashboard/presentation/providers/seller_dashboard_provider.dart';

class SellerTasksWidget extends ConsumerWidget {
  const SellerTasksWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final c = context.dsColors;
    final theme = Theme.of(context);

    if (state.isInitialLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
            child: DsSkeleton.box(height: 180, borderRadius: DsRadius.xxl)),
      );
    }

    final tasks = state.data?.pendingTasks ?? [];
    if (tasks.isEmpty) return const SizedBox.shrink();

    final highPriority = tasks.where((t) => t.priority == TaskPriority.high).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.sellerTasks,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: DsTypography.bold),
                    ),
                    if (highPriority > 0)
                      Text(
                        '$highPriority urgent',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: c.error, fontWeight: DsTypography.semiBold),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          ...tasks.asMap().entries.map((e) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: e.key < tasks.length - 1 ? DsSpacing.xs : 0),
              child: _TaskTile(task: e.value)
                  .animate(delay: (e.key * 60).ms)
                  .fadeIn(duration: 300.ms)
                  .slideX(begin: 0.03, end: 0, duration: 300.ms),
            );
          }),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final SellerTask task;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final isHigh = task.priority == TaskPriority.high;
    final color = task.priorityColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.md, vertical: DsSpacing.sm + 2),
      decoration: BoxDecoration(
        color: isHigh ? color.withValues(alpha: 0.06) : c.card,
        borderRadius: DsRadius.borderLg,
        border: Border.all(
          color: isHigh
              ? color.withValues(alpha: 0.3)
              : c.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: DsRadius.borderSm,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(task.icon, size: 18, color: color),
                if (task.count != null)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${task.count}',
                          style: const TextStyle(
                            fontFamily: DsTypography.fontFamily,
                            fontSize: 8,
                            fontWeight: DsTypography.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: DsTypography.semiBold,
                    color: isHigh ? color : c.onSurface,
                  ),
                ),
                Text(
                  task.subtitle,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: c.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: DsSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.xs, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: DsRadius.borderFull,
            ),
            child: Text(
              task.priority.name.toUpperCase(),
              style: TextStyle(
                fontFamily: DsTypography.fontFamily,
                fontSize: 9,
                fontWeight: DsTypography.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
