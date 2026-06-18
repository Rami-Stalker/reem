import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design_system/design_system.dart';
import '../../../../../core/router/route_paths.dart';
import '../../domain/entities/seller_store_info.dart';
import '../providers/seller_dashboard_provider.dart';

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
              const SizedBox(height: 60),
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
    final c = context.dsColors;
    final theme = Theme.of(context);
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
                imageUrl: store.coverUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => ColoredBox(color: c.surfaceVariant),
                errorWidget: (_, _, _) => Container(
                  decoration: BoxDecoration(gradient: context.meshGradient),
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
                      c.background.withValues(alpha: 0.8),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
              // Top actions.
              Positioned(
                top: topPad + DsSpacing.sm,
                right: DsSpacing.md,
                child: _CoverActions(),
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
                gradient: context.storyRingGradient,
                boxShadow: context.luxuryShadow,
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: store.logoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(color: c.surfaceVariant),
                  errorWidget: (_, _, _) => Container(
                    color: c.primaryContainer,
                    child: Icon(Icons.storefront_rounded,
                        color: c.primary, size: 40),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Content below logo.
        Padding(
          padding: EdgeInsets.only(
              top: SellerStoreHeader._coverHeight + topPad + 50),
          child: Column(
            children: [
              // Store name + verified badge.
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      store.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFamily: DsTypography.fontFamilyDisplay,
                        fontFamilyFallback: DsTypography.displayFallback,
                        fontWeight: DsTypography.bold,
                      ),
                    ),
                    if (store.isVerified)
                      Padding(
                        padding: const EdgeInsets.only(left: DsSpacing.xs),
                        child: Icon(Icons.verified_rounded,
                            size: 20, color: c.info),
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
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: c.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: DsSpacing.md),
              // Subscription badge.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.md, vertical: DsSpacing.xxs + 1),
                decoration: BoxDecoration(
                  gradient: context.primaryGradient,
                  borderRadius: DsRadius.borderFull,
                ),
                child: Text(
                  '${store.subscriptionPlan} plan',
                  style: const TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontSize: DsTypography.labelSmall,
                    fontWeight: DsTypography.bold,
                    color: Colors.white,
                  ),
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
                  label: const Text('Edit store'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: DsRadius.borderLg),
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
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: () => context.push(RoutePaths.notifications),
        ),
        const SizedBox(width: DsSpacing.xs),
        _GlassIconButton(
          icon: Icons.settings_outlined,
          onTap: () => context.push(RoutePaths.settings),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: DsRadius.borderMd,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: DsRadius.borderMd,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
