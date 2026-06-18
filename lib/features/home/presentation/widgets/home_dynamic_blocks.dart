import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/dynamic_block.dart';
import '../providers/home_content_provider.dart';

/// Renders merchandising blocks configured from the admin panel. Generic by
/// design so new campaigns ship without an app release.
class HomeDynamicBlocks extends ConsumerWidget {
  const HomeDynamicBlocks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(
      homeContentNotifierProvider
          .select((s) => s.content?.dynamicBlocks ?? const <DynamicContentBlock>[]),
    );

    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final block in blocks)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DsSpacing.lg, 0, DsSpacing.lg, DsSpacing.md),
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
    final theme = Theme.of(context);
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
                  imageUrl: block.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      ColoredBox(color: context.dsColors.shimmerBase),
                  errorWidget: (_, _, _) => DecoratedBox(
                      decoration: BoxDecoration(gradient: DsGradients.mauve)),
                )
              else
                DecoratedBox(
                    decoration: BoxDecoration(gradient: DsGradients.mauve)),
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
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: DsTypography.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      block.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    if (block.ctaLabel != null) ...[
                      const SizedBox(height: DsSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: DsSpacing.md, vertical: DsSpacing.xs),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: DsRadius.borderFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              block.ctaLabel!,
                              style: const TextStyle(
                                color: Color(0xFF221A1F),
                                fontWeight: DsTypography.bold,
                                fontSize: DsTypography.labelMedium,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded,
                                size: 14, color: Color(0xFF221A1F)),
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
                    style: TextStyle(
                      fontFamily: DsTypography.fontFamily,
                      fontWeight: DsTypography.bold,
                      fontSize: DsTypography.labelLarge,
                      color: c.onAccentContainer,
                    ),
                  ),
                  Text(
                    block.subtitle,
                    style: TextStyle(
                      fontSize: DsTypography.labelSmall,
                      color: c.onAccentContainer.withValues(alpha: 0.8),
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
