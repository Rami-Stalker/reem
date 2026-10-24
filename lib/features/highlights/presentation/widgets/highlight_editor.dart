import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/core/shared/entities/story.dart';
import 'package:ohara/features/highlights/domain/entities/highlight.dart';
import 'package:ohara/features/highlights/presentation/providers/highlights_providers.dart';
import 'package:ohara/features/highlights/presentation/widgets/highlights_rail.dart';

/// Making, naming and filling a highlight.
///
/// All of it is sheets rather than a screen: a highlight is a small decision
/// taken while looking at the page it will appear on, and pushing a route for
/// it would take the page away at exactly the moment she is judging how the
/// rail looks.
abstract final class HighlightEditor {
  /// «إبراز جديد» — name it, pick the stories, done.
  static Future<void> create(
    BuildContext context,
    WidgetRef ref,
    HighlightsProviderFamily provider,
  ) async {
    final title = await _askForName(context, initial: '');
    if (title == null || title.isEmpty || !context.mounted) return;

    final chosen = await pickStories(context, ref, alreadyIn: const {});
    if (!context.mounted) return;

    final created = await ref
        .read(provider.notifier)
        .create(title: title, contentIds: chosen.toList(growable: false));
    if (!context.mounted) return;
    if (created == null) {
      DsSnackbar.error(context, context.l10n.actionDidNotSave);
    }
  }

