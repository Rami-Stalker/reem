import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/media_lightbox.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/repositories/closet_repository.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_visuals.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_wear_feedback.dart';

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
      appBar: OharaAppBar(
        title: context.l10n.closetPieceTitle,
        actions: [
          itemAsync.maybeWhen(
            data: (item) => IconButton(
              tooltip: item.isFavourite
                  ? context.l10n.closetRemoveFavourite
                  : context.l10n.closetAddFavourite,
              icon: Icon(
                item.isFavourite
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                color: item.isFavourite ? colors.favorite : null,
              ),
              onPressed: () => ref
                  .read(closetActionsProvider)
                  .updateItem(
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
          message: context.l10n.closetPieceLoadFailed,
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
    final l10n = context.l10n;
    final text = context.dsText;
    final palette = context.boutique;
    final shelved = item.status == ClosetItemStatus.archived;
    final wornToday = item.daysSinceWorn == 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.sm,
        DsSpacing.lg,
        DsSpacing.xxl,
      ),
      children: [
        _Hero(item: item),
        DsGaps.vLg,
        Text(item.title, style: text.pageTitle),
        DsGaps.vXxs,
        Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ClosetPill(
              label: item.slotLabel,
              icon: ClosetSlotStyle.icon(item.slot),
              tone: DsTone.critical,
            ),
            ClosetPill(
              label: item.sourceLabel,
              icon: item.source.isFromOhara
                  ? Icons.storefront_rounded
                  : Icons.photo_camera_rounded,
            ),
            if (item.brandName != null && item.brandName!.isNotEmpty)
              ClosetPill(label: item.brandName!, icon: Icons.sell_outlined),
          ],
        ),
        if (shelved) ...[
          DsGaps.vMd,
          _ShelvedBanner(item: item),
        ],
        DsGaps.vLg,
        _Rotation(item: item),
        if (!shelved) ...[
          DsGaps.vMd,
          wornToday
              ? DsButton(
                  label: l10n.closetWornTodayDone,
                  icon: Icons.check_circle_rounded,
                  variant: DsButtonVariant.tonal,
                  onPressed: () => logClosetWear(context, ref, item),
                )
              : CustomerPrimaryButton(
                  label: l10n.closetWoreToday,
                  icon: Icons.check_rounded,
                  onPressed: () => logClosetWear(context, ref, item),
                ),
        ],
        DsGaps.vXl,
        _Details(item: item),
        if (item.note != null && item.note!.trim().isNotEmpty) ...[
          DsGaps.vMd,
          CustomerPanel(
            padding: const EdgeInsets.all(DsSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  size: DsSizes.iconSm,
                  color: palette.gold,
                ),
                DsGaps.hXs,
                Expanded(child: Text(item.note!, style: text.body)),
              ],
            ),
          ),
        ],
        if (item.productId != null) ...[
          DsGaps.vMd,
          DsButton(
            label: l10n.closetViewInShop,
            icon: Icons.storefront_outlined,
            variant: DsButtonVariant.secondary,
            onPressed: () =>
                context.push(RoutePaths.productDetailsOf(item.productId!)),
          ),
        ],
        DsGaps.vXl,
        _Manage(item: item),
      ],
    );
  }
}

/// The photograph, framed, with a tap to see it full-screen.
class _Hero extends StatelessWidget {
  const _Hero({required this.item});

  final ClosetItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final url = item.imageUrl;
    final hasPhoto = url != null && url.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderCard,
        boxShadow: palette.shadow,
      ),
      child: ClipRRect(
        borderRadius: DsRadius.borderCard,
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: hasPhoto
                    ? () => MediaLightbox.open(context, url: url, title: item.title)
                    : null,
                child: ClosetPhoto(
                  url: url,
                  slot: item.slot,
                  blurHash: item.blurHash,
                  iconSize: DsSizes.iconHero,
                ),
              ),
              if (hasPhoto)
                PositionedDirectional(
                  bottom: DsSpacing.sm,
                  end: DsSpacing.sm,
                  child: IgnorePointer(
                    child: ClosetPill(
                      label: context.l10n.closetTapToEnlarge,
                      icon: Icons.zoom_out_map_rounded,
                      onMedia: true,
                    ),
                  ),
                ),
              if (item.isFavourite)
                PositionedDirectional(
                  top: DsSpacing.sm,
                  start: DsSpacing.sm,
                  child: ClosetPill(
                    label: context.l10n.closetFavouriteTag,
                    icon: Icons.favorite_rounded,
                    onMedia: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelvedBanner extends ConsumerWidget {
  const _ShelvedBanner({required this.item});

  final ClosetItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final text = context.dsText;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.infoContainer,
        borderRadius: DsRadius.borderLg,
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, color: colors.info),
          DsGaps.hSm,
          Expanded(
            child: Text(context.l10n.closetShelvedBanner, style: text.body),
          ),
          DsGaps.hXs,
          TextButton(
            onPressed: () => ref
                .read(closetActionsProvider)
                .setStatus(item.id, ClosetItemStatus.active),
            child: Text(context.l10n.closetReturnToCloset),
          ),
        ],
      ),
    );
  }
}

