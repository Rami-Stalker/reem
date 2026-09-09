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
                      style: context.dsText.cardTitle
                          .copyWith(fontWeight: DsTypography.bold),
                    ),
                    if (highPriority > 0)
                      Text(
                        '$highPriority ${context.l10n.adminPriorityUrgent}',
                        style: context.dsText.caption
                            .copyWith(color: c.error, fontWeight: DsTypography.semiBold),
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
                  bottom: e.key < tasks.length - DsSpacing.xxxs ? DsSpacing.xs : DsSpacing.xxxs),
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
    final isHigh = task.priority == TaskPriority.high;
    final color = context.toneColor(task.priorityTone);

    return Container(
      margin: const EdgeInsets.only(bottom: DsSpacing.xxxs),
      padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.md, vertical: DsSpacing.sm + DsSpacing.xxxs),
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
                          style: context.dsText.micro.bold.tint(DsColors.onMedia),
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
                  style: context.dsText.tileTitle.copyWith(
                    fontWeight: DsTypography.semiBold,
                    color: isHigh ? color : c.onSurface,
                  ),
                ),
                Text(
                  task.subtitle,
                  style: context.dsText.caption
                      .copyWith(color: c.onSurfaceVariant, fontSize: DsTypography.labelSmall),
                ),
              ],
            ),
          ),
          const SizedBox(width: DsSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.xs, vertical: DsSpacing.xxs),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: DsRadius.borderFull,
            ),
            child: Text(
              task.priority.name.toUpperCase(),
              style: context.dsText.micro.bold.tint(color),
            ),
          ),
        ],
      ),
    );
  }
}
