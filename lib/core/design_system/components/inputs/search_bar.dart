import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_constraints.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';

/// A premium pill search bar with leading icon, clear affordance and an
/// optional filter button (with active-count badge).
///
/// Set [readOnly] + [onTap] to use it as a tappable entry point that navigates
/// to a dedicated search screen.
class DsSearchBar extends StatefulWidget {
  const DsSearchBar({
    super.key,
    this.controller,
    this.hint = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onClear,
    this.onFilter,
    this.filterActiveCount,
    this.readOnly = false,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final VoidCallback? onFilter;
  final int? filterActiveCount;
  final bool readOnly;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<DsSearchBar> createState() => _DsSearchBarState();
}

class _DsSearchBarState extends State<DsSearchBar> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  bool get _ownsController => widget.controller == null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final hasText = _controller.text.isNotEmpty;

    final bar = Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: DsRadius.borderPill,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              color: c.onSurfaceVariant, size: DsConstraints.iconMd),
          const SizedBox(width: DsSpacing.xs),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              readOnly: widget.readOnly,
              autofocus: widget.autofocus,
              onTap: widget.onTap,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              style: theme.textTheme.bodyMedium,
              cursorColor: c.primary,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: theme.textTheme.bodyMedium
                    ?.copyWith(color: c.onSurfaceVariant),
              ),
            ),
          ),
          if (hasText)
            GestureDetector(
              onTap: () {
                _controller.clear();
                widget.onChanged?.call('');
                widget.onClear?.call();
              },
              child: Icon(Icons.close_rounded,
                  color: c.onSurfaceVariant, size: 20),
            ),
          if (widget.onFilter != null) ...[
            const SizedBox(width: DsSpacing.xs),
            _FilterButton(
              activeCount: widget.filterActiveCount,
              onTap: widget.onFilter!,
            ),
          ],
        ],
      ),
    );

    return bar;
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onTap, this.activeCount});

  final VoidCallback onTap;
  final int? activeCount;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final active = activeCount != null && activeCount! > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.xs,
          vertical: DsSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: active ? c.primaryContainer : c.surface,
          borderRadius: DsRadius.borderPill,
          border: Border.all(color: active ? c.primary : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded,
                size: 18, color: active ? c.onPrimaryContainer : c.onSurface),
            if (active) ...[
              const SizedBox(width: DsSpacing.xxs),
              Text(
                '${activeCount!}',
                style: TextStyle(
                  color: c.onPrimaryContainer,
                  fontSize: DsTypography.labelMedium,
                  fontWeight: DsTypography.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
