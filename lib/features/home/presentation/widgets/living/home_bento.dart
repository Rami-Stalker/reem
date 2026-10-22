import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/home/domain/entities/home_category.dart';
import 'package:reem/features/home/presentation/providers/home_content_provider.dart';

/// «تجوّلي بين الأقسام» — the departments as a bento, not a row of circles.
///
/// A row of equal circles says every department is the same size and the
/// same mood. The bento gives the first one a tall tile, stacks two beside
/// it, and lays a wide one under them — a layout that reads as an editor's
/// choice. Each tile carries its own colour wash and how many pieces wait
/// inside, so the grid looks different from one week to the next.
class HomeBento extends ConsumerWidget {
  const HomeBento({super.key});

  static const double _tall = DsSizes.railCardHeight + DsSpacing.lg;
  static const double _wide = DsSizes.thumbLg + DsSpacing.xl;

  static const List<List<Color>> _washes = [
    [DsColors.primary700, DsColors.primary400],
    [DsColors.mauve700, DsColors.lavender400],
    [DsColors.gold600, DsColors.gold300],
    [DsColors.mauve800, DsColors.coral400],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(
      homeContentNotifierProvider.select(
        (s) => s.content?.featuredCategories ?? const <HomeCategory>[],
      ),
    );
    if (categories.length < 3) return const SizedBox.shrink();

    final l10n = context.l10n;
    final colors = context.dsColors;
    final picks = categories.take(4).toList();

    Widget tile(int i) => _BentoTile(category: picks[i], wash: _washes[i]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeBentoEyebrow,
            style: context.dsText.overline.tint(colors.primary),
          ),
          DsGaps.vXxs,
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.homeBentoTitle,
                  style: context.dsText.sectionTitle.displayFamily.bold,
                ),
              ),
              TextButton(
                onPressed: () => context.push(RoutePaths.categories),
                child: Text(l10n.viewAll),
              ),
            ],
          ),
          DsGaps.vSm,
          SizedBox(
            height: _tall,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: tile(0)),
                DsGaps.hSm,
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: tile(1)),
                      DsGaps.vSm,
                      Expanded(child: tile(2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (picks.length > 3) ...[
            DsGaps.vSm,
            SizedBox(height: _wide, child: tile(3)),
          ],
        ],
      ),
    );
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({required this.category, required this.wash});

  final HomeCategory category;
  final List<Color> wash;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: category.label,
      child: GestureDetector(
        onTap: () => context.push(RoutePaths.categoryOf(category.slug)),
        child: ClipRRect(
          borderRadius: DsRadius.borderXxl,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: wash,
                  ),
                ),
              ),
              if (category.imageUrl.isNotEmpty)
                Opacity(
                  opacity: 0.78,
                  child: CachedNetworkImage(
                    imageUrl: MediaVariants.thumb(category.imageUrl),
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              // The wash again, from the foot, so the name always reads.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.25, 1],
                    colors: [
                      wash.first.withValues(alpha: 0),
                      wash.first.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                top: DsSpacing.sm,
                end: DsSpacing.sm,
                child: Container(
                  width: DsSizes.controlSm,
                  height: DsSizes.controlSm,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DsColors.mediaPlate,
                    border: Border.all(color: DsColors.onMediaFaint),
                  ),
                  child: const Icon(
                    Icons.north_west_rounded,
                    size: DsSizes.iconXs,
                    color: DsColors.onMedia,
                  ),
                ),
              ),
              PositionedDirectional(
                start: DsSpacing.md,
                end: DsSpacing.md,
                bottom: DsSpacing.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.sectionTitle.displayFamily.bold
                          .tint(DsColors.onMedia),
                    ),
                    Text(
                      l10n.homeBentoCount(category.productCount),
                      style: context.dsText.caption.tint(DsColors.onMediaMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
