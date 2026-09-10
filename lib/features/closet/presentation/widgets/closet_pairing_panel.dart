import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/closet/domain/entities/closet_gap.dart';
import 'package:reem/features/closet/presentation/providers/closet_providers.dart';

/// "هل بتناسب خزانتي؟" — on the product page.
///
/// The inverse of a gap: the garment is given and the wardrobe is the unknown.
/// This is what turns a listing into a fitting room — she is not asked whether
/// she likes the dress, she is told which pieces she owns it works with, which
/// look it finishes, and whether she already owns one.
///
/// Renders nothing at all when her closet is empty or unreachable. A woman who
/// has not built a wardrobe should not be shown an empty panel telling her so
/// on every product she opens; the feature earns its space on the page or it
/// takes none.
class ClosetPairingPanel extends ConsumerWidget {
  const ClosetPairingPanel({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairingAsync = ref.watch(closetPairingProvider(productId));

    return pairingAsync.maybeWhen(
      data: (pairing) => pairing == null
          ? const SizedBox.shrink()
          : _Panel(productId: productId, pairing: pairing),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({required this.productId, required this.pairing});

  final String productId;
  final ClosetPairing pairing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;

    // Nothing useful to say: she owns nothing this would go with and it
    // finishes no look. Saying "ما بتناسب خزانتك" would be both discouraging
    // and wrong — it usually means her closet is small, not that the garment
    // is a mismatch.
    if (!pairing.isOwned && !pairing.pairsWithAnything) {
      return const SizedBox.shrink();
    }

    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checkroom_rounded, size: 18, color: colors.primary),
              const SizedBox(width: DsSpacing.xs),
              Text('من خزانتك', style: context.dsText.labelStrong),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),

          if (pairing.isOwned)
            // The most valuable thing this panel can say, and the one no shop
            // has any incentive to say: you already have this.
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: colors.warning,
                ),
                const SizedBox(width: DsSpacing.xs),
                Expanded(
                  child: Text(
                    'عندك وحدة منها بخزانتك.',
                    style: context.dsText.body.tint(colors.warning),
                  ),
                ),
              ],
            )
          else ...[
            Text(
              'بتنسّق مع ${pairing.pairsWithItemIds.length} قطعة عندك.',
              style: context.dsText.body,
            ),
            if (pairing.completesLookIds.isNotEmpty) ...[
              DsGaps.vXxxs,
              Text(
                'وبتكمّل ${pairing.completesLookIds.length} إطلالة محفوظة.',
                style: context.dsText.body.tint(colors.primary),
              ),
            ],
          ],

          const SizedBox(height: DsSpacing.sm),
          Row(
            children: [
              if (!pairing.isOwned)
                Expanded(
                  child: DsButton(
                    label: 'أضيفيها لخزانتي',
                    size: DsButtonSize.sm,
                    variant: DsButtonVariant.secondary,
                    onPressed: () => _add(context, ref),
                  ),
                ),
              if (!pairing.isOwned) const SizedBox(width: DsSpacing.xs),
              Expanded(
                child: DsButton(
                  label: 'افتحي خزانتي',
                  size: DsButtonSize.sm,
                  variant: DsButtonVariant.secondary,
                  onPressed: () => context.push(RoutePaths.closet),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Adding from here is "I own this", not "I want this" — the wishlist is a
  /// different button on this same page. Offered because a woman who bought the
  /// same dress elsewhere, or is holding it, should be able to say so.
  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result =
        await ref.read(closetActionsProvider).addFromCatalog(productId: productId);
    if (!context.mounted) return;

    result.when(
      success: (_) => DsSnackbar.show(context, message: 'صارت بخزانتك.'),
      error: (_) => DsSnackbar.show(
        context,
        message: 'ما قدرنا نضيفها.',
        type: DsSnackbarType.error,
      ),
    );
  }
}
