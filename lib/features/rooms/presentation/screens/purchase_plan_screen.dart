import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/rooms/domain/entities/room.dart';
import 'package:reem/features/rooms/presentation/providers/rooms_providers.dart';

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
      appBar: const ReemAppBar(title: 'خطة الشرا'),
      body: roomAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: 'ما قدرنا نجيب الخطة.',
          onRetry: () => ref.invalidate(roomProvider(roomId)),
        ),
        data: (room) {
          final plan = room.plan;
          if (plan == null) {
            return const DsEmptyState(
              icon: Icons.checklist_rounded,
              title: 'ما في خطة بعد',
              message: 'احسمي قرارات الغرفة، وبعدها منجهّزلك الخطة.',
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

        Text('هلق', style: context.dsText.sectionTitle),
        const SizedBox(height: DsSpacing.xs),
        if (plan.now.isEmpty)
          Text('ما في شي مجهّز للشرا هلق.', style: context.dsText.bodyMuted)
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
          Text('بعدين', style: context.dsText.sectionTitle),
          Text(
            // The plan's own idea, said once so it is understood.
            'بتضل محفوظة بالخطة — بتشتريها لما تجهزي.',
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
                child: Text('المجموع', style: context.dsText.labelStrong),
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
                'over' => 'فوق ميزانيتك بـ${budget.overBy?.format() ?? ''}',
                'under' => 'تحت ميزانيتك',
                _ => 'ضمن ميزانيتك',
              },
              style: context.dsText.caption.tint(
                budget.isOver ? colors.warning : colors.success,
              ),
            ),
          ],
          if (budget.unpricedCount > 0) ...[
            const SizedBox(height: 2),
            Text(
              // An unknown price is not a free one, and the total says so.
              '${budget.unpricedCount} قطعة ما قدرنا نسعّرها',
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
                  const SizedBox(height: 2),
                  Text(
                    item.lineTotal?.format() ?? '—',
                    style: context.dsText.price,
                  ),
                  if (unavailable) ...[
                    const SizedBox(height: 2),
                    Text(
                      'ما عادت متوفرة',
                      style: context.dsText.micro.tint(colors.error),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: item.stage == PurchaseStage.now ? 'أجّليها' : 'هلق',
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
                  tooltip: 'شيليها',
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
                  'شيلي القطع يلي ما عادت متوفرة قبل ما تكملي.',
                  style: context.dsText.caption.tint(colors.error),
                ),
              ),
            DsButton(
              label: plan.hasLater
                  ? 'اشتري يلي لهلق (${plan.now.length})'
                  : 'اشتري (${plan.now.length})',
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
