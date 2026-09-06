import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/closet/domain/entities/closet_item.dart';
import 'package:reem/features/closet/domain/repositories/closet_repository.dart';
import 'package:reem/features/closet/presentation/providers/closet_providers.dart';

/// One garment.
///
/// Leads with rotation rather than with the purchase. Cost-per-wear is the
/// number that changes how a wardrobe feels — a dress worn thirty times is a
/// different object from one worn once, whatever either cost — and it is a
/// number no shop has any incentive to show her.
class ClosetItemScreen extends ConsumerWidget {
  const ClosetItemScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final itemAsync = ref.watch(closetItemProvider(itemId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: ReemAppBar(
        title: 'قطعة من خزانتي',
        actions: [
          itemAsync.maybeWhen(
            data: (item) => IconButton(
              icon: Icon(
                item.isFavourite
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                color: item.isFavourite ? colors.favorite : null,
              ),
              onPressed: () => ref.read(closetActionsProvider).updateItem(
                    itemId,
                    ClosetItemPatch(isFavourite: !item.isFavourite),
                  ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: itemAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: 'ما قدرنا نفتح القطعة.',
          onRetry: () => ref.invalidate(closetItemProvider(itemId)),
        ),
        data: (item) => _Body(item: item),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.item});

  final ClosetItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final url = item.imageUrl;

    return ListView(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: url == null || url.isEmpty
              ? Container(
                  color: colors.surfaceVariant,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.checkroom_rounded,
                    size: 64,
                    color: colors.onSurfaceVariant,
                  ),
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) =>
                      Container(color: colors.surfaceVariant),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(DsSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: context.dsText.pageTitle),
              const SizedBox(height: 2),
              Text(
                '${item.slotLabel} · ${item.sourceLabel}',
                style: context.dsText.bodyMuted,
              ),

              const SizedBox(height: DsSpacing.md),
              Row(
                children: [
                  _Stat(value: '${item.wearCount}', label: 'مرة لبستيها'),
                  _Stat(
                    value: item.costPerWear?.format() ?? '—',
                    label: 'كلفة اللبسة',
                  ),
                  _Stat(
                    value: _lastWorn(),
                    label: 'آخر مرة',
                  ),
                ],
              ),

              const SizedBox(height: DsSpacing.md),
              DsButton(
                label: 'لبستها اليوم',
                icon: Icons.check_rounded,
                onPressed: () =>
                    ref.read(closetActionsProvider).logWear(item.id),
              ),

              const SizedBox(height: DsSpacing.lg),
              Text('التفاصيل', style: context.dsText.sectionTitle),
              const SizedBox(height: DsSpacing.xs),
              Wrap(
                spacing: DsSpacing.xs,
                runSpacing: DsSpacing.xs,
                children: [
                  for (final colour in item.colours) DsChip(label: colour.label),
                  for (final material in item.materials) DsChip(label: material),
                  for (final season in item.seasons) DsChip(label: season.label),
                  if (item.size != null) DsChip(label: 'مقاس ${item.size}'),
                  if (item.brandName != null) DsChip(label: item.brandName!),
                ],
              ),

              if (item.occasions.isNotEmpty) ...[
                const SizedBox(height: DsSpacing.md),
                Text('بتناسب', style: context.dsText.labelStrong),
                const SizedBox(height: DsSpacing.xs),
                Wrap(
                  spacing: DsSpacing.xs,
                  runSpacing: DsSpacing.xs,
                  children: [
                    for (final occasion in item.occasions)
                      DsChip(label: occasion.label),
                  ],
                ),
              ],

              if (item.productId != null) ...[
                const SizedBox(height: DsSpacing.md),
                DsButton(
                  label: 'شوفي القطعة بالمتجر',
                  variant: DsButtonVariant.secondary,
                  onPressed: () => context.push(
                    RoutePaths.productDetailsOf(item.productId!),
                  ),
                ),
              ],

              const SizedBox(height: DsSpacing.lg),
              // Two different requests, offered separately. Archiving says "not
              // this season"; releasing says "I no longer own it" and keeps the
              // history, which is what replacement gaps and cost-per-wear are
              // built on.
              _StatusRow(item: item),

              const SizedBox(height: DsSpacing.md),
              TextButton(
                onPressed: () => _delete(context, ref),
                child: Text(
                  'احذفيها نهائيًا',
                  style: TextStyle(color: colors.error),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _lastWorn() {
    if (!item.hasBeenWorn) return 'أبدًا';
    final days = item.daysSinceWorn ?? 0;
    if (days == 0) return 'اليوم';
    if (days == 1) return 'مبارح';
    if (days < 30) return 'من $days يوم';
    return 'من ${(days / 30).floor()} شهر';
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    await ref.read(closetActionsProvider).removeItem(item.id);
    if (!context.mounted) return;
    context.pop();
  }
}

class _StatusRow extends ConsumerWidget {
  const _StatusRow({required this.item});

  final ClosetItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(closetActionsProvider);

    return Row(
      children: [
        Expanded(
          child: DsButton(
            label: item.status == ClosetItemStatus.archived
                ? 'رجّعيها للخزانة'
                : 'اركنيها للموسم',
            variant: DsButtonVariant.secondary,
            size: DsButtonSize.sm,
            onPressed: () => actions.setStatus(
              item.id,
              item.status == ClosetItemStatus.archived
                  ? ClosetItemStatus.active
                  : ClosetItemStatus.archived,
            ),
          ),
        ),
        const SizedBox(width: DsSpacing.xs),
        Expanded(
          child: DsButton(
            label: 'ما عادت عندي',
            variant: DsButtonVariant.secondary,
            size: DsButtonSize.sm,
            onPressed: () =>
                actions.setStatus(item.id, ClosetItemStatus.released),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.metricSmall,
          ),
          Text(label, style: context.dsText.metricLabel),
        ],
      ),
    );
  }
}
