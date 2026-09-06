import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/value/presentation/providers/value_providers.dart';

/// Her standing, compactly.
///
/// The card that appears on her profile and on home — the two places she is not
/// looking for it — so that standing is a fact about her account rather than a
/// page she has to remember exists.
///
/// It shows a rung and a direction, never a bare number in isolation. "٦٤٠" is
/// a credit rating; "موثوقة، وعم تصعدي" is a place in something.
class ValueStandingCard extends ConsumerWidget {
  const ValueStandingCard({super.key, this.compact = false});

  /// The one-line form used inside a denser layout.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeAsync = ref.watch(valueBadgeProvider);

    return badgeAsync.maybeWhen(
      data: (badge) {
        // No standing yet, or unreachable. A woman who has just arrived is not
        // shown an empty ladder — there is nothing yet to be proud of, and the
        // programme introduces itself when she has done something.
        if (badge == null || badge.tierKey == null) return const SizedBox.shrink();
        return compact
            ? _CompactRow(
                tierName: badge.tierName ?? '',
                momentum: badge.momentum,
                onTap: () => context.push(RoutePaths.value),
              )
            : _FullCard(
                score: badge.score,
                tierName: badge.tierName ?? '',
                momentum: badge.momentum,
                nextTierName: badge.nextTierName,
                toNextTier: badge.toNextTier,
                onTap: () => context.push(RoutePaths.value),
              );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _FullCard extends StatelessWidget {
  const _FullCard({
    required this.score,
    required this.tierName,
    required this.momentum,
    required this.nextTierName,
    required this.toNextTier,
    required this.onTap,
  });

  final int score;
  final String tierName;
  final int momentum;
  final String? nextTierName;
  final int toNextTier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, size: 18, color: colors.primary),
              const SizedBox(width: DsSpacing.xs),
              Expanded(
                child: Text('مكانتك بريم', style: context.dsText.labelStrong),
              ),
              const Icon(Icons.chevron_left_rounded, size: 18),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(tierName, style: context.dsText.pageTitle),
              const SizedBox(width: DsSpacing.xs),
              if (momentum != 0) _MomentumChip(momentum: momentum),
            ],
          ),
          if (nextTierName != null && toNextTier > 0) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              // Deliberately not "٦٠ نقطة". The standing screen turns the gap
              // into things she could do; the card only says there is one.
              'قريبة من $nextTierName',
              style: context.dsText.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.tierName,
    required this.momentum,
    required this.onTap,
  });

  final String tierName;
  final int momentum;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DsRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.sm,
          vertical: DsSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded, size: 14, color: colors.primary),
            const SizedBox(width: 4),
            Text(tierName, style: context.dsText.captionStrong),
            if (momentum != 0) ...[
              const SizedBox(width: 4),
              _MomentumChip(momentum: momentum),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rising or fading, in one glyph.
///
/// The single most important thing on the card, because it is the thing a
/// points balance can never say. A balance only goes up; a relationship has a
/// direction, and showing it is what makes standing feel alive rather than
/// accumulated.
class _MomentumChip extends StatelessWidget {
  const _MomentumChip({required this.momentum});

  final int momentum;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final rising = momentum > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: rising ? colors.successContainer : colors.surfaceVariant,
        borderRadius: BorderRadius.circular(DsRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            rising ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 12,
            color: rising ? colors.success : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 2),
          Text(
            rising ? 'عم تصعدي' : 'هدوء',
            style: context.dsText.micro.tint(
              rising ? colors.success : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
