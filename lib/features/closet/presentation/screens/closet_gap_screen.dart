import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/closet/domain/entities/closet_gap.dart';
import 'package:reem/features/closet/presentation/providers/closet_providers.dart';
import 'package:reem/features/closet/presentation/widgets/closet_gap_card.dart';

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
    final suggestionsAsync = ref.watch(gapSuggestionsProvider(gapId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: ReemAppBar(title: context.l10n.closetGapTitle),
      body: suggestionsAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.closetSuggestionsFailed,
          onRetry: () => ref.invalidate(gapSuggestionsProvider(gapId)),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(DsSpacing.md),
          children: [
            ClosetGapCard(
              gap: data.gap,
              onTap: () => _explain(context, data.gap),
            ),
            const SizedBox(height: DsSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: DsButton(
                    label: context.l10n.closetWhySuggestion,
                    variant: DsButtonVariant.secondary,
                    size: DsButtonSize.sm,
                    onPressed: () => _explain(context, data.gap),
                  ),
                ),
                const SizedBox(width: DsSpacing.xs),
                Expanded(
                  child: DsButton(
                    label: context.l10n.closetNotInterested,
                    variant: DsButtonVariant.secondary,
                    size: DsButtonSize.sm,
                    onPressed: () => _dismiss(context, ref),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.lg),
            if (data.suggestions.isEmpty)
              DsEmptyState(
                icon: Icons.search_off_rounded,
                title: context.l10n.closetNoMatchNow,
                message: context.l10n.closetNoMatchNowBody,
              )
            else ...[
              Text(
                context.l10n.closetPiecesThatFit,
                style: context.dsText.sectionTitle,
              ),
              const SizedBox(height: DsSpacing.sm),
              for (final suggestion in data.suggestions) ...[
                _SuggestionCard(suggestion: suggestion),
                const SizedBox(height: DsSpacing.sm),
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
      builder: (context) => GapReasoningSheet(gap: gap),
    );
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    await ref.read(closetActionsProvider).dismissGap(gapId);
    if (!context.mounted) return;
    // Dismissal is durable — the fingerprint keeps it suppressed across every
    // future recompute — so saying so is honest rather than reassuring.
    DsSnackbar.show(context, message: context.l10n.closetGapDismissed);
    context.pop();
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion});

  final ClosetSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final product = suggestion.product;

    return SurfaceCard(
      onTap: () => context.push(RoutePaths.productDetailsOf(product.id)),
      padding: const EdgeInsets.all(DsSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DsRadius.sm),
            child: SizedBox(
              width: 84,
              height: 100,
              child: product.coverUrl == null
                  ? Container(color: colors.surfaceVariant)
                  : AuthorizedMediaImage(
                      url: product.coverUrl!,
                      fallback: Container(color: colors.surfaceVariant),
                    ),
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.cardTitle,
                ),
                DsGaps.vXxxs,
                if (product.priceFrom != null)
                  Text(
                    product.priceFrom!.format(),
                    style: context.dsText.price,
                  ),
                const SizedBox(height: DsSpacing.xs),
                // Why *her wardrobe* likes it. The catalog's own reasons are
                // one tap away on the product page.
                Wrap(
                  spacing: DsSpacing.xs,
                  runSpacing: 4,
                  children: [
                    if (suggestion.completesALook)
                      DsChip(
                        label: context.l10n.closetCompletesLook,
                        icon: Icons.auto_awesome_rounded,
                      ),
                    for (final reason in suggestion.pairingReasons.take(2))
                      DsChip(label: reason.label),
                  ],
                ),
                if (suggestion.pairsWithItemIds.isNotEmpty) ...[
                  DsGaps.vXxs,
                  Text(
                    context.l10n.closetPairsWithCount(
                      suggestion.pairsWithItemIds.length,
                    ),
                    style: context.dsText.caption.tint(colors.primary),
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
