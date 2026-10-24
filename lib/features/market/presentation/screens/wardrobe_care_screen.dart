import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/market/domain/entities/market.dart';
import 'package:ohara/features/market/presentation/providers/market_providers.dart';
import 'package:ohara/features/market/presentation/widgets/market_pieces.dart';

/// خزانتك بعد الشرا — the part of a garment's life the shop usually ignores.
///
/// The screen is built to be *short*. Three numbers at the top, then at most
/// six pieces that need something, then nothing. A wardrobe with nothing to
/// report shows a sentence saying so, and that is a good day rather than an
/// empty state — which is why the empty copy congratulates rather than
/// apologises.
class WardrobeCareScreen extends ConsumerWidget {
  const WardrobeCareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final summary = ref.watch(wardrobeSummaryProvider);
    final attention = ref.watch(wardrobeAttentionProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: OharaAppBar(
        title: context.l10n.marketCareTitle,
        actions: [
          IconButton(
            tooltip: context.l10n.marketResaleTitle,
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.push(RoutePaths.marketResale),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(wardrobeSummaryProvider)
            ..invalidate(wardrobeAttentionProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(DsSpacing.lg),
          children: [
            summary.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (data) =>
                  data == null ? const SizedBox.shrink() : _Summary(summary: data),
            ),
            DsGaps.vLg,
            attention.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: DsSpacing.xxl),
                child: Center(child: DsLoadingIndicator()),
              ),
              error: (_, _) => DsErrorState(
                message: context.l10n.marketCareFailed,
                onRetry: () => ref.invalidate(wardrobeAttentionProvider),
              ),
              data: (pieces) => pieces.isEmpty
                  ? DsEmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: context.l10n.marketCareAllGood,
                      message: context.l10n.marketCareAllGoodBody,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.marketCareNeedsAttention,
                          style: context.dsText.cardTitle.tint(
                            colors.onSurface,
                          ),
                        ),
                        DsGaps.vSm,
                        for (final piece in pieces) ...[
                          _PieceCard(piece: piece),
                          DsGaps.vSm,
                        ],
                      ],
                    ),
            ),
            DsGaps.vXxl,
          ],
        ),
      ),
    );
  }
}

/// Three numbers, not a dashboard.
///
/// Cost per wear is the one worth having and the one nobody else computes: it
/// is what turns "this was expensive" into "this was worth it", and it is the
/// number that makes logging a wear feel like it pays for itself.
class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final WardrobeSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return DsGlassCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Row(
        children: [
          _Stat(
            label: context.l10n.marketCarePieces,
            value: '${summary.items}',
          ),
          _Stat(
            label: context.l10n.marketCareInRotation,
            value: '${summary.inRotation}',
          ),
          _Stat(
            label: context.l10n.marketCareCostPerWear,
            value: sypNumber(summary.medianCostPerWearSyp),
            tint: colors.price,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.tint});

  final String label;
  final String value;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.tileValue.tint(tint ?? colors.onSurface),
          ),
          Text(
            label,
            style: context.dsText.micro.tint(colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// One piece that needs something.
///
/// The advice leads, the care note follows, and the price only appears where
/// selling is actually the advice — a suggested price beside "wear it again"
/// would turn a styling note into a nudge to sell.
class _PieceCard extends ConsumerWidget {
  const _PieceCard({required this.piece});

  final WardrobePiece piece;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final reading = piece.reading;
    final colour = dispositionColor(context, reading.disposition);

    return DsGlassCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarketThumb(imageUrl: piece.imageUrl, size: 56),
              DsGaps.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      piece.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.body.tint(colors.onSurface),
                    ),
                    DsGaps.vXxs,
                    Row(
                      children: [
                        Icon(
                          dispositionIcon(reading.disposition),
                          size: 13,
                          color: colour,
                        ),
                        DsGaps.hXxs,
                        Text(
                          rotationLabel(context.l10n, reading.rotation),
                          style: context.dsText.micro.tint(colour),
                        ),
                        if (reading.costPerWearSyp != null) ...[
                          DsGaps.hXs,
                          Text(
                            context.l10n.marketCostPerWear(
                              sypText(reading.costPerWearSyp),
                            ),
                            style: context.dsText.micro.tint(
                              colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (reading.reason.isNotEmpty) ...[
            DsGaps.vSm,
            ReasonLine(text: reading.reason, tint: colour),
          ],
          for (final note in reading.care) ...[
            DsGaps.vXs,
            ReasonLine(text: note.text, icon: Icons.spa_outlined),
          ],
          if (piece.styleWith.isNotEmpty) ...[
            DsGaps.vXs,
            ReasonLine(
              icon: Icons.checkroom_rounded,
              text: context.l10n.marketGoesWith(
                piece.styleWith.map((p) => p.title).join('، '),
              ),
            ),
          ],
          if (reading.disposition == Disposition.resell) ...[
            DsGaps.vSm,
            Row(
              children: [
                if (piece.suggestedPriceSyp != null)
                  Expanded(
                    child: Text(
                      context.l10n.marketSuggestedPrice(
                        sypText(piece.suggestedPriceSyp),
                      ),
                      style: context.dsText.caption.semibold.tint(colors.price),
                    ),
                  )
                else
                  const Spacer(),
                DsButton(
                  label: piece.listingId == null
                      ? context.l10n.marketListForSale
                      : context.l10n.marketEditListing,
                  size: DsButtonSize.sm,
                  isExpanded: false,
                  variant: DsButtonVariant.secondary,
                  onPressed: () => _openResaleSheet(context, ref, piece),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Drafting a listing.
///
/// A sheet rather than a screen, and it produces a **draft** — she can see what
/// her dress is worth without offering it to anybody, and publishing is a
/// second, deliberate tap on her own listings.
Future<void> _openResaleSheet(
  BuildContext context,
  WidgetRef ref,
  WardrobePiece piece,
) async {
  var condition = 'EXCELLENT';

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (innerContext, setSheetState) {
        final colors = innerContext.dsColors;
        return Padding(
          padding: EdgeInsets.only(
            left: DsSpacing.lg,
            right: DsSpacing.lg,
            top: DsSpacing.lg,
            bottom:
                MediaQuery.of(innerContext).viewInsets.bottom + DsSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.marketListTitle(piece.title),
                style: innerContext.dsText.cardTitle.tint(colors.onSurface),
              ),
              DsGaps.vXs,
              Text(
                context.l10n.marketListDraftNote,
                style: innerContext.dsText.caption.tint(
                  colors.onSurfaceVariant,
                ),
              ),
              DsGaps.vMd,
              Text(
                context.l10n.marketCondition,
                style: innerContext.dsText.caption.tint(colors.onSurface),
              ),
              DsGaps.vXs,
              Wrap(
                spacing: DsSpacing.xs,
                children: [
                  for (final option in resaleConditions)
                    DsChip(
                      label: resaleConditionLabel(innerContext.l10n, option),
                      selected: condition == option,
                      onTap: () => setSheetState(() => condition = option),
                    ),
                ],
              ),
              DsGaps.vLg,
              DsButton(
                label: context.l10n.marketSaveDraft,
                isExpanded: true,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              DsGaps.vSm,
            ],
          ),
        );
      },
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final result = await ref
      .read(marketRepositoryProvider)
      .draftListing(piece.closetItemId, condition: condition);

  if (!context.mounted) return;

  result.fold((failure) => DsSnackbar.error(context, failure.message), (_) {
    DsSnackbar.success(context, context.l10n.marketSavedDraft);
    ref
      ..invalidate(wardrobeAttentionProvider)
      ..invalidate(myListingsProvider);
  });
}
