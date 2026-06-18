import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design_system/design_system.dart';
import '../../domain/entities/seller_misc.dart';
import '../providers/seller_dashboard_provider.dart';

class SellerGoalsWidget extends ConsumerWidget {
  const SellerGoalsWidget({super.key});

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

    final goals = state.data?.goals ?? [];
    if (goals.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.lg),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: DsRadius.borderXxl,
          border: Border.all(color: c.border.withValues(alpha: 0.5)),
          boxShadow: context.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 18, color: c.primary),
                const SizedBox(width: DsSpacing.xs),
                Text(
                  'Store goals',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: DsTypography.bold),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
            ...goals.asMap().entries.map((e) {
              return Padding(
                padding: EdgeInsets.only(
                    bottom: e.key < goals.length - 1 ? DsSpacing.md : 0),
                child: _GoalRow(goal: e.value)
                    .animate(delay: (e.key * 70).ms)
                    .fadeIn(duration: 300.ms),
              );
            }),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .slideY(begin: 0.04, end: 0, duration: 380.ms);
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});

  final SellerGoal goal;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final isComplete = goal.isComplete;
    final color = isComplete ? c.success : c.primary;
    final pct = (goal.progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(goal.icon, size: 15, color: color),
            const SizedBox(width: DsSpacing.xs),
            Expanded(
              child: Text(
                goal.label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: DsTypography.semiBold),
              ),
            ),
            Text(
              isComplete
                  ? '✓ Done'
                  : '${goal.unit}${_fmt(goal.current)} / ${goal.unit}${_fmt(goal.target)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isComplete ? c.success : c.onSurfaceVariant,
                fontWeight:
                    isComplete ? DsTypography.bold : DsTypography.regular,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: DsSpacing.xs),
            SizedBox(
              width: 32,
              child: Text(
                '$pct%',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontSize: 11,
                  fontWeight: DsTypography.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.xxs),
        ClipRRect(
          borderRadius: DsRadius.borderFull,
          child: Stack(
            children: [
              Container(height: 6, color: c.surfaceVariant),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                widthFactor: goal.progress,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.7), color],
                    ),
                    borderRadius: DsRadius.borderFull,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(v == v.toInt() ? 0 : 1);
  }
}
