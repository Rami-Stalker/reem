import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/catalog/domain/entities/category_node.dart';
import 'package:reem/features/catalog/presentation/providers/categories_provider.dart';

/// Picks the LEAF category a product belongs to.
///
/// This replaces a plain text box that asked a seller to type a category slug
/// from memory. `POST /seller/products` accepts a leaf's UUID and refuses
/// everything else, so there was no string she could have typed that would
/// have saved — and no list anywhere in the app to read one off. The field
/// shows the full crumb («ملابس › فساتين › فساتين سهرة») because two
/// departments may each hold a «فساتين سهرة», and the last word alone does not
/// say which shelf the product lands on.
class CategoryPickerField extends ConsumerWidget {
  const CategoryPickerField({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.enabled = true,
    this.errorText,
  });

  final String? selectedId;
  final ValueChanged<CategoryNode> onSelected;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final tree = ref.watch(categoryTreeProvider);
    final chosen = selectedId == null
        ? null
        : ref.watch(categoryByIdProvider(selectedId!));

    final subtitle = switch (tree) {
      AsyncError() => l10n.formCategoryFailed,
      AsyncLoading() when chosen == null => '…',
      _ => chosen?.crumb ?? l10n.formCategoryPick,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            DsSpacing.xs,
            0,
            0,
            DsSpacing.xs,
          ),
          child: Text(
            l10n.formCategory,
            style: context.dsText.body.semibold.tint(palette.muted),
          ),
        ),
        InkWell(
          borderRadius: DsRadius.borderMd,
          onTap: enabled ? () => _open(context, ref) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.md,
              vertical: DsSpacing.sm + DsSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: DsRadius.borderMd,
              border: Border.all(
                color: errorText != null ? palette.critical : palette.line,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 18,
                  color: chosen == null ? palette.muted : palette.ink,
                ),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.body.tint(chosen == null ? palette.muted : palette.ink),
                  ),
                ),
                Text(
                  chosen == null
                      ? l10n.formCategoryPick
                      : l10n.formCategoryChange,
                  style: context.dsText.caption.semibold.tint(context.dsColors.primary),
                ),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DsSpacing.xs,
              DsSpacing.xs,
              0,
              0,
            ),
            child: Text(
              errorText!,
              style: context.dsText.caption.tint(palette.critical),
            ),
          ),
      ],
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final picked = await DsBottomSheet.show<CategoryNode>(
      context,
      builder: (_) => const _CategorySheet(),
    );
    if (picked != null) onSelected(picked);
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet();

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  final _search = TextEditingController();

  /// The branch currently open. Empty means the department list.
  final List<CategoryNode> _trail = [];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tree = ref.watch(categoryTreeProvider);

    return DsSheetScaffold(
      title: l10n.formCategoryPick,
      subtitle: _trail.isEmpty ? null : _trail.last.crumb,
      child: switch (tree) {
        AsyncError() => Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpacing.xl),
          child: DsErrorState(
            message: l10n.formCategoryFailed,
            onRetry: () => ref.invalidate(categoryTreeProvider),
          ),
        ),
        AsyncData(:final value) => _body(context, value),
        _ => const Padding(
          padding: EdgeInsets.symmetric(vertical: DsSpacing.xxl),
          child: DsLoadingIndicator(),
        ),
      },
    );
  }

  Widget _body(BuildContext context, List<CategoryNode> roots) {
    final l10n = context.l10n;
    final query = _search.text.trim();

    // Searching flattens the whole tree: a woman typing «سهرة» wants every
    // shelf that matches, not only the branch she happens to have opened.
    final rows = query.isEmpty
        ? (_trail.isEmpty ? roots : _trail.last.children)
        : [
            for (final root in roots)
              ...root.leaves.where((leaf) => leaf.matches(query)),
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsInputField(
          controller: _search,
          hint: l10n.formCategorySearch,
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          onChanged: (_) => setState(() {}),
        ),
        if (query.isEmpty && _trail.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(_trail.removeLast),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(
                _trail.length == 1
                    ? l10n.categories
                    : _trail[_trail.length - 2].name,
              ),
            ),
          ),
        const SizedBox(height: DsSpacing.xs),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpacing.xl),
            child: Center(child: Text(l10n.formCategoryEmpty)),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: rows.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, indent: DsSpacing.lg, color: context.atelier.line),
              itemBuilder: (context, index) =>
                  _row(context, rows[index], query),
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, CategoryNode node, String query) {
    final palette = context.atelier;
    // While searching, every row is a leaf — so the crumb is the only thing
    // that tells two same-named shelves apart.
    final showCrumb = query.isNotEmpty && node.path.length > 1;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
      leading: Icon(
        node.isLeaf ? Icons.sell_outlined : Icons.folder_outlined,
        size: 20,
        color: node.isLeaf ? context.dsColors.primary : palette.muted,
      ),
      title: Text(
        node.name,
        style: context.dsText.body.medium.tint(palette.ink),
      ),
      subtitle: showCrumb
          ? Text(
              node.path.take(node.path.length - 1).join(' › '),
              style: context.dsText.caption.tint(palette.muted),
            )
          : null,
      trailing: node.isLeaf
          ? null
          : Icon(Icons.chevron_left_rounded, color: palette.muted),
      onTap: () {
        if (node.isLeaf) {
          Navigator.of(context).pop(node);
        } else {
          setState(() {
            _search.clear();
            _trail.add(node);
          });
        }
      },
    );
  }
}
