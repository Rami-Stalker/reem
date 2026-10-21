import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

/// The inbox search field.
///
/// Owns its controller so the clear button can empty it, and reports every
/// keystroke upward — the debounce lives in the notifier, where it can also
/// discard a stale reply.
///
/// It used to be a hand-rolled `TextField` inside a pill: its own padding, its
/// own borderless decoration, its own Arabic tooltip typed inline. It now
/// draws the design system's search field, so the inbox, the console and the
/// catalogue all search in the same object and a change to the focus ring
/// reaches all three.
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DsInputField.search(
      controller: _controller,
      hint: widget.hintText,
      onChanged: widget.onChanged,
      onSubmitted: widget.onChanged,
      onClear: () => widget.onChanged(''),
    );
  }
}
