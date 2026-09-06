import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';

/// The input row, with the follow-up chips sitting above it.
///
/// The chips are not decoration: a chat with an empty box and no suggestions
/// asks the customer to invent a query, which is exactly the moment most
/// assistants lose her. They carry the last turn's follow-ups while a
/// conversation is running and the opening prompts before it starts.
class StylistComposer extends StatefulWidget {
  const StylistComposer({
    super.key,
    required this.onSend,
    this.suggestions = const [],
    this.enabled = true,
    this.hintText = 'خبّريني شو بتدوّري عليه…',
  });

  final ValueChanged<String> onSend;
  final List<String> suggestions;
  final bool enabled;
  final String hintText;

  @override
  State<StylistComposer> createState() => _StylistComposerState();
}

class _StylistComposerState extends State<StylistComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    final text = (value ?? _controller.text).trim();
    if (text.isEmpty || !widget.enabled) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.suggestions.isNotEmpty)
              _Suggestions(
                suggestions: widget.suggestions,
                enabled: widget.enabled,
                onTap: _submit,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.sm,
                DsSpacing.xs,
                DsSpacing.sm,
                DsSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        counterText: '',
                        filled: true,
                        fillColor: colors.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.sm,
                          vertical: DsSpacing.sm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DsRadius.field),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DsRadius.field),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: DsSpacing.xs),
                  _SendButton(
                    enabled: widget.enabled && _hasText,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.suggestions,
    required this.enabled,
    required this.onTap,
  });

  final List<String> suggestions;
  final bool enabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.xs),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return Center(
            child: InkWell(
              onTap: enabled ? () => onTap(suggestion) : null,
              borderRadius: BorderRadius.circular(DsRadius.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.sm,
                  vertical: DsSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(DsRadius.pill),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
                ),
                child: Text(
                  suggestion,
                  style: context.dsText.labelMedium.tint(colors.onPrimaryContainer),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return AnimatedContainer(
      duration: DsDurations.fast,
      decoration: BoxDecoration(
        color: enabled ? colors.primary : colors.disabled,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(Icons.send_rounded, color: colors.onPrimary, size: 20),
        tooltip: 'إرسال',
      ),
    );
  }
}
