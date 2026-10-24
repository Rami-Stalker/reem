import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/domain/entities/closet_gap.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';

/// «يُنسَّق مع ٣ قطع من خزانتكِ» — the closet, under a post in the feed.
///
/// Every feed tells her what is new. This line tells her what the piece does
/// for the wardrobe she already has: how many of her own pieces it goes with,
/// which saved looks it finishes — or, the line no shop has a reason to show,
/// that she already owns one like it. The question stops being "do I like
/// it" and becomes "does it complete me", which is the one that prevents the
/// purchase she regrets.
///
/// It is the product page's closet panel brought up to the moment of wanting,
/// and it follows the panel's rule: it says something useful or it takes no
/// space. A failed lookup, an empty closet, or a piece that pairs with
/// nothing she owns all render nothing — a small closet is not a verdict on
/// the garment.
///
/// One lookup per tagged post, made as the post scrolls into view and served
/// from the response cache when it comes back. A feed that arrives with the
/// pairing already attached would make this free; until then it is lazy so
/// it only ever costs what she actually scrolls past.
class PostClosetStrip extends ConsumerWidget {
  const PostClosetStrip({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(closetPairingProvider(productId)).value;
    if (pairing == null || (!pairing.isOwned && !pairing.pairsWithAnything)) {
      return const SizedBox.shrink();
    }
    return _Strip(pairing: pairing);
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.pairing});

  final ClosetPairing pairing;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;

    // Owning one already is a caution, not a recommendation, so it changes
    // the strip's register rather than just its sentence. The caution is
    // carried by the ground and the icon; the words stay in body ink, because
    // warning amber on its own container is too faint to read.
    final owned = pairing.isOwned;
    final ground = owned ? c.warningContainer : c.secondaryContainer;
    final ink = owned ? c.onSurface : c.onSecondaryContainer;
    final mark = owned ? c.warning : c.onSecondaryContainer;

    final completes = pairing.completesLookIds.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.sm,
        0,
        DsSpacing.sm,
        DsSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DsSpacing.sm,
          DsSpacing.xs,
          DsSpacing.xs,
          DsSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: ground,
          borderRadius: DsRadius.borderLg,
        ),
        child: Row(
          children: [
            Icon(
              owned ? Icons.info_outline_rounded : Icons.checkroom_rounded,
              size: DsSizes.iconSm,
              color: mark,
            ),
            DsGaps.hXs,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    owned
                        ? l10n.postClosetOwned
                        : l10n.postClosetPairs(pairing.pairsWithItemIds.length),
                    style: context.dsText.labelStrong.tint(ink),
                  ),
                  if (!owned && completes > 0)
                    Text(
                      l10n.postClosetCompletes(completes),
                      style: context.dsText.caption.tint(ink),
                    ),
                ],
              ),
            ),
            DsGaps.hXs,
            DsButton(
              label: l10n.postClosetOpen,
              size: DsButtonSize.sm,
              // Tonal, not outlined: this is a line of information with a
              // way through it, and should not outshout the post above it.
              variant: DsButtonVariant.tonal,
              // Hugs its label: the sentence beside it is what gets the room.
              isExpanded: false,
              // The closet is a tab, so `go` switches to it and keeps the bar.
              onPressed: () => context.go(RoutePaths.closet),
            ),
          ],
        ),
      ),
    );
  }
}
