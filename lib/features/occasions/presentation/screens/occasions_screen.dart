import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/occasions/presentation/providers/occasions_providers.dart';
import 'package:ohara/features/occasions/presentation/widgets/occasion_card.dart';

/// «مناسباتي».
///
/// Two tabs, the way she thinks about them: the days coming, and the days
/// that have been. The past is kept rather than cleared, because it is what
/// the repeat warning reads — «لبستِ هذا بخطوبة لينا» needs a record of
/// what she wore to Lina's engagement.
class OccasionsScreen extends ConsumerStatefulWidget {
  const OccasionsScreen({super.key});

  @override
  ConsumerState<OccasionsScreen> createState() => _OccasionsScreenState();
}

class _OccasionsScreenState extends ConsumerState<OccasionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: OharaAppBar(
        title: context.l10n.occasionsTitle,
        actions: [
          IconButton(
            tooltip: context.l10n.occasionAdd,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push(RoutePaths.occasionNew),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: context.l10n.occasionsUpcoming),
            Tab(text: context.l10n.occasionsPast),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _OccasionList(upcoming: true),
          _OccasionList(upcoming: false),
        ],
      ),
    );
  }
}

class _OccasionList extends ConsumerWidget {
  const _OccasionList({required this.upcoming});

  final bool upcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(occasionsProvider(upcoming));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(occasionsProvider(upcoming)),
      child: async.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.occasionsLoadError,
          onRetry: () => ref.invalidate(occasionsProvider(upcoming)),
        ),
        data: (occasions) => occasions.isEmpty
            ? _Empty(upcoming: upcoming)
            : ListView.separated(
                padding: const EdgeInsets.all(DsSpacing.lg),
                itemCount: occasions.length,
                separatorBuilder: (_, _) => DsGaps.vMd,
                itemBuilder: (context, index) {
                  final occasion = occasions[index];
                  return OccasionCard(
                    occasion: occasion,
                    onTap: () =>
                        context.push(RoutePaths.occasionOf(occasion.id)),
                  );
                },
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.upcoming});

  final bool upcoming;

  @override
  Widget build(BuildContext context) {
    // A scroll view, so pull-to-refresh still works on an empty list.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        DsGaps.vXxxl,
        DsEmptyState(
          icon: upcoming ? Icons.celebration_rounded : Icons.history_rounded,
          title: upcoming
              ? context.l10n.occasionsEmptyTitle
              : context.l10n.occasionsPastEmptyTitle,
          message: upcoming
              ? context.l10n.occasionsEmptyBody
              : context.l10n.occasionsPastEmptyBody,
          actionLabel: context.l10n.occasionAdd,
          onAction: () => context.push(RoutePaths.occasionNew),
        ),
      ],
    );
  }
}
