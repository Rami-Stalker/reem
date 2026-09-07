import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_decode.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/home/domain/entities/featured_store.dart';
import 'package:reem/features/home/presentation/providers/home_content_provider.dart';
import 'package:reem/features/home/presentation/widgets/home_section_header.dart';
import 'package:reem/features/user_profile/presentation/providers/user_profile_providers.dart';

/// "Featured boutiques" — rich store cards with cover, logo, trust signals and
/// a teaser strip of their pieces, plus an optimistic follow toggle.
class HomeFeaturedStores extends ConsumerWidget {
  const HomeFeaturedStores({super.key});

  static const double _cardWidth = 272;
  static const double _railHeight = 248;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      homeContentNotifierProvider.select((s) => s.isInitialLoading),
    );
    final stores = ref.watch(
      homeContentNotifierProvider.select(
        (s) => s.content?.featuredStores ?? const <FeaturedStore>[],
      ),
    );

    if (!isLoading && stores.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No "see all". It used to open the departments grid — a list of
        // categories under a heading that says boutiques, which is simply the
        // wrong screen. There is no buyer-facing list of stores to send her to
        // yet, and the header hides the control when it has nowhere to go;
        // offering a link that lands somewhere unrelated is worse than not
        // offering one. Give it a destination when that screen exists.
        HomeSectionHeader(
          eyebrow: context.l10n.homeFeaturedEyebrow,
          title: context.l10n.homeFeaturedStores,
        ),
        SizedBox(
          height: _railHeight,
          child: isLoading
              ? _skeleton(context)
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                  itemCount: stores.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: DsSpacing.md),
                  itemBuilder: (context, i) => SizedBox(
                    width: _cardWidth,
                    child: _StoreCard(store: stores[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    return DsShimmer(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
        itemBuilder: (_, _) => const SizedBox(
          width: _cardWidth,
          child: DsSkeleton.box(
            height: _railHeight,
            borderRadius: DsRadius.xxl,
          ),
        ),
      ),
    );
  }
}

class _StoreCard extends ConsumerStatefulWidget {
  const _StoreCard({required this.store});

  final FeaturedStore store;

  @override
  ConsumerState<_StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends ConsumerState<_StoreCard> {
  late bool _following = widget.store.isFollowing;
  bool _busy = false;

  /// Follow, for real.
  ///
  /// The button used to be a `setState` and nothing else: the pill filled in,
  /// the boutique was never told, and the next refresh quietly un-followed her
  /// again. It now calls the same endpoint the profile screen does, and rolls
  /// the pill back if the call fails.
  Future<void> _toggleFollow() async {
    if (_busy) return;
    final wasFollowing = _following;
    setState(() {
      _busy = true;
      _following = !wasFollowing;
    });

    final result = wasFollowing
        ? await ref.read(unfollowSellerUseCaseProvider).call(widget.store.id)
        : await ref.read(followSellerUseCaseProvider).call(widget.store.id);

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result case Error()) _following = wasFollowing;
    });
    if (result case Error() when mounted) {
      DsSnackbar.error(context, context.l10n.actionDidNotSave);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final store = widget.store;

    return SurfaceCard(
      padding: EdgeInsets.zero,
      elevation: DsCardElevation.medium,
      onTap: () => context.push(RoutePaths.userProfileOf(store.id)),
      child: ClipRRect(
        borderRadius: DsRadius.borderCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover + logo.
            SizedBox(
              height: 84,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CachedNetworkImage(
                    imageUrl: MediaVariants.at(
                      store.coverUrl,
                      MediaVariants.medium,
                    ),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
                    errorWidget: (_, _, _) =>
                        ColoredBox(color: c.surfaceVariant),
                  ),
                  Positioned(
                    left: DsSpacing.md,
                    bottom: -22,
                    child: Container(
                      padding: const EdgeInsets.all(DsSpacing.xxxs),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.surface,
                      ),
                      child: DsAvatar(
                        imageUrl: store.logoUrl,
                        name: store.name,
                        size: 48,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DsGaps.vXl,
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.md,
                DsSpacing.xxxs,
                DsSpacing.md,
                DsSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          store.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.tileTitle.bold.tint(
                            c.onSurface,
                          ),
                        ),
                      ),
                      if (store.isVerified) ...[
                        DsGaps.hXxs,
                        Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: c.secondary,
                        ),
                      ],
                      const Spacer(),
                      // Only where customers have actually rated her. A shop
                      // nobody has reviewed used to be labelled "0.0".
                      if (store.rating != null) ...[
                        Icon(Icons.star_rounded, size: 15, color: c.rating),
                        DsGaps.hXxxs,
                        Text(
                          store.rating!.toStringAsFixed(1),
                          style: context.dsText.labelMedium.semibold.tint(
                            c.onSurface,
                          ),
                        ),
                      ],
                    ],
                  ),
                  DsGaps.vXxxs,
                  Text(
                    store.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.caption.tint(c.onSurfaceVariant),
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  Row(
                    children: [
                      for (final img in store.previewImages.take(3))
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: DsSpacing.xs,
                          ),
                          child: ClipRRect(
                            borderRadius: DsRadius.borderSm,
                            child: CachedNetworkImage(
                              imageUrl: MediaVariants.thumb(img),
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              memCacheWidth: MediaDecode.widthFor(context, 38),
                              placeholder: (_, _) =>
                                  ColoredBox(color: c.shimmerBase),
                              errorWidget: (_, _, _) =>
                                  ColoredBox(color: c.surfaceVariant),
                            ),
                          ),
                        ),
                      const Spacer(),
                      _FollowButton(
                        following: _following,
                        onTap: _toggleFollow,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.following, required this.onTap});

  final bool following;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DsMotion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.md,
          vertical: DsSpacing.xs,
        ),
        decoration: BoxDecoration(
          gradient: following ? null : context.primaryGradient,
          color: following ? c.surfaceVariant : null,
          borderRadius: DsRadius.borderFull,
          border: following ? Border.all(color: c.border) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              following ? Icons.check_rounded : Icons.add_rounded,
              size: 15,
              color: following ? c.onSurface : c.onPrimary,
            ),
            DsGaps.hXxs,
            Text(
              following ? context.l10n.following : context.l10n.follow,
              style: context.dsText.labelMedium.bold.tint(
                following ? c.onSurface : c.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