/// Rotation: how often, what it costs per wear, and when last — and one
/// sentence about what those numbers mean for this piece.
class _Rotation extends StatelessWidget {
  const _Rotation({required this.item});

  final ClosetItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.dsText;
    final palette = context.boutique;
    final insight = _insight(context);

    return CustomerPanel(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.closetRotationTitle,
            style: text.overline.tint(palette.primary),
          ),
          DsGaps.vSm,
          IntrinsicHeight(
            child: Row(
              children: [
                _Stat(value: '${item.wearCount}', label: l10n.closetTimesWorn),
                VerticalDivider(color: palette.line, width: DsSpacing.md),
                _Stat(
                  value: item.costPerWear?.format() ?? '—',
                  label: l10n.closetCostPerWear,
                ),
                VerticalDivider(color: palette.line, width: DsSpacing.md),
                _Stat(value: _lastWorn(context), label: l10n.closetLastWorn),
              ],
            ),
          ),
          if (insight != null) ...[
            DsGaps.vSm,
            Divider(color: palette.line, height: 1),
            DsGaps.vSm,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  insight.icon,
                  size: DsSizes.iconXs,
                  color: context.toneColor(insight.tone),
                ),
                DsGaps.hXs,
                Expanded(
                  child: Text(
                    insight.message,
                    style: text.caption.tint(palette.ink),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _lastWorn(BuildContext context) {
    final l10n = context.l10n;
    if (!item.hasBeenWorn) return l10n.closetWornNever;
    final days = item.daysSinceWorn ?? 0;
    if (days == 0) return l10n.closetWornToday;
    if (days == 1) return l10n.closetWornYesterday;
    if (days < 30) return l10n.closetWornDaysAgo(days);
    return l10n.closetWornMonthsAgo((days / 30).floor());
  }

  /// What the numbers say, in one line. Never a verdict on the purchase —
  /// only on what to do with the piece now.
  ({IconData icon, DsTone tone, String message})? _insight(BuildContext context) {
    final l10n = context.l10n;
    if (!item.hasBeenWorn) {
      return (
        icon: Icons.lightbulb_outline_rounded,
        tone: DsTone.accent,
        message: l10n.closetInsightNeverWorn,
      );
    }
    if ((item.daysSinceWorn ?? 0) >= 90) {
      return (
        icon: Icons.history_rounded,
        tone: DsTone.caution,
        message: l10n.closetInsightForgotten,
      );
    }
    if (item.wearCount >= 10) {
      return (
        icon: Icons.workspace_premium_rounded,
        tone: DsTone.positive,
        message: l10n.closetInsightStaple(item.wearCount),
      );
    }
    if (item.costPerWear != null) {
      return (
        icon: Icons.trending_down_rounded,
        tone: DsTone.info,
        message: l10n.closetInsightCostFalls,
      );
    }
    return null;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = context.dsText;

    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, maxLines: 1, style: text.metricSmall),
          ),
          DsGaps.vXxxs,
          Text(label, textAlign: TextAlign.center, style: text.metricLabel),
        ],
      ),
    );
  }
}

/// The descriptor, as labelled rows. A row with nothing in it is not drawn:
/// "الخامة: —" tells her nothing she can act on.
class _Details extends StatelessWidget {
  const _Details({required this.item});

  final ClosetItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.dsText;

