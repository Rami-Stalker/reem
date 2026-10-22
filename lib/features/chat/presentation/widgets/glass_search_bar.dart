import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';

/// The inbox search field.
///
/// Owns its controller so the clear button can empty it, and reports every
/// keystroke upward — the debounce lives in the notifier, where it can also
/// discard a stale reply.
class GlassSearchBar extends StatefulWidget {
  const GlassSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
  });

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  State<GlassSearchBar> createState() => _GlassSearchBarState();
}

class _GlassSearchBarState extends State<GlassSearchBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handle(String value) {
    final hasText = value.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
    widget.onChanged(value);
  }

  void _clear() {
    _controller.clear();
    _handle('');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: DsRadius.borderFull,
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
      ),
      child: TextField(
        controller: _controller,
        onChanged: _handle,
        textInputAction: TextInputAction.search,
        style: context.dsText.body,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.md,
            vertical: DsSpacing.md,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: c.onSurfaceVariant),
          suffixIcon: _hasText
              ? IconButton(
                  tooltip: context.l10n.chatClearSearch,
                  icon: Icon(Icons.close_rounded, color: c.onSurfaceVariant),
                  onPressed: _clear,
                )
              : null,
          hintText: widget.hintText,
          hintStyle: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: c.onSurfaceVariant),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
