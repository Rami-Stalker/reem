import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../domain/entities/profile_overview.dart';
import '../providers/profile_overview_provider.dart';
import '../../../../core/localization/l10n_extension.dart';

/// Profile completion — a progress ring, the next nudge and a checklist of
/// steps. Collapses into a celebratory state at 100%.
class ProfileCompletionCard extends ConsumerWidget {
  const ProfileCompletionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      profileOverviewNotifierProvider.select((s) => s.isInitialLoading),
    );
    final overview = ref.watch(
      profileOverviewNotifierProvider.select((s) => s.overview),
    );

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
            child: DsSkeleton.box(height: 132, borderRadius: DsRadius.xxl)),
      );
    }
    if (overview == null || overview.completionSteps.isEmpty) {
      return const SizedBox.shrink();
    }

    final c = context.dsColors;
    final theme = Theme.of(context);
    final complete = overview.completionPercent >= 100;
    final next = overview.nextStep;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CompletionRing(percent: overview.completionPercent),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complete ? context.l10n.allSet : context.l10n.completeProfile,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: DsTypography.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        complete
                            ? context.l10n.profileLooksBeautiful
                            : next != null
                                ? context.l10n.nextStep(next.label)
                                : context.l10n.quickSteps,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: c.onSurfaceVariant),
                      ),
                      if (!complete) ...[
                        const SizedBox(height: DsSpacing.sm),
                        DsButton(
                          label: context.l10n.completeProfile,
                          size: DsButtonSize.sm,
                          variant: DsButtonVariant.tonal,
                          isExpanded: false,
                          onPressed: () => context.push(RoutePaths.editProfile),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
            Wrap(
              spacing: DsSpacing.xs,
              runSpacing: DsSpacing.xs,
              children: [
                for (final step in overview.completionSteps)
                  _StepChip(step: step),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionRing extends StatelessWidget {
  const _CompletionRing({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 6,
              color: c.primary.withValues(alpha: 0.12),
            ),
          ),
          SizedBox(
            width: 64,
            height: 64,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percent / 100),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                color: c.primary,
              ),
            ),
          ),
          Text(
            '$percent%',
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontWeight: DsTypography.bold,
              fontSize: DsTypography.labelLarge,
              color: c.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.step});

  final ProfileCompletionStep step;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: step.done ? c.successContainer : c.surfaceVariant,
        borderRadius: DsRadius.borderFull,
        border: Border.all(
          color: step.done ? c.success.withValues(alpha: 0.3) : c.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            step.done ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: step.done ? c.success : c.onSurfaceVariant,
          ),
          const SizedBox(width: DsSpacing.xxs),
          Text(
            step.label,
            style: TextStyle(
              fontSize: DsTypography.labelSmall,
              fontWeight: DsTypography.medium,
              color: step.done ? c.onSurface : c.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