    final rows = <(IconData, String, List<String>)>[
      if (item.colours.isNotEmpty)
        (
          Icons.palette_outlined,
          l10n.closetDetailColours,
          item.colours.map((term) => term.label).toList(),
        ),
      if (item.materials.isNotEmpty)
        (Icons.texture_rounded, l10n.closetDetailMaterial, item.materials),
      if (item.seasons.isNotEmpty)
        (
          Icons.wb_sunny_outlined,
          l10n.closetDetailSeasons,
          item.seasons.map((term) => term.label).toList(),
        ),
      if (item.occasions.isNotEmpty)
        (
          Icons.celebration_outlined,
          l10n.closetSuitsLabel,
          item.occasions.map((term) => term.label).toList(),
        ),
      if (item.size != null)
        (Icons.straighten_rounded, l10n.closetDetailSize, [item.size!]),
      if (item.modestyLabel.isNotEmpty)
        (Icons.shield_moon_outlined, l10n.closetDetailModesty, [item.modestyLabel]),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.closetDetails, style: text.sectionTitle),
        DsGaps.vSm,
        CustomerPanel(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.md,
            vertical: DsSpacing.xs,
          ),
          child: Column(
            children: [
              for (final (index, row) in rows.indexed) ...[
                if (index > 0) Divider(color: context.boutique.line, height: 1),
                _DetailRow(icon: row.$1, label: row.$2, values: row.$3),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.values,
  });

  final IconData icon;
  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final text = context.dsText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: DsSizes.iconSm, color: palette.primary),
          DsGaps.hSm,
          SizedBox(
            width: DsSizes.thumbLg,
            child: Text(label, style: text.label.tint(palette.muted)),
          ),
          Expanded(
            child: Wrap(
              spacing: DsSpacing.xxs,
              runSpacing: DsSpacing.xxs,
              children: [
                for (final value in values) ClosetPill(label: value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shelving, releasing and deleting, each asked separately and each
/// confirmed where it cannot be undone from this screen.
///
/// Archiving says "not this season"; releasing says "I no longer own it" and
/// keeps the history, which is what replacement gaps and cost-per-wear are
/// built on; deleting erases the piece and its history altogether.
class _Manage extends ConsumerWidget {
  const _Manage({required this.item});

  final ClosetItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.dsText;
    final colors = context.dsColors;
    final shelved = item.status == ClosetItemStatus.archived;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.closetManageTitle, style: text.sectionTitle),
        DsGaps.vSm,
        CustomerPanel(
          padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  shelved ? Icons.unarchive_outlined : Icons.inventory_2_outlined,
                  color: context.boutique.primary,
                ),
                title: Text(
                  shelved ? l10n.closetReturnToCloset : l10n.closetShelveForSeason,
                  style: text.bodyStrong,
                ),
                subtitle: Text(
                  shelved ? l10n.closetReturnHint : l10n.closetShelveHint,
                  style: text.caption,
                ),
                onTap: () => _shelve(context, ref, shelved),
              ),
              Divider(color: context.boutique.line, height: 1),
              ListTile(
                leading: Icon(
                  Icons.volunteer_activism_outlined,
                  color: context.boutique.primary,
                ),
                title: Text(l10n.closetNoLongerOwn, style: text.bodyStrong),
                subtitle: Text(l10n.closetReleaseHint, style: text.caption),
                onTap: () => _release(context, ref),
              ),
              Divider(color: context.boutique.line, height: 1),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: colors.error),
                title: Text(
                  l10n.closetDeleteForever,
                  style: text.bodyStrong.tint(colors.errorInk),
                ),
                subtitle: Text(l10n.closetDeleteHint, style: text.caption),
                onTap: () => _delete(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _shelve(BuildContext context, WidgetRef ref, bool shelved) async {
    final result = await ref
        .read(closetActionsProvider)
        .setStatus(
          item.id,
          shelved ? ClosetItemStatus.active : ClosetItemStatus.archived,
        );
    if (!context.mounted) return;
    DsSnackbar.show(
      context,
      message: result is Success
          ? (shelved ? context.l10n.closetReturned : context.l10n.closetShelved)
          : context.l10n.closetUpdateFailed,
      type: result is Success ? DsSnackbarType.success : DsSnackbarType.error,
    );
  }

  Future<void> _release(BuildContext context, WidgetRef ref) async {
    final confirmed = await DsDialog.confirm(
      context,
      title: context.l10n.closetReleaseConfirmTitle,
      message: context.l10n.closetReleaseConfirmBody,
      confirmLabel: context.l10n.closetNoLongerOwn,
      icon: Icons.volunteer_activism_outlined,
    );
    if (!confirmed || !context.mounted) return;

    final result = await ref
        .read(closetActionsProvider)
        .setStatus(item.id, ClosetItemStatus.released);
    if (!context.mounted) return;
    if (result is Success) {
      DsSnackbar.show(
        context,
        message: context.l10n.closetReleased,
        type: DsSnackbarType.success,
      );
      _leave(context);
    } else {
      DsSnackbar.show(
        context,
        message: context.l10n.closetUpdateFailed,
        type: DsSnackbarType.error,
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await DsDialog.confirm(
      context,
      title: context.l10n.closetDeleteConfirmTitle,
      message: context.l10n.closetDeleteConfirmBody,
      confirmLabel: context.l10n.closetDeleteForever,
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final result = await ref.read(closetActionsProvider).removeItem(item.id);
    if (!context.mounted) return;
    if (result is Success) {
      DsSnackbar.show(context, message: context.l10n.closetDeleted);
      _leave(context);
    } else {
      DsSnackbar.show(
        context,
        message: context.l10n.closetUpdateFailed,
        type: DsSnackbarType.error,
      );
    }
  }

  /// Opened from a link there is nothing to pop back to; the closet is where
  /// she was going anyway.
  void _leave(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(RoutePaths.closet);
}