  /// The «…» on a shelf she owns.
  static Future<void> manage(
    BuildContext context,
    WidgetRef ref,
    HighlightsProviderFamily provider,
    Highlight highlight,
  ) async {
    final action = await DsBottomSheet.choose<_HighlightAction>(
      context,
      title: highlight.title,
      message: context.l10n.highlightStoriesCount(highlight.itemsCount),
      choices: [
        DsSheetChoice(
          value: _HighlightAction.add,
          label: context.l10n.highlightAddStories,
          icon: Icons.add_photo_alternate_outlined,
        ),
        DsSheetChoice(
          value: _HighlightAction.rename,
          label: context.l10n.highlightRename,
          icon: Icons.edit_outlined,
        ),
        DsSheetChoice(
          value: _HighlightAction.delete,
          label: context.l10n.highlightDelete,
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _HighlightAction.add:
        await _addStories(context, ref, provider, highlight);
      case _HighlightAction.rename:
        final title = await _askForName(context, initial: highlight.title);
        if (title == null || title.isEmpty || !context.mounted) return;
        await ref.read(provider.notifier).rename(highlight.id, title);
      case _HighlightAction.delete:
        final confirmed = await DsDialog.confirm(
          context,
          title: context.l10n.highlightDelete,
          message: context.l10n.highlightDeleteConfirm(highlight.title),
          confirmLabel: context.l10n.delete,
          destructive: true,
        );
        if (!confirmed || !context.mounted) return;
        await ref.read(provider.notifier).remove(highlight.id);
    }
  }

  static Future<void> _addStories(
    BuildContext context,
    WidgetRef ref,
    HighlightsProviderFamily provider,
    Highlight highlight,
  ) async {
    // What is already on the shelf, so the picker opens with it ticked and a
    // story she un-ticks is taken off rather than silently ignored.
    final full = await ref.read(provider.notifier).detail(highlight.id);
    if (!context.mounted) return;
    final before = <String>{
      for (final story in full?.stories ?? const <Story>[]) story.id,
    };

    final after = await pickStories(context, ref, alreadyIn: before);
    if (!context.mounted) return;

    final notifier = ref.read(provider.notifier);
    for (final id in after.difference(before)) {
      await notifier.addStory(highlight.id, id);
    }
    for (final id in before.difference(after)) {
      await notifier.removeStory(highlight.id, id);
    }
  }

  static Future<String?> _askForName(
    BuildContext context, {
    required String initial,
  }) async {
    final controller = TextEditingController(text: initial);
    try {
      return await DsBottomSheet.showTitled<String>(
        context,
        title: context.l10n.highlightCreate,
        scrollable: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Builder(
              builder: (sheetContext) => DsInputField(
                controller: controller,
                label: sheetContext.l10n.highlightNameLabel,
                hint: sheetContext.l10n.highlightNameHint,
                autofocus: true,
                maxLength: 40,
                prefixIcon: const Icon(Icons.auto_awesome_outlined),
                onSubmitted: (value) =>
                    Navigator.of(sheetContext).pop(value.trim()),
              ),
            ),
            DsGaps.vMd,
            Builder(
              builder: (sheetContext) => PrimaryButton(
                label: sheetContext.l10n.save,
                onPressed: () =>
                    Navigator.of(sheetContext).pop(controller.text.trim()),
              ),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  /// Her story archive, as a multiple choice.
  ///
  /// The archive is what makes the feature work: a story that expired
  /// yesterday is gone from the tray but not from the database, and this is
  /// the only screen in the app that shows it to her again.
  static Future<Set<String>> pickStories(
    BuildContext context,
    WidgetRef ref, {
    required Set<String> alreadyIn,
  }) async {
    final chosen = await DsBottomSheet.showTitled<Set<String>>(
      context,
      title: context.l10n.highlightPickStories,
      child: _StoryPicker(initial: alreadyIn),
    );
    return chosen ?? alreadyIn;
  }
}

enum _HighlightAction { add, rename, delete }

class _StoryPicker extends ConsumerStatefulWidget {
  const _StoryPicker({required this.initial});

  final Set<String> initial;

  @override
  ConsumerState<_StoryPicker> createState() => _StoryPickerState();
}

class _StoryPickerState extends ConsumerState<_StoryPicker> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final archive = ref.watch(highlightArchiveProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        archive.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: DsSpacing.xxl),
            child: DsLoadingIndicator(),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpacing.xl),
            child: DsErrorState(
              message: context.l10n.error,
              onRetry: () => ref.invalidate(highlightArchiveProvider),
            ),
          ),
          data: (stories) => stories.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpacing.xl),
                  child: Text(
                    context.l10n.highlightArchiveEmpty,
                    textAlign: TextAlign.center,
                    style: context.dsText.body.tint(
                      context.dsColors.onSurfaceVariant,
                    ),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stories.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: DsSpacing.xs,
                        mainAxisSpacing: DsSpacing.xs,
                        childAspectRatio: 0.62,
                      ),
                  itemBuilder: (context, index) => _StoryCell(
                    story: stories[index],
                    selected: _selected.contains(stories[index].id),
                    onTap: () => setState(() {
                      final id = stories[index].id;
                      if (!_selected.remove(id)) _selected.add(id);
                    }),
                  ),
                ),
        ),
        DsGaps.vMd,
        Text(
          context.l10n.highlightSelected(_selected.length),
          textAlign: TextAlign.center,
          style: context.dsText.caption.tint(context.dsColors.onSurfaceVariant),
        ),
        DsGaps.vXs,
        PrimaryButton(
          label: context.l10n.done,
          onPressed: () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }
}

class _StoryCell extends StatelessWidget {
  const _StoryCell({
    required this.story,
    required this.selected,
    required this.onTap,
  });

  final Story story;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final url = story.coverUrl;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.borderMd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: DsRadius.borderMd,
              child: url == null || url.isEmpty
                  ? ColoredBox(
                      color: c.surfaceVariant,
                      child: Icon(
                        Icons.image_outlined,
                        color: c.onSurfaceVariant,
                      ),
                    )
                  : AuthorizedMediaImage(
                      url: url,
                      variantWidth: MediaVariants.thumbnail,
                      fit: BoxFit.cover,
                    ),
            ),
            if (selected)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: DsRadius.borderMd,
                  border: Border.all(color: c.primary, width: 2.5),
                  color: c.primary.withValues(alpha: 0.18),
                ),
              ),
            PositionedDirectional(
              top: DsSpacing.xxs,
              end: DsSpacing.xxs,
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 20,
                color: selected ? c.primary : DsColors.onMedia,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
