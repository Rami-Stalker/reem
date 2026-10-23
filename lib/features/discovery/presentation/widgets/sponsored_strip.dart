import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/discovery/domain/entities/sponsored_product.dart';
import 'package:reem/features/discovery/presentation/providers/sponsored_providers.dart';
import 'package:reem/features/discovery/presentation/widgets/product_card_compact.dart';

/// The paid slots for a listing, above it and labelled as what they are.
///
/// The server already keeps them out of the results; this keeps them visibly
/// apart on screen too. A shopper who cannot tell an advert from an answer
/// stops trusting the answers, which costs the marketplace more than the slot
/// earns. Renders nothing at all when there are no slots.
class SponsoredStrip extends ConsumerWidget {
  const SponsoredStrip({super.key, required this.slotsKey});

  /// [searchSponsoredKey] or [categorySponsoredKey].
  final String slotsKey;

  static const double _cardWidth = 152;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(sponsoredSlotsProvider(slotsKey));
    if (slots.isEmpty) return const SizedBox.shrink();

    final colors = context.dsColors;
    return Semantics(
      container: true,
      label: context.l10n.searchSponsored,
      child: Padding(
        padding: const EdgeInsets.only(bottom: DsSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
              child: DsBadge(
                label: context.l10n.searchSponsored,
                tone: DsBadgeTone.neutral,
                icon: Icons.campaign_outlined,
              ),
            ),
            const SizedBox(height: DsSpacing.xs),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                itemCount: slots.length,
                separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.sm),
                itemBuilder: (context, index) => SizedBox(
                  width: _cardWidth,
                  child: ProductCardCompact(
                    product: slots[index].product,
                    onTap: () => _open(context, ref, slots[index]),
                  ),
                ),
              ),
            ),
            Divider(height: DsSpacing.lg, color: colors.divider),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref, SponsoredProduct slot) {
    ref
        .read(discoverySignalsProvider)
        .sponsoredTapped(offerId: slot.offerId, placement: slot.placement);
    context.push(RoutePaths.productDetailsOf(slot.product.id));
  }
}
