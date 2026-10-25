import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/domain/entities/closet_gap.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_gap_card.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_visuals.dart';

/// One gap, and what would fill it.
///
/// The only screen in the closet that reaches the catalog. Each card carries
/// the wardrobe's reason for it — "بتنسّق مع ٤ قطع عندك" — rather than the
/// catalog's, because the catalog's reasons are available on every other screen
/// in the application and this one's are not available anywhere else.
class ClosetGapScreen extends ConsumerWidget {
  const ClosetGapScreen({super.key, required this.gapId});

  final String gapId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    final suggestionsAsync = ref.watch(gapSuggestionsProvider(gapId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: OharaAppBar(title: l10n.closetGapTitle),
      body: suggestionsAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: l10n.closetSuggestionsFailed,
          onRetry: () => ref.invalidate(gapSuggestionsProvider(gapId)),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.md,
            DsSpacing.lg,
            DsSpacing.xxl,
          ),
          children: [
            ClosetGapCard(
              gap: data.gap,
              onTap: () => _explain(context, data.gap),
            ),
            DsGaps.vSm,
            Row(
              children: [
                Expanded(
                  child: DsButton(
                    label: l10n.closetWhySuggestion,
                    icon: Icons.receipt_long_rounded,
                    variant: DsButtonVariant.tonal,
                    size: DsButtonSize.sm,
                    onPressed: () => _explain(context, data.gap),
                  ),
                ),
                DsGaps.hXs,
                Expanded(
                  child: DsButton(
                    label: l10n.closetNotInterested,
                    icon: Icons.do_not_disturb_on_outlined,
                    variant: DsButtonVariant.ghost,
                    size: DsButtonSize.sm,
                    onPressed: () => _dismiss(context, ref),
                  ),
                ),
              ],
            ),
            DsGaps.vXl,
            if (data.suggestions.isEmpty)
              DsEmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.closetNoMatchNow,
                message: l10n.closetNoMatchNowBody,
              )
            else ...[
              ClosetSectionHeading(
                eyebrow: l10n.closetSuggestionsEyebrow(data.suggestions.length),
                title: l10n.closetPiecesThatFit,
                padding: EdgeInsets.zero,
              ),
              DsGaps.vSm,
              for (final (index, suggestion) in data.suggestions.indexed) ...[
                DsStaggerAnimations.item(
                  index: index,
                  child: _SuggestionCard(suggestion: suggestion),
                ),
                DsGaps.vSm,
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _explain(BuildContext context, ClosetGap gap) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => GapReasoningSheet(gap: gap),
    );
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    final confirmed = await DsDialog.confirm(
      context,
      title: context.l10n.closetDismissConfirmTitle,
      message: context.l10n.closetDismissConfirmBody,
      confirmLabel: context.l10n.closetNotInterested,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(closetActionsProvider).dismissGap(gapId);
    if (!context.mounted) return;
    // Dismissal is durable — the fingerprint keeps it suppressed across every
    // future recompute — so saying so is honest rather than reassuring.
    DsSnackbar.show(context, message: context.l10n.closetGapDismissed);
    context.canPop() ? context.pop() : context.go(RoutePaths.closet);
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion});

  final ClosetSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final text = context.dsText;
    final product = suggestion.product;
    final fit = suggestion.pairingScore.clamp(0, 1).toDouble();

    return SurfaceCard(
      onTap: () => context.push(RoutePaths.productDetailsOf(product.id)),
      padding: const EdgeInsets.all(DsSpacing.sm),
      semanticLabel: product.title,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: DsSizes.thumbLg,
            height: DsSizes.thumbLg * 1.25,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: DsRadius.borderMd,
                  child: product.coverUrl == null
                      ? ColoredBox(color: colors.surfaceVariant)
                      : AuthorizedMediaImage(
                          url: product.coverUrl!,
                          width: DsSizes.thumbLg,
                          fallback: ColoredBox(color: colors.surfaceVariant),
                        ),
                ),
                // A suggestion is a product like any other.
                if (DsProductActions.of(context, product, DsProductSurface.rail)
                    case final action?)
                  PositionedDirectional(
                    top: DsSpacing.xxs,
                    end: DsSpacing.xxs,
                    child: action,
                  ),
              ],
            ),
          ),
          DsGaps.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (suggestion.completesALook) ...[
                  ClosetPill(
                    label: context.l10n.closetCompletesLook,
                    icon: Icons.auto_awesome_rounded,
                    tone: DsTone.accent,
                  ),
                  DsGaps.vXxs,
                ],
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.cardTitle,
                ),
                if (product.priceFrom != null) ...[
                  DsGaps.vXxxs,
                  Text(product.priceFrom!.format(), style: text.price),
                ],
                DsGaps.vXs,
                // How well it sits with what she owns — the wardrobe's score,
                // not the catalog's.
                Row(
                  children: [
                    Icon(
                      Icons.checkroom_rounded,
                      size: DsSizes.iconXxs,
                      color: colors.primary,
                    ),
                    DsGaps.hXxs,
                    Text(context.l10n.closetFitWithWardrobe, style: text.micro),
                    DsGaps.hXs,
                    Expanded(
                      child: DsMeter(
                        value: fit,
                        weight: DsMeterWeight.thin,
                        semanticLabel: context.l10n.closetFitWithWardrobe,
                      ),
                    ),
                  ],
                ),
                if (suggestion.pairingReasons.isNotEmpty) ...[
                  DsGaps.vXs,
                  // Why *her wardrobe* likes it. The catalog's own reasons are
                  // one tap away on the product page.
                  Wrap(
                    spacing: DsSpacing.xxs,
                    runSpacing: DsSpacing.xxs,
                    children: [
                      for (final reason in suggestion.pairingReasons.take(2))
                        ClosetPill(
                          label: reason.label,
                          icon: Icons.check_rounded,
                          tone: DsTone.positive,
                        ),
                    ],
                  ),
                ],
                if (suggestion.pairsWithItemIds.isNotEmpty) ...[
                  DsGaps.vXxs,
                  Text(
                    context.l10n.closetPairsWithCount(
                      suggestion.pairsWithItemIds.length,
                    ),
                    style: text.caption.tint(colors.primary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
