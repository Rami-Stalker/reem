import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/profile/domain/entities/wishlist_entity.dart';
import 'package:ohara/features/profile/presentation/providers/profile_provider.dart';

/// What kind of thing is being filed.
enum SaveTargetKind {
  product('product'),
  post('post'),
  seller('seller');

  const SaveTargetKind(this.wire);

  final String wire;
}

/// Where a newly saved piece should live.
///
/// Saving used to be one gesture with one destination: the flat «المحفوظات»
/// list. Collections existed — she could make them, name them, share them —
/// and there was no way at all to put anything *into* one except from the
/// wishlist screen afterwards, which nobody does. So a woman who had built
/// «عرس أختي» and «شتويات» could not save a dress into either of them.
///
/// This is the missing half, and it is deliberately shown *after* the save
/// rather than in front of it: the bookmark fills immediately, the piece is
/// already hers, and this only asks where to keep it. «بدون مجموعة» is a real
/// answer and the default, so the fast path stays one tap and a dismissal.
class SaveToCollectionSheet extends ConsumerStatefulWidget {
  const SaveToCollectionSheet({
    super.key,
    required this.kind,
    required this.targetId,
  });

  final SaveTargetKind kind;
  final String targetId;

  /// Opens the sheet. Every write inside it has already committed by the time
  /// it closes, so there is nothing to hand back.
  static Future<void> show(
    BuildContext context, {
    required SaveTargetKind kind,
    required String targetId,
  }) async {
    if (targetId.isEmpty) return;
    await DsBottomSheet.showTitled<void>(
      context,
      title: context.l10n.saveToCollection,
      subtitle: context.l10n.saveToCollectionBlurb,
      child: SaveToCollectionSheet(kind: kind, targetId: targetId),
    );
  }

  @override
  ConsumerState<SaveToCollectionSheet> createState() =>
      _SaveToCollectionSheetState();
}

class _SaveToCollectionSheetState extends ConsumerState<SaveToCollectionSheet> {
  /// Which row is mid-write. One at a time, so a slow connection cannot leave
  /// two rows both claiming to be busy.
  String? _busyCollectionId;

  bool _creating = false;

