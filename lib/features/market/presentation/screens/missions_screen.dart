import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/market/domain/entities/market.dart';
import 'package:reem/features/market/presentation/providers/market_providers.dart';

/// أشياء تستاهل — at most three, and each one worth doing on its own terms.
///
/// There is no points total on this screen, no streak, no badge shelf, and
/// that is the design rather than an omission. A mission asks for something
/// whose payoff is the thing itself — a described closet gives better
/// suggestions, a reviewed dress helps the next woman — and adding a currency
/// on top would turn a useful act into a farmed one.
///
/// The progress bar is read from the server, which recomputes it from rows the
/// missions system did not write. Nothing here can move it, which is why there
/// is no "I did it" button.
class MissionsScreen extends ConsumerWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final async = ref.watch(missionsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: const ReemAppBar(title: 'أشياء تستاهل'),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(missionsProvider),
        child: async.when(
          loading: () => const Center(child: DsLoadingIndicator()),
          error: (_, _) => DsErrorState(
            message: 'ما قدرنا نجيب المهام.',
            onRetry: () => ref.invalidate(missionsProvider),
          ),
          data: (missions) => missions.isEmpty
              ? const DsEmptyState(
                  icon: Icons.done_all_rounded,
                  title: 'ما في شي مطلوب منك هلق',
                  // Explains the rule rather than apologising: nothing is
                  // offered that she cannot actually finish.
                  message:
                      'أوهارا ما بتطلب منك شي إلا لما يكون في شي فعلاً يستاهل وبتقدري تخلّصيه.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(DsSpacing.lg),
                  itemCount: missions.length,
                  separatorBuilder: (_, _) => DsGaps.vMd,
                  itemBuilder: (_, index) =>
                      _MissionCard(mission: missions[index]),
                ),
        ),
      ),
    );
  }
}

class _MissionCard extends ConsumerWidget {
  const _MissionCard({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final done = mission.isComplete;

    return DsGlassCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : _iconFor(mission.kind),
                size: 18,
                color: done ? colors.success : colors.primary,
              ),
              DsGaps.hXs,
              Expanded(
                child: Text(
                  mission.title,
                  style: context.dsText.cardTitle.tint(colors.onSurface),
                ),
              ),
            ],
          ),
          DsGaps.vXs,
          Text(
            mission.body,
            style: context.dsText.caption.tint(colors.onSurfaceVariant),
          ),
          DsGaps.vMd,
          ClipRRect(
            borderRadius: BorderRadius.circular(DsRadius.pill),
            child: LinearProgressIndicator(
              value: mission.progress,
              minHeight: 5,
              backgroundColor: colors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(
                done ? colors.success : colors.primary,
              ),
            ),
          ),
          DsGaps.vXs,
          Row(
            children: [
              Expanded(
                child: Text(
                  done
                      ? 'خلصانة'
                      // The counts behind the bar, so it can be checked rather
                      // than believed — and `done` is what she has done since
                      // being asked, not her lifetime total.
                      : '${mission.done} من ${mission.target}',
                  style: context.dsText.micro.tint(colors.onSurfaceVariant),
                ),
              ),
              if (!done)
                TextButton(
                  onPressed: () => _decline(context, ref, mission),
                  child: Text(
                    'مو هلق',
                    style: context.dsText.micro.tint(colors.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// She can say no, and be believed — the server holds it for sixty days.
  Future<void> _decline(
    BuildContext context,
    WidgetRef ref,
    Mission mission,
  ) async {
    final result = await ref
        .read(marketRepositoryProvider)
        .declineMission(mission.key);
    if (!context.mounted) return;
    result.fold(
      (failure) => DsSnackbar.error(context, failure.message),
      (_) => ref.invalidate(missionsProvider),
    );
  }

  static IconData _iconFor(String kind) => switch (kind) {
    'DISCOVER' => Icons.explore_outlined,
    'CONTRIBUTE' => Icons.rate_review_outlined,
    'SHARE' => Icons.ios_share_rounded,
    _ => Icons.checklist_rounded,
  };
}
