import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/features/home/domain/entities/dynamic_block.dart';
import 'package:reem/features/home/presentation/providers/home_content_provider.dart';

/// Renders merchandising blocks configured from the admin panel. Generic by
/// design so new campaigns ship without an app release.
class HomeDynamicBlocks extends ConsumerWidget {
  const HomeDynamicBlocks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(
      homeContentNotifierProvider.select(
        (s) => s.content?.dynamicBlocks ?? const <DynamicContentBlock>[],
      ),
    );

    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final block in blocks)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.xxxs,
              DsSpacing.lg,
              DsSpacing.md,
            ),
            child: switch (block.kind) {
              DynamicBlockKind.announcement => _AnnouncementBlock(block: block),
              _ => _SpotlightBlock(block: block),
            },
          ),
      ],
    );
  }
}

void _go(BuildContext context, DynamicContentBlock block) {
  if (block.targetRoute != null) context.push(block.targetRoute!);
}

class _SpotlightBlock extends StatelessWidget {
  const _SpotlightBlock({required this.block});

  final DynamicContentBlock block;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _go(context, block),
      child: ClipRRect(
        borderRadius: DsRadius.borderXxl,
        child: SizedBox(
          height: 158,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (block.imageUrl != null)
                CachedNetworkImage(
                  imageUrl: MediaVariants.at(
                    block.imageUrl!,
                    MediaVariants.medium,
                  ),
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      ColoredBox(color: context.dsColors.shimmerBase),
                  errorWidget: (_, _, _) => DecoratedBox(
                    decoration: BoxDecoration(gradient: DsGradients.mauve),
                  ),
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(gradient: DsGradients.mauve),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: DsGradients.imageScrim),
              ),
              Padding(
                padding: const EdgeInsets.all(DsSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      block.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.sectionTitle.copyWith(
                        color: DsColors.onMedia,
                        fontWeight: DsTypography.bold,
                      ),
                    ),
                    DsGaps.vXxxs,
                    Text(
                      block.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.cardSubtitle.copyWith(
                        color: DsColors.onMedia.withValues(alpha: 0.9),
                      ),
                    ),
                    if (block.ctaLabel != null) ...[
                      const SizedBox(height: DsSpacing.sm),
                      Container(
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
                              block.ctaLabel!,
                              style: context.dsText.labelMedium.bold.tint(
                                DsColors.onGold,
                              ),
                            ),
                            DsGaps.hXxs,
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: DsColors.onGold,
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _AnnouncementBlock extends StatelessWidget {
  const _AnnouncementBlock({required this.block});

  final DynamicContentBlock block;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return GestureDetector(
      onTap: () => _go(context, block),
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.md),
        decoration: BoxDecoration(
          color: c.accentContainer,
          borderRadius: DsRadius.borderXl,
          border: Border.all(color: c.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.campaign_rounded, color: c.onAccentContainer, size: 22),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.title,
                    style: context.dsText.labelLarge.bold.tint(
                      c.onAccentContainer,
                    ),
                  ),
                  Text(
                    block.subtitle,
                    style: context.dsText.caption.tint(
                      c.onAccentContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (block.ctaLabel != null)
              Icon(Icons.chevron_right_rounded, color: c.onAccentContainer),
          ],
        ),
      ),
    );
  }
}
