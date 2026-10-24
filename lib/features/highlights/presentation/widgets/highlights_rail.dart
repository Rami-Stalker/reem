import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/core/platform/app_haptics.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/highlights/domain/entities/highlight.dart';
import 'package:ohara/features/highlights/presentation/providers/highlights_providers.dart';
import 'package:ohara/features/highlights/presentation/widgets/highlight_editor.dart';
import 'package:ohara/features/stories/presentation/screens/story_viewer_screen.dart';

/// «الأبرز» on a page.
///
/// One rail for both sides of the marketplace: a shopper's «إطلالاتي» and a
/// boutique's «مقاساتنا» are the same object, drawn the same way, because the
/// only thing that differs is what is on the shelf.
///
/// It draws nothing at all on somebody else's page with no highlights — an
/// empty rail on a storefront is a sentence about a feature rather than about
/// the boutique. On her own page it draws the invitation instead, because the
/// one person who needs to be told the shelf exists is the one who could fill
/// it.
class HighlightsRail extends ConsumerWidget {
  const HighlightsRail({super.key, this.ownerId});

  /// Null for the signed-in account's own rail.
  final String? ownerId;

  static const double _size = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = highlightsProvider(ownerId ?? '');
    final state = ref.watch(provider);
    final mine =
        ownerId == null ||
        state.highlights.any((highlight) => highlight.isMine);

    if (state.isLoading && state.isEmpty) {
      return const _RailSkeleton(size: _size);
    }
    if (state.isEmpty && !mine) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            child: Text(
              context.l10n.highlights,
              style: context.dsText.sectionTitle.bold,
            ),
          ),
          if (state.isEmpty && mine) ...[
            DsGaps.vXs,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
              child: Text(
                context.l10n.highlightEmptyOwner,
                style: context.dsText.caption.tint(
                  context.dsColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
          DsGaps.vSm,
          SizedBox(
            height: _size + 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
              children: [
                if (mine) ...[
                  _NewHighlightTile(
                    size: _size,
                    onTap: () => HighlightEditor.create(context, ref, provider),
                  ),
                  const SizedBox(width: DsSpacing.md),
                ],
                for (final highlight in state.highlights) ...[
                  _HighlightTile(
                    highlight: highlight,
                    size: _size,
                    onTap: () => _open(context, ref, provider, highlight),
                    onLongPress: highlight.isMine
                        ? () => HighlightEditor.manage(
                            context,
                            ref,
                            provider,
                            highlight,
                          )
                        : null,
                  ),
                  const SizedBox(width: DsSpacing.md),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the shelf in the app's one story viewer.
  ///
  /// The stories come from the detail read rather than the rail, which carries
  /// covers and counts only — so the tap costs one request and the rail costs
  /// none.
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    HighlightsProviderFamily provider,
    Highlight highlight,
  ) async {
    AppHaptics.selection();
    final full = await ref.read(provider.notifier).detail(highlight.id);
    if (!context.mounted) return;
    if (full == null || full.stories.isEmpty) {
      DsSnackbar.show(
        context,
        message: context.l10n.highlightEmptyOpen,
        type: DsSnackbarType.info,
      );
      return;
    }
    await context.push(
      RoutePaths.storyViewer,
      extra: StoryViewerArgs(stories: full.stories),
    );
  }
}

/// The family's type, so the rail can hand its own provider to the editor
/// rather than the editor guessing which page it is on.
typedef HighlightsProviderFamily =
    StateNotifierProvider<HighlightsNotifier, HighlightsState>;

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.highlight,
    required this.size,
    required this.onTap,
    this.onLongPress,
  });

  final Highlight highlight;
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final cover = highlight.coverUrl;

    return Semantics(
      button: true,
      label: '${highlight.title}، '
          '${context.l10n.highlightStoriesCount(highlight.itemsCount)}',
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          onLongPress: onLongPress,
          radius: size * 0.7,
          child: SizedBox(
            width: size + 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // The same ring the stories tray uses, quieted: a highlight
                    // is kept rather than new, so it should not compete with an
                    // unseen story for the same glance.
                    gradient: context.primaryGradient,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.surface,
                    ),
                    child: ClipOval(
                      child: cover == null || cover.isEmpty
                          ? ColoredBox(
                              color: c.surfaceVariant,
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                color: c.onSurfaceVariant,
                                size: 22,
                              ),
                            )
                          : AuthorizedMediaImage(
                              url: cover,
                              variantWidth: MediaVariants.thumbnail,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
                DsGaps.vXxs,
                Text(
                  highlight.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.dsText.caption.tint(c.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewHighlightTile extends StatelessWidget {
  const _NewHighlightTile({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Semantics(
      button: true,
      label: context.l10n.highlightCreate,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          radius: size * 0.7,
          child: SizedBox(
            width: size + 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.surfaceVariant,
                    border: Border.all(
                      color: c.border,
                      // Dashed is not a thing a Flutter border does; a lighter
                      // ring says "not filled yet" well enough.
                      width: 1.2,
                    ),
                  ),
                  child: Icon(Icons.add_rounded, color: c.primary, size: 26),
                ),
                DsGaps.vXxs,
                Text(
                  context.l10n.highlightNew,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.caption.tint(c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailSkeleton extends StatelessWidget {
  const _RailSkeleton({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    // A horizontal list rather than a `Row`: four 72-point circles and their
    // gaps are wider than a 360-point handset, and a `Row` answers that by
    // overflowing rather than by scrolling.
    return SizedBox(
      height: size + DsSpacing.md * 2,
      child: DsShimmer(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.lg,
            vertical: DsSpacing.md,
          ),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
          itemBuilder: (_, _) => DsSkeleton.circle(size: size),
        ),
      ),
    );
  }
}
