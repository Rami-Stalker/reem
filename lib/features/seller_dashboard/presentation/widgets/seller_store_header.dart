import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_decode.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_store_info.dart';
import 'package:reem/features/seller_dashboard/presentation/providers/seller_dashboard_provider.dart';

/// Cover image + logo + store name + verification + description + edit CTA.
class SellerStoreHeader extends ConsumerWidget {
  const SellerStoreHeader({super.key});

  static const double _coverHeight = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);

    if (state.isInitialLoading) {
      return SliverToBoxAdapter(
        child: DsShimmer(
          child: Column(
            children: [
              DsSkeleton.box(height: _coverHeight, borderRadius: 0.0),
              // Clears the status bar and the floating chrome above.
              const SizedBox(height: DsSizes.appBarHeight),
              Center(child: DsSkeleton.line(width: 160)),
              const SizedBox(height: DsSpacing.xs),
              Center(child: DsSkeleton.line(width: 240)),
            ],
          ),
        ),
      );
    }

    final store = state.data?.storeInfo;
    if (store == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: _StoreHeaderBody(store: store).animate().fadeIn(duration: 400.ms),
    );
  }
}

class _StoreHeaderBody extends StatelessWidget {
  const _StoreHeaderBody({required this.store});

  final SellerStoreInfo store;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;
    final topPad = MediaQuery.paddingOf(context).top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover image.
        SizedBox(
          height: SellerStoreHeader._coverHeight + topPad,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: MediaVariants.at(
                  store.coverUrl,
                  MediaVariants.medium,
                ),
                memCacheWidth: MediaDecode.widthFor(
                  context,
                  MediaQuery.sizeOf(context).width,
                ),
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    ColoredBox(color: context.dsColors.shimmerBase),
                errorWidget: (_, _, _) => DecoratedBox(
                  decoration: BoxDecoration(gradient: palette.headerGradient),
                ),
              ),
              // Gradient scrim.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      palette.background.withValues(alpha: 0.86),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
              // Top actions.
              PositionedDirectional(
                top: topPad + DsSpacing.sm,
                end: DsSpacing.md,
                child: const _CoverActions(),
              ),
            ],
          ),
        ),

        // Logo avatar (overlapping cover).
        Positioned(
          top: SellerStoreHeader._coverHeight + topPad - 44,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: palette.goldGradient,
                boxShadow: palette.shadow,
              ),
              padding: const EdgeInsets.all(DsSpacing.xxs),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: MediaVariants.thumb(store.logoUrl),
                  memCacheWidth: MediaDecode.widthFor(context, 88),
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      ColoredBox(color: context.dsColors.shimmerBase),
                  errorWidget: (_, _, _) => ColoredBox(
                    color: palette.primarySoft,
                    child: Icon(
                      Icons.storefront_rounded,
                      color: palette.primary,
                      size: 38,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Content below logo.
        Padding(
          padding: EdgeInsets.only(
              top: SellerStoreHeader._coverHeight + topPad + DsSpacing.huge),
          child: Column(
            children: [
              // Store name + verified badge.
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        store.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.dsText.screenTitle.copyWith(
                          fontFamily: DsTypography.fontFamilyDisplay,
                          fontFamilyFallback: DsTypography.displayFallback,
                          fontWeight: DsTypography.bold,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    if (store.isVerified)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: DsSpacing.xs,
                        ),
                        child: Icon(
                          Icons.verified_rounded,
                          size: 20,
                          color: context.dsColors.secondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: DsSpacing.xxs),
              // Tagline.
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: DsSpacing.xxl),
                child: Text(
                  store.tagline,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.cardSubtitle
                      .copyWith(color: palette.muted),
                ),
              ),
              const SizedBox(height: DsSpacing.md),
              // Subscription badge.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.md, vertical: DsSpacing.xxs + DsSpacing.xxxs),
                decoration: BoxDecoration(
                  gradient: palette.goldGradient,
                  borderRadius: DsRadius.borderFull,
                ),
                child: Text(
                  l10n.sellerPlanBadge(store.subscriptionPlan),
                  // Deep gold ink on the champagne wash, fixed in both
                  // themes because the badge's ground is a brand gradient.
                  style: context.dsText.badge.tint(DsColors.onChampagne),
                ),
              ),
              const SizedBox(height: DsSpacing.lg),
              // Edit store button.
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.lg),
                child: OutlinedButton.icon(
                  onPressed: () => context.push(RoutePaths.editProfile),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(l10n.sellerEditStore),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    foregroundColor: palette.primary,
                    side: BorderSide(color: palette.primary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: DsRadius.borderLg,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DsSpacing.xl),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoverActions extends StatelessWidget {
  const _CoverActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassIconButton(
          tooltip: context.l10n.notifications,
          icon: Icons.notifications_none_rounded,
          onTap: () => context.push(RoutePaths.notifications),
        ),
        const SizedBox(width: DsSpacing.xs),
        _GlassIconButton(
          tooltip: context.l10n.settings,
          icon: Icons.settings_outlined,
          onTap: () => context.push(RoutePaths.settings),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Required: this is a bare `GestureDetector` around an icon, so without a
  /// label it is invisible to a screen reader rather than merely unclear.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      // `Tooltip` alone would not do here: this is a `GestureDetector`, not a
      // button widget, so nothing declares it tappable to a screen reader.
      // `Semantics(button: true)` is what makes it announce as one at all.
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: DsRadius.borderMd,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: DsColors.onMedia.withValues(alpha: 0.2),
                borderRadius: DsRadius.borderMd,
                border: Border.all(
                    color: DsColors.onMedia.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: DsColors.onMedia, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
