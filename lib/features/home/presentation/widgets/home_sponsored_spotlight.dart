import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/media_decode.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/discovery/presentation/providers/sponsored_providers.dart';
import 'package:ohara/features/home/domain/entities/sponsored_spotlight.dart';
import 'package:ohara/features/home/presentation/providers/home_content_provider.dart';
import 'package:ohara/features/home/presentation/widgets/home_section_header.dart';
import 'package:ohara/features/store_ads/presentation/widgets/store_tier.dart';

/// «مختارات مميزة» — the boutiques' HOME_SPOTLIGHT slots, near the top of
/// the home page, each card labelled «إعلان» in so many words.
///
/// A swipeable stack of wide cards rather than a grid: three adverts side by
/// side read as a shelf of products, and a shopper who cannot tell an advert
/// from an answer stops trusting the answers. Renders nothing when no
/// boutique has bought the slot — or this shopper has already seen it enough
/// times today.
class HomeSponsoredSpotlight extends ConsumerStatefulWidget {
  const HomeSponsoredSpotlight({super.key});

  static const double _cardHeight = 176;

  @override
  ConsumerState<HomeSponsoredSpotlight> createState() =>
      _HomeSponsoredSpotlightState();
}

class _HomeSponsoredSpotlightState
    extends ConsumerState<HomeSponsoredSpotlight> {
  final _controller = PageController(viewportFraction: 0.9);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(SponsoredSpotlight slot) {
    ref
        .read(discoverySignalsProvider)
        .sponsoredTapped(offerId: slot.offerId, placement: 'home_spotlight');
    context.push(RoutePaths.productDetailsOf(slot.product.id));
  }

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(
      homeContentNotifierProvider.select(
        (s) => s.content?.sponsoredSpotlight ?? const <SponsoredSpotlight>[],
      ),
    );
    if (slots.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;

    return Semantics(
      container: true,
      label: l10n.homeSpotlightTitle,
      child: Padding(
        padding: const EdgeInsets.only(bottom: DsSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSectionHeader(
              eyebrow: l10n.searchSponsored,
              title: l10n.homeSpotlightTitle,
            ),
            SizedBox(
              height: HomeSponsoredSpotlight._cardHeight,
              child: PageView.builder(
                controller: _controller,
                padEnds: slots.length == 1,
                itemCount: slots.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: DsSpacing.lg,
                  ),
                  child: _SpotlightCard(
                    slot: slots[index],
                    onTap: () => _open(slots[index]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({required this.slot, required this.onTap});

  final SponsoredSpotlight slot;
  final VoidCallback onTap;

  static const double _imageWidth = 132;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    final text = context.dsText;
    final product = slot.product;
    final jewel = storeTierJewel(slot.storeTier);
    final cover = product.coverUrl;

    return SurfaceCard(
      padding: EdgeInsets.zero,
      elevation: DsCardElevation.medium,
      onTap: onTap,
      semanticLabel: l10n.homeSpotlightCardLabel(product.title, slot.storeName),
      child: ClipRRect(
        borderRadius: DsRadius.borderCard,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _imageWidth,
              child: cover == null
                  ? ColoredBox(color: c.surfaceVariant)
                  : CachedNetworkImage(
                      imageUrl: MediaVariants.thumb(cover),
                      fit: BoxFit.cover,
                      memCacheWidth: MediaDecode.widthFor(context, _imageWidth),
                      placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
                      errorWidget: (_, _, _) =>
                          ColoredBox(color: c.surfaceVariant),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: DsSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: DsSpacing.xxs,
                      runSpacing: DsSpacing.xxs,
                      children: [
                        DsBadge(
                          label: l10n.searchSponsored,
                          tone: DsBadgeTone.neutral,
                          icon: Icons.campaign_outlined,
                        ),
                        if (jewel != null)
                          DsTierBadge(
                            tier: jewel,
                            label: storeTierLabel(l10n, slot.storeTier),
                          ),
                      ],
                    ),
                    DsGaps.vXs,
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.cardTitle.tint(c.onSurface),
                    ),
                    DsGaps.vXxs,
                    Text(
                      slot.storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.caption.tint(c.onSurfaceVariant),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.price?.format() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.price.tint(c.price),
                          ),
                        ),
                        Text(
                          l10n.homeSpotlightShop,
                          style: text.labelStrong.tint(c.primary),
                        ),
                        Icon(
                          Icons.chevron_left_rounded,
                          size: DsSizes.iconSm,
                          color: c.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
