import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/home/domain/entities/featured_store.dart';
import 'package:reem/features/home/presentation/providers/home_content_provider.dart';
import 'package:reem/features/home/presentation/widgets/home_section_header.dart';

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
      homeContentNotifierProvider
          .select((s) => s.content?.featuredStores ?? const <FeaturedStore>[]),
    );

    if (!isLoading && stores.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          eyebrow: context.l10n.homeFeaturedEyebrow,
          title: context.l10n.homeFeaturedStores,
          onSeeAll: () => context.push(RoutePaths.categories),
        ),
        SizedBox(
          height: _railHeight,
          child: isLoading
              ? _skeleton(context)
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                  itemCount: stores.length,
                  separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
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
          child: DsSkeleton.box(height: _railHeight, borderRadius: DsRadius.xxl),
        ),
      ),
    );
  }
}

class _StoreCard extends StatefulWidget {
  const _StoreCard({required this.store});

  final FeaturedStore store;

  @override
  State<_StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<_StoreCard> {
  late bool _following = widget.store.isFollowing;

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
                    imageUrl: store.coverUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
                    errorWidget: (_, _, _) => ColoredBox(color: c.surfaceVariant),
                  ),
                  Positioned(
                    left: DsSpacing.md,
                    bottom: -22,
                    child: Container(
                      padding: const EdgeInsets.all(2),
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
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DsSpacing.md, 0, DsSpacing.md, DsSpacing.md),
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
                          style: TextStyle(
                            fontFamily: DsTypography.fontFamily,
                            fontWeight: DsTypography.bold,
                            fontSize: DsTypography.titleSmall,
                            color: c.onSurface,
                          ),
                        ),
                      ),
                      if (store.isVerified) ...[
                        const SizedBox(width: 3),
                        Icon(Icons.verified_rounded, size: 15, color: c.secondary),
                      ],
                      const Spacer(),
                      Icon(Icons.star_rounded, size: 15, color: c.rating),
                      const SizedBox(width: 2),
                      Text(store.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: DsTypography.labelMedium,
                            fontWeight: DsTypography.semiBold,
                            color: c.onSurface,
                          )),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    store.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: DsTypography.labelSmall,
                        color: c.onSurfaceVariant),
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  Row(
                    children: [
                      for (final img in store.previewImages.take(3))
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: DsSpacing.xs),
                          child: ClipRRect(
                            borderRadius: DsRadius.borderSm,
                            child: CachedNetworkImage(
                              imageUrl: img,
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
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
                        onTap: () => setState(() => _following = !_following),
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
            horizontal: DsSpacing.md, vertical: DsSpacing.xs),
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
            const SizedBox(width: 3),
            Text(
              following ? context.l10n.following : context.l10n.follow,
              style: TextStyle(
                fontSize: DsTypography.labelMedium,
                fontWeight: DsTypography.bold,
                color: following ? c.onSurface : c.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
