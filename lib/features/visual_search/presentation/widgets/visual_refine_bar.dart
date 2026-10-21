import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';

/// "أريد نفس هذا الفستان لكن باللون الأسود."
///
/// A composer, not a filter row, because what she is doing is *correcting* —
/// and a correction is a sentence, not a set of toggles. "شي أكتر احتشامًا"
/// has no chip; "أقل من ٤٠٠ ألف" has a slider somewhere but not one she wants
/// to hunt for while looking at a dress she likes.
///
/// The suggestions above the field are the server's, not the client's. They
/// come from `/visual-search/bootstrap`, so the phrasing the assistant is
/// known to read well can change without an app release.
class VisualRefineBar extends StatefulWidget {
  const VisualRefineBar({
    super.key,
    required this.enabled,
    required this.onSubmit,
    this.suggestions = const [],
    this.hint = 'وصفيلي شو بدك تغيّري…',
  });

  final bool enabled;
  final List<String> suggestions;
  final String hint;
  final void Function(String text) onSubmit;

  @override
  State<VisualRefineBar> createState() => _VisualRefineBarState();
}

class _VisualRefineBarState extends State<VisualRefineBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    final text = (value ?? _controller.text).trim();
    if (text.isEmpty || !widget.enabled) return;
    _controller.clear();
    _focus.unfocus();
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Container(
      padding: EdgeInsets.only(
        left: DsSpacing.md,
        right: DsSpacing.md,
        top: DsSpacing.sm,
        // Above the home indicator, not under it.
        bottom: DsSpacing.sm + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.suggestions.isNotEmpty) ...[
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.xs),
                itemBuilder: (context, index) {
                  final suggestion = widget.suggestions[index];
                  return DsChip(
                    label: suggestion,
                    onTap: widget.enabled ? () => _submit(suggestion) : null,
                  );
                },
              ),
            ),
            const SizedBox(height: DsSpacing.xs),
          ],
          Row(
            children: [
              Expanded(
                child: DsComposerField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  hint: widget.hint,
                  shape: DsComposerShape.panel,
                  maxLines: 3,
                  maxLength: 400,
                  onSubmitted: _submit,
                ),
              ),
              const SizedBox(width: DsSpacing.xs),
              DsIconButton(
                icon: Icons.arrow_upward_rounded,
                onPressed: widget.enabled ? _submit : null,
                tooltip: 'عدّلي البحث',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
