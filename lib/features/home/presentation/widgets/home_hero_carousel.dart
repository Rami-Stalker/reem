import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/media/media_decode.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/features/home/domain/entities/hero_banner.dart';
import 'package:reem/features/home/presentation/providers/home_content_provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

/// The dynamic hero — a swipeable, auto-advancing carousel of promotions,
/// campaigns, seasonal moments and personalized offers. Peeking neighbours,
/// gentle parallax on the artwork and a kind-aware gradient give it a premium,
/// alive feel.
class HomeHeroCarousel extends ConsumerStatefulWidget {
  const HomeHeroCarousel({super.key});

  static const double _height = 252;

  @override
  ConsumerState<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends ConsumerState<HomeHeroCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  Timer? _autoplay;
  int _index = 0;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!_controller.hasClients) return;
      setState(() => _page = _controller.page ?? 0);
    });
  }

  void _startAutoplay(int count) {
    _autoplay?.cancel();
    if (count <= 1) return;
    _autoplay = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients) return;
      final next = (_index + 1) % count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      homeContentNotifierProvider.select((s) => s.isInitialLoading),
    );
    final banners = ref.watch(
      homeContentNotifierProvider.select(
        (s) => s.content?.heroBanners ?? const <HeroBanner>[],
      ),
    );

    if (isLoading) return const _HeroSkeleton();
    if (banners.isEmpty) return const SizedBox.shrink();

    // (Re)arm autoplay once we know the count.
    if (_autoplay == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startAutoplay(banners.length),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: HomeHeroCarousel._height,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final delta = (_page - i).clamp(-1.0, 1.0);
              return _HeroSlide(banner: banners[i], parallax: delta);
            },
          ),
        ),
        const SizedBox(height: DsSpacing.md),
        SmoothPageIndicator(
          controller: _controller,
          count: banners.length,
          effect: ExpandingDotsEffect(
            dotHeight: 6,
            dotWidth: 6,
            expansionFactor: 3.4,
            spacing: 5,
            activeDotColor: context.dsColors.primary,
            dotColor: context.dsColors.primary.withValues(alpha: 0.22),
          ),
        ),
      ],
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({required this.banner, required this.parallax});

  final HeroBanner banner;

  /// -1..1 — distance of this slide from the centred page, for parallax.
  final double parallax;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final tint = _kindGradient(banner.kind);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs),
      child: GestureDetector(
        onTap: () {
          if (banner.targetRoute != null) context.push(banner.targetRoute!);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: DsRadius.borderCard,
            boxShadow: context.shadowSoft,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Parallax artwork — slides translate the image opposite to drag.
              OverflowBox(
                maxWidth: MediaQuery.sizeOf(context).width * 1.25,
                child: Transform.translate(
                  offset: Offset(parallax * -28, 0),
                  child: CachedNetworkImage(
                    imageUrl: MediaVariants.at(
                      banner.imageUrl,
                      MediaVariants.medium,
                    ),
                    // The variant bounds the download; this bounds the *decode*,
                    // which is the RAM. A full-resolution banner is four bytes
                    // a pixel however small it is drawn, and this carousel keeps
                    // several alive at once on the first screen she sees.
                    memCacheWidth: MediaDecode.widthFor(
                      context,
                      MediaQuery.sizeOf(context).width * 1.25,
                    ),
                    fit: BoxFit.cover,
                    placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
                    errorWidget: (_, _, _) =>
                        DecoratedBox(decoration: BoxDecoration(gradient: tint)),
                  ),
                ),
              ),
              // Brand tint + legibility scrim.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      DsColors.black.withValues(alpha: 0.62),
                      DsColors.black.withValues(alpha: 0.12),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DsSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (banner.eyebrow != null)
                      Text(
                        banner.eyebrow!.toUpperCase(),
                        style: DsTypography.overline(DsColors.onMedia).copyWith(
                          color: DsColors.onMedia.withValues(alpha: 0.85),
                        ),
                      ),
                    const SizedBox(height: DsSpacing.xxs),
                    Text(
                      banner.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.screenTitle.copyWith(
                        color: DsColors.onMedia,
                        fontWeight: DsTypography.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: DsSpacing.xxs),
                    SizedBox(
                      width: 220,
                      child: Text(
                        banner.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.cardSubtitle.copyWith(
                          color: DsColors.onMedia.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    const SizedBox(height: DsSpacing.md),
                    _HeroCta(label: banner.ctaLabel, gradient: tint),
                  ],
                ),
              ),
              if (banner.badge != null)
                Positioned(
                  top: DsSpacing.md,
                  right: DsSpacing.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.sm,
                      vertical: DsSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      gradient: tint,
                      borderRadius: DsRadius.borderFull,
                      boxShadow: context.shadowXs,
                    ),
                    child: Text(
                      banner.badge!,
                      style: context.dsText.caption.bold.tint(DsColors.onMedia),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  LinearGradient _kindGradient(HeroBannerKind kind) => switch (kind) {
    HeroBannerKind.promotion => DsGradients.sunset,
    HeroBannerKind.campaign => DsGradients.mauve,
    HeroBannerKind.seasonal => DsGradients.champagne,
    HeroBannerKind.personalized => DsGradients.rewards,
  };
}

class _HeroCta extends StatelessWidget {
  const _HeroCta({required this.label, required this.gradient});

  final String label;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: DsColors.onMedia,
        borderRadius: DsRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.dsText.labelMedium.bold.tint(DsColors.onGold),
          ),
          const SizedBox(width: DsSpacing.xxs),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 15,
            color: DsColors.onGold,
          ),
        ],
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: DsShimmer(
        child: DsSkeleton.box(
          height: HomeHeroCarousel._height,
          borderRadius: DsRadius.xxl,
        ),
      ),
    );
  }
}
