import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/achievement.dart';
import '../providers/profile_overview_provider.dart';
import 'profile_section_header.dart';

/// Gamified badges — a rail of achievement medallions. Earned badges glow in
/// champagne gold; locked ones are muted with a lock. Tapping opens detail.
class ProfileAchievements extends ConsumerWidget {
  const ProfileAchievements({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      profileOverviewNotifierProvider.select((s) => s.isInitialLoading),
    );
    final achievements = ref.watch(
      profileOverviewNotifierProvider
          .select((s) => s.overview?.achievements ?? const <Achievement>[]),
    );
    final earned = ref.watch(
      profileOverviewNotifierProvider
          .select((s) => s.overview?.earnedAchievements ?? 0),
    );

    if (!isLoading && achievements.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeader(
          eyebrow: isLoading ? null : '$earned of ${achievements.length} earned',
          title: 'Achievements',
        ),
        SizedBox(
          height: 104,
          child: isLoading
              ? _skeleton()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                  itemCount: achievements.length,
                  separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
                  itemBuilder: (context, i) => _Badge(achievement: achievements[i]),
                ),
        ),
      ],
    );
  }

  Widget _skeleton() {
    return DsShimmer(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
        itemBuilder: (_, _) => const Column(
          children: [
            DsSkeleton.circle(size: 64),
            SizedBox(height: DsSpacing.xs),
            DsSkeleton.line(width: 48),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.achievement});

  final Achievement achievement;

  void _showDetail(BuildContext context) {
    final c = context.dsColors;
    DsBottomSheet.showTitled(
      context,
      title: achievement.label,
      subtitle: achievement.earned ? 'Earned' : 'Locked',
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: achievement.earned ? DsGradients.champagne : null,
              color: achievement.earned ? null : c.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(achievement.icon,
                color: achievement.earned ? Colors.white : c.onSurfaceVariant),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Text(achievement.description,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final earned = achievement.earned;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: earned ? DsGradients.champagne : null,
                    color: earned ? null : c.surfaceVariant,
                    shape: BoxShape.circle,
                    border: earned ? null : Border.all(color: c.border),
                    boxShadow: earned
                        ? context.glowShadow(c.accent, blur: 16, alpha: 0.3)
                        : null,
                  ),
                  child: Icon(
                    achievement.icon,
                    size: 28,
                    color: earned ? Colors.white : c.onSurfaceVariant,
                  ),
                ),
                if (!earned)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: c.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock_rounded,
                          size: 12, color: c.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DsSpacing.xs),
            Text(
              achievement.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: DsTypography.labelSmall,
                fontWeight: DsTypography.medium,
                color: earned ? c.onSurface : c.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
