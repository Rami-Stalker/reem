import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/profile/domain/entities/profile_overview.dart';
import 'package:ohara/features/profile/presentation/providers/profile_overview_provider.dart';

/// Profile completion — a progress ring, the next nudge and a checklist of
/// steps.
///
/// It draws nothing at all once there is nothing left to complete. It used to
/// turn into a congratulation — «كل شيء مكتمل / ملفك يبدو رائعًا» — which then
/// sat at the top of the profile for ever, in front of the orders, the wallet
/// and the wishlist, telling her something she had already done.
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

    // Nothing left to ask for, so nothing to say. A card whose entire content
    // is «كل شيء مكتمل» is a congratulation she has already read, sitting
    // permanently at the top of her profile above the things she came for.
    // The completion card exists to prompt; with no prompt left it goes.
    if (overview.completionPercent >= 100) return const SizedBox.shrink();

    final c = context.dsColors;
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
                        context.l10n.completeProfile,
                        style: context.dsText.cardTitle
                            .copyWith(fontWeight: DsTypography.bold),
                      ),
                      DsGaps.vXxxs,
                      Text(
                        next != null
                            ? context.l10n.nextStep(next.label)
                            : context.l10n.quickSteps,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.cardSubtitle
                            .copyWith(color: c.onSurfaceVariant),
                      ),
                      if (next != null) ...[
                        const SizedBox(height: DsSpacing.sm),
                        DsButton(
                          label: context.l10n.completeProfile,
                          size: DsButtonSize.sm,
                          variant: DsButtonVariant.tonal,
                          isExpanded: false,
                          onPressed: () => context.push(_routeFor(next)),
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
                  _StepChip(
                    step: step,
                    // A chip that cannot be acted on is a label, and a
                    // checklist of labels reads as decoration. Each unfinished
                    // step opens the screen that finishes it.
                    onTap: step.done
                        ? null
                        : () => context.push(_routeFor(step)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Where a step is completed.
///
/// Her name, photograph, bio and recovery address are all fields on the edit
/// screen; a phone number is proved somewhere else entirely, on the security
/// screen, and sending her to the edit form for it would be a dead end.
String _routeFor(ProfileCompletionStep step) => switch (step.key) {
  'phone_verified' => RoutePaths.securitySettings,
  _ => RoutePaths.editProfile,
};

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
            style: context.dsText.labelLarge.bold.tint(c.onSurface),
          ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.step, this.onTap});

  final ProfileCompletionStep step;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: DsSpacing.xxs),
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
            style: context.dsText.caption.tint(step.done ? c.onSurface : c.onSurfaceVariant),
          ),
          if (onTap != null) ...[
            const SizedBox(width: DsSpacing.xxs),
            Icon(Icons.chevron_left_rounded, size: 14, color: c.primary),
          ],
        ],
      ),
    );

    if (onTap == null) return chip;
    return Semantics(
      button: true,
      label: step.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.borderFull,
        child: chip,
      ),
    );
  }
}
