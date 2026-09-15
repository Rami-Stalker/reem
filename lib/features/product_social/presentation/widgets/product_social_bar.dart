import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/value_objects/money_format.dart';
import 'package:reem/features/product_social/presentation/product_gestures.dart';
import 'package:reem/features/product_social/presentation/providers/product_social_providers.dart';

/// The post gestures on the product page.
///
/// A piece seen as a grid tile or a mosaic tile has no room for a heart, a
/// thread and a share row — so, as the client put it, those shapes keep their
/// own look and the gestures wait on the product page. This is where they
/// wait: the same action bar a post has, the same counts, the same «…» menu,
/// and the thread one tap away.
class ProductSocialBar extends ConsumerStatefulWidget {
  const ProductSocialBar({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ProductSocialBar> createState() => _ProductSocialBarState();
}

class _ProductSocialBarState extends ConsumerState<ProductSocialBar> {
  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void didUpdateWidget(ProductSocialBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) _seed();
  }

  void _seed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(productEngagementProvider.notifier).seed([widget.product]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    final product = widget.product;
    final engagement = ProductGestures.watch(ref, product);
    final gestures = ProductGestures(context, ref, product);

    final facts = [
      if (engagement.likes > 0) l10n.postLikesCount(formatCount(engagement.likes)),
      if (engagement.picks > 0)
        l10n.productPicksCount(formatCount(engagement.picks)),
    ];

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.xs,
        DsSpacing.xs,
        DsSpacing.xs,
        DsSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DsPostActionBar(
                  liked: engagement.isLiked,
                  saved: engagement.isSaved,
                  picked: engagement.isPicked,
                  commentsCount: engagement.comments,
                  sharesCount: engagement.shares,
                  onLike: gestures.like,
                  onComment: gestures.comment,
                  onShare: gestures.share,
                  onSave: gestures.save,
                  onPick: gestures.pick,
                ),
              ),
              DsIconButton(
                icon: Icons.more_horiz_rounded,
                tooltip: l10n.postOptions,
                variant: DsIconButtonVariant.ghost,
                size: 40,
                onPressed: () => gestures.options(showOpenProduct: false),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (facts.isNotEmpty)
                  Text(
                    facts.join(' · '),
                    style: context.dsText.labelLarge.semibold.tint(c.onSurface),
                  ),
                DsGaps.vXxs,
                GestureDetector(
                  onTap: gestures.comment,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    engagement.comments > 0
                        ? l10n.postViewComments(formatCount(engagement.comments))
                        : l10n.beTheFirstToComment,
                    style: context.dsText.cardSubtitle.tint(c.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
