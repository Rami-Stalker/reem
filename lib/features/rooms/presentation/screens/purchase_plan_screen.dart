import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/rooms/domain/entities/room.dart';
import 'package:ohara/features/rooms/presentation/providers/rooms_providers.dart';

/// خطة الشرا — what the room decided, as something buyable.
///
/// This is the screen that replaces the cart, and the two differences are
/// visible on it:
///
///  - **Every line says what it answers.** "الفستان — فستان كحلي" rather than a
///    product floating in a list, because a plan is a record of decisions.
///  - **Lines can wait.** "هلق" and "بعدين" are the plan's own idea; a cart
///    forces "the shoes next month" to be a deletion she has to remember.
class PurchasePlanScreen extends ConsumerWidget {
  const PurchasePlanScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final roomAsync = ref.watch(roomProvider(roomId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: OharaAppBar(title: context.l10n.roomsPlanTitle),
      body: roomAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.roomsPlanFailed,
          onRetry: () => ref.invalidate(roomProvider(roomId)),
        ),
        data: (room) {
          final plan = room.plan;
          if (plan == null) {
            return DsEmptyState(
              icon: Icons.checklist_rounded,
              title: context.l10n.roomsNoPlanTitle,
              message: context.l10n.roomsNoPlanBody,
            );
          }
          return _Body(room: room, plan: plan);
        },
      ),
      bottomNavigationBar: roomAsync.maybeWhen(
        data: (room) => room.plan == null
            ? null
            : _CheckoutBar(room: room, plan: room.plan!),
        orElse: () => null,
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.room, required this.plan});

  final Room room;
  final PurchasePlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(DsSpacing.md),
      children: [
        _BudgetCard(room: room, plan: plan),
        const SizedBox(height: DsSpacing.md),

        Text(context.l10n.roomsPlanNow, style: context.dsText.sectionTitle),
        const SizedBox(height: DsSpacing.xs),
        if (plan.now.isEmpty)
          Text(
            context.l10n.roomsPlanNothingNow,
            style: context.dsText.bodyMuted,
          )
        else
          for (final item in plan.now)
            _PlanLine(
              room: room,
              plan: plan,
              item: item,
              unavailable: plan.unavailableItemIds.contains(item.id),
            ),

        if (plan.later.isNotEmpty) ...[
          const SizedBox(height: DsSpacing.lg),
          Text(context.l10n.roomsPlanLater, style: context.dsText.sectionTitle),
          Text(
            // The plan's own idea, said once so it is understood.
            context.l10n.roomsPlanLaterBody,
            style: context.dsText.sectionSubtitle,
          ),
          const SizedBox(height: DsSpacing.xs),
          for (final item in plan.later)
            _PlanLine(
              room: room,
              plan: plan,
              item: item,
              unavailable: plan.unavailableItemIds.contains(item.id),
            ),
        ],

        const SizedBox(height: DsSpacing.xxl),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.room, required this.plan});

  final Room room;
  final PurchasePlan plan;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final budget = plan.budget;

    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.roomsPlanTotal,
                  style: context.dsText.labelStrong,
                ),
              ),
              Text(
                plan.total?.format() ?? '—',
                style: context.dsText.metricSmall,
              ),
            ],
          ),
          if (budget.hasBudget) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              switch (budget.verdict) {
                'over' => context.l10n.roomsOverBudget(
                  budget.overBy?.format() ?? '',
                ),
                'under' => context.l10n.roomsUnderBudget,
                _ => context.l10n.roomsWithinBudget,
              },
              style: context.dsText.caption.tint(
                budget.isOver ? colors.warning : colors.success,
              ),
            ),
          ],
          if (budget.unpricedCount > 0) ...[
            DsGaps.vXxxs,
            Text(
              // An unknown price is not a free one, and the total says so.
              context.l10n.roomsUnpriced(budget.unpricedCount),
              style: context.dsText.micro.tint(colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanLine extends ConsumerWidget {
  const _PlanLine({
    required this.room,
    required this.plan,
    required this.item,
    this.unavailable = false,
  });

  final Room room;
  final PurchasePlan plan;
  final PlanItem item;
  final bool unavailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final actions = ref.read(roomActionsProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.xs),
      child: SurfaceCard(
        padding: const EdgeInsets.all(DsSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(DsRadius.sm),
              child: SizedBox(
                width: 56,
                height: 68,
                child: item.image == null
                    ? Container(color: colors.surfaceVariant)
                    : AuthorizedMediaImage(
                        url: item.image!,
                        fallback: Container(color: colors.surfaceVariant),
                      ),
              ),
            ),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // What this line answers. The difference between a plan line
                  // and a cart line, on the card.
                  if (item.decisionTitle != null)
                    Text(
                      item.decisionTitle!,
                      style: context.dsText.micro.tint(colors.primary),
                    ),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.tileTitle,
                  ),
                  Text(item.sellerName, style: context.dsText.micro),
                  DsGaps.vXxxs,
                  Text(
                    item.lineTotal?.format() ?? '—',
                    style: context.dsText.price,
                  ),
                  if (unavailable) ...[
                    DsGaps.vXxxs,
                    Text(
                      context.l10n.roomsNoLongerAvailable,
                      style: context.dsText.micro.tint(colors.error),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: item.stage == PurchaseStage.now
                      ? context.l10n.roomsPostpone
                      : context.l10n.roomsPlanNow,
                  icon: Icon(
                    item.stage == PurchaseStage.now
                        ? Icons.schedule_rounded
                        : Icons.shopping_bag_rounded,
                    size: 18,
                  ),
                  onPressed: () => actions.setStage(
                    room.id,
                    plan.id,
                    item.id,
                    item.stage == PurchaseStage.now
                        ? PurchaseStage.later
                        : PurchaseStage.now,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.roomsRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () =>
                      actions.removePlanItem(room.id, plan.id, item.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutBar extends ConsumerWidget {
  const _CheckoutBar({required this.room, required this.plan});

  final Room room;
  final PurchasePlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (plan.unavailableItemIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.xs),
                child: Text(
                  context.l10n.roomsRemoveUnavailableFirst,
                  style: context.dsText.caption.tint(colors.error),
                ),
              ),
            DsButton(
              label: plan.hasLater
                  ? context.l10n.roomsBuyNowCount(plan.now.length)
                  : context.l10n.roomsBuyCount(plan.now.length),
              onPressed: plan.canBuy
                  ? () => context.push(
                      RoutePaths.checkout,
                      extra: {'room_id': room.id, 'plan_id': plan.id},
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
