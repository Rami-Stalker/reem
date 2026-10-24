import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/seller_returns/domain/entities/return_request.dart';
import 'package:ohara/features/seller_returns/presentation/providers/seller_returns_provider.dart';
import 'package:ohara/features/seller_returns/presentation/return_labels.dart';
import 'package:ohara/features/seller_returns/presentation/widgets/return_action_sheets.dart';
import 'package:ohara/features/seller_returns/presentation/widgets/return_request_card.dart';

/// The seller's returns desk.
///
/// `/returns/*` has carried the whole lifecycle — accept, refuse, mark in
/// transit, confirm receipt, exchange — since the returns module landed, and
/// nothing in the app had ever called any of it. Her order queue could show a
/// parcel coming back and gave her no way to do a single thing about it.
class SellerReturnsScreen extends ConsumerWidget {
  const SellerReturnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerReturnsNotifierProvider);
    final notifier = ref.read(sellerReturnsNotifierProvider.notifier);
    final l10n = context.l10n;

    ref.listen(sellerReturnsNotifierProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    });

    final rows = state.visible;

    return OharaScrollPage(
      onRefresh: notifier.refresh,
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        AtelierAppBar(
          icon: Icons.assignment_return_rounded,
          title: l10n.sellerReturnsTitle,
          showBack: true,
        ),
        // Air between the banner and the page.
        DsGaps.sliverMd,
        SliverToBoxAdapter(
          child: _TabBar(
            selected: state.tab,
            countFor: state.countFor,
            onSelect: notifier.setTab,
          ),
        ),

        if (state.isInitialLoading)
          const SliverToBoxAdapter(child: _Skeleton())
        else if (state.requests.isEmpty && state.error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
              child: DsErrorState(
                message: state.error ?? l10n.returnsFailed,
                onRetry: notifier.refresh,
              ),
            ),
          )
        else if (rows.isEmpty)
          SliverToBoxAdapter(child: _Empty(tab: state.tab))
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              atelierGutter(context),
              DsSpacing.lg,
              atelierGutter(context),
              DsSizes.bottomSafeGap + DsSpacing.huge,
            ),
            sliver: SliverList.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.md),
              itemBuilder: (context, index) {
                final request = rows[index];
                return ReturnRequestCard(
                  request: request,
                  isActing: state.actingId == request.id,
                  onOpen: () => context.push(
                    RoutePaths.sellerReturnDetailFor(request.id),
                  ),
                  onPrimaryAction: (action) =>
                      runReturnAction(context, ref, request, action),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Runs one transition: asks for whatever it needs, sends it, and says what
/// happened. Shared with the detail screen so both speak identically.
Future<void> runReturnAction(
  BuildContext context,
  WidgetRef ref,
  ReturnRequest request,
  ReturnAction action,
) async {
  final input = await askForReturnAction(context, request, action);
  if (input == null || !context.mounted) return;

  final ok = await ref
      .read(sellerReturnsNotifierProvider.notifier)
      .act(
        request,
        action,
        reason: input.reason,
        note: input.note,
        restock: input.restock,
        shippingBorneBy: input.shippingBorneBy,
      );

  if (!ok || !context.mounted) return;
  // The detail screen reads its own provider, so it has to be told the row it
  // is rendering has moved on.
  ref.invalidate(sellerReturnProvider(request.id));
  DsSnackbar.show(
    context,
    message: context.l10n.returnsUpdated,
    type: DsSnackbarType.success,
  );
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.selected,
    required this.countFor,
    required this.onSelect,
  });

  final ReturnQueueTab selected;
  final int Function(ReturnQueueTab) countFor;
  final ValueChanged<ReturnQueueTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return AtelierBeads<ReturnQueueTab>(
      padding: EdgeInsets.symmetric(horizontal: atelierGutter(context)),
      selected: selected,
      onSelected: onSelect,
      options: [
        for (final tab in ReturnQueueTab.values)
          (
            value: tab,
            label: context.returnTabLabel(tab),
            count: countFor(tab) == 0 ? null : countFor(tab),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.tab});

  final ReturnQueueTab tab;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.xxl,
      ),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: DsRadius.borderXl,
              border: Border.all(color: palette.line),
            ),
            child: Icon(
              Icons.assignment_return_outlined,
              size: 36,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            context.returnTabEmptyTitle(tab),
            textAlign: TextAlign.center,
            style: context.dsText.cardTitle.bold.tint(palette.ink),
          ),
          if (tab == ReturnQueueTab.open) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              context.l10n.returnsEmptyOpenBody,
              textAlign: TextAlign.center,
              style: context.dsText.body.tint(palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: DsShimmer(
        child: Column(
          children: [
            DsSkeleton.box(height: 150, borderRadius: DsRadius.lg),
            SizedBox(height: DsSpacing.md),
            DsSkeleton.box(height: 150, borderRadius: DsRadius.lg),
            SizedBox(height: DsSpacing.md),
            DsSkeleton.box(height: 150, borderRadius: DsRadius.lg),
          ],
        ),
      ),
    );
  }
}