  @override
  void initState() {
    super.initState();
    // The overview carries the collections *and* what is in each, which is
    // what lets a row draw a tick. It is usually loaded already; this covers
    // the first save of a session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(wishlistNotifierProvider);
      if (state.overview.collections.isEmpty && !state.isLoading) {
        ref.read(wishlistNotifierProvider.notifier).load();
      }
    });
  }

  /// The row holding this piece inside [collection], or null.
  WishlistItem? _itemIn(WishlistCollection collection) {
    for (final item in collection.items) {
      final id = switch (widget.kind) {
        SaveTargetKind.product => item.product?.id,
        SaveTargetKind.post => item.post?.id,
        SaveTargetKind.seller => item.seller?.id,
      };
      if (id != null && id == widget.targetId) return item;
    }
    return null;
  }

  Future<void> _toggle(WishlistCollection collection) async {
    if (_busyCollectionId != null) return;
    final existing = _itemIn(collection);
    setState(() => _busyCollectionId = collection.id);

    final notifier = ref.read(wishlistNotifierProvider.notifier);
    final ok = existing != null
        ? await notifier.removeFromCollection(
            collectionId: collection.id,
            itemId: existing.id,
          )
        : await notifier.addToCollection(
            collectionId: collection.id,
            type: widget.kind.wire,
            productId: widget.kind == SaveTargetKind.product
                ? widget.targetId
                : null,
            postId: widget.kind == SaveTargetKind.post ? widget.targetId : null,
            sellerId: widget.kind == SaveTargetKind.seller
                ? widget.targetId
                : null,
          );

    if (!mounted) return;
    setState(() => _busyCollectionId = null);
    if (!ok) {
      DsSnackbar.error(context, context.l10n.actionDidNotSave);
      return;
    }
    DsSnackbar.success(
      context,
      existing != null
          ? context.l10n.removedFromCollection(collection.name)
          : context.l10n.addedToCollection(collection.name),
    );
  }

  /// «بدون مجموعة» — out of every collection that holds it, still saved.
  ///
  /// Not a no-op: a piece she filed and now wants loose needs a way back out
  /// that does not mean un-saving it.
  Future<void> _clearAll(List<WishlistCollection> holding) async {
    if (_busyCollectionId != null) return;
    final notifier = ref.read(wishlistNotifierProvider.notifier);
    for (final collection in holding) {
      final item = _itemIn(collection);
      if (item == null) continue;
      setState(() => _busyCollectionId = collection.id);
      await notifier.removeFromCollection(
        collectionId: collection.id,
        itemId: item.id,
      );
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(() => _busyCollectionId = null);
  }

  Future<void> _createAndFile() async {
    final name = await _promptForName();
    if (name == null || name.isEmpty || !mounted) return;

    setState(() => _creating = true);
    final notifier = ref.read(wishlistNotifierProvider.notifier);
    await notifier.createCollection(name: name);
    if (!mounted) return;

    // `createCollection` reloads the overview, so the new row is already in
    // state — found by name, because the notifier does not hand the row back.
    final created = ref
        .read(wishlistNotifierProvider)
        .overview
        .collections
        .where((collection) => collection.name == name)
        .firstOrNull;
    setState(() => _creating = false);
    if (created != null) await _toggle(created);
  }

  Future<String?> _promptForName() async {
    final controller = TextEditingController();
    try {
      return await DsBottomSheet.showTitled<String>(
        context,
        title: context.l10n.newCollection,
        scrollable: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Builder(
              builder: (sheetContext) => DsInputField(
                controller: controller,
                label: sheetContext.l10n.newCollectionName,
                autofocus: true,
                maxLength: 80,
                prefixIcon: const Icon(Icons.folder_special_outlined),
                onSubmitted: (value) =>
                    Navigator.of(sheetContext).pop(value.trim()),
              ),
            ),
            DsGaps.vMd,
            Builder(
              builder: (sheetContext) => PrimaryButton(
                label: sheetContext.l10n.createCollection,
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(wishlistNotifierProvider);
    final collections = state.overview.collections;
    final holding = collections
        .where((collection) => _itemIn(collection) != null)
        .toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CollectionRow(
          icon: Icons.bookmark_border_rounded,
          title: l10n.noCollection,
          subtitle: l10n.noCollectionBlurb,
          selected: holding.isEmpty,
          busy: false,
          onTap: holding.isEmpty ? null : () => _clearAll(holding),
        ),

        if (collections.isEmpty && !state.isLoading) ...[
          DsGaps.vMd,
          Text(
            l10n.collectionsEmptyHint,
            style: context.dsText.caption.tint(
              context.dsColors.onSurfaceVariant,
            ),
          ),
        ],

        for (final collection in collections) ...[
          DsGaps.vXs,
          _CollectionRow(
            icon: Icons.collections_bookmark_outlined,
            title: collection.name,
            subtitle: l10n.itemsCount(collection.itemsCount),
            selected: _itemIn(collection) != null,
            busy: _busyCollectionId == collection.id,
            onTap: () => _toggle(collection),
          ),
        ],

        DsGaps.vLg,
        SecondaryButton(
          label: l10n.createCollection,
          icon: Icons.create_new_folder_outlined,
          onPressed: _creating ? null : _createAndFile,
          isLoading: _creating,
        ),
      ],
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.busy,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: DsRadius.borderLg,
          onTap: busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(DsSpacing.md),
            decoration: BoxDecoration(
              color: selected
                  ? c.primaryContainer.withValues(alpha: 0.45)
                  : c.card,
              borderRadius: DsRadius.borderLg,
              border: Border.all(
                color: selected
                    ? c.primary.withValues(alpha: 0.5)
                    : c.border.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: selected ? c.primary : c.onSurfaceVariant),
                DsGaps.hMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.body.semibold,
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.caption.tint(c.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (selected)
                  Icon(Icons.check_circle_rounded, color: c.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
