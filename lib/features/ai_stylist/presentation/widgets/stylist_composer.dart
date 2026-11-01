import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/ai_stylist/presentation/widgets/stylist_aura.dart';

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
    this.hintText,
  });

  final ValueChanged<String> onSend;
  final List<String> suggestions;
  final bool enabled;
  final String? hintText;

  @override
  State<StylistComposer> createState() => _StylistComposerState();
}

class _StylistComposerState extends State<StylistComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _focusNode.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focusNode.hasFocus != _focused) {
      setState(() => _focused = _focusNode.hasFocus);
    }
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
    _focusNode
      ..removeListener(_onFocus)
      ..dispose();
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

    return DecoratedBox(
      // Fades the transcript into the composer instead of cutting it with a
      // hard line, so the input feels like it floats over the conversation.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.background.withValues(alpha: 0),
            colors.background.withValues(alpha: 0.92),
            colors.background,
          ],
          stops: const [0, 0.35, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsGaps.vXs,
            AnimatedSwitcher(
              duration: DsDurations.normal,
              child: widget.suggestions.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : _Suggestions(
                      // Keyed by content so a new set of follow-ups slides in
                      // rather than silently replacing the old one.
                      key: ValueKey(widget.suggestions.join('|')),
                      suggestions: widget.suggestions,
                      enabled: widget.enabled,
                      onTap: _submit,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.sm,
                DsSpacing.xs,
                DsSpacing.sm,
                DsSpacing.sm,
              ),
              child: StylistPanel(
                radius: DsRadius.xxl,
                padding: const EdgeInsetsDirectional.fromSTEB(
                  DsSpacing.xxs,
                  DsSpacing.xxs,
                  DsSpacing.xxs,
                  DsSpacing.xxs,
                ),
                highlighted: _focused,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: DsComposerField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: widget.enabled,
                        hint: widget.hintText ?? context.l10n.stylistComposerHint,
                        shape: DsComposerShape.panel,
                        maxLength: 1000,
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    DsGaps.hXxs,
                    _SendButton(
                      enabled: widget.enabled && _hasText,
                      onTap: _submit,
                    ),
                  ],
                ),
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
    super.key,
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
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => DsGaps.hXs,
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return StylistAppear(
            index: index,
            offset: 8,
            child: Center(
              child: AnimatedOpacity(
                duration: DsDurations.fast,
                opacity: enabled ? 1 : 0.5,
                child: DsScaleAnimations.tapScale(
                  enabled: enabled,
                  onTap: () => onTap(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.sm,
                      vertical: DsSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(DsRadius.pill),
                      border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.08),
                          blurRadius: DsSpacing.sm,
                          offset: const Offset(0, DsSpacing.xxxs),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 13, color: colors.primary),
                        DsGaps.hXxs,
                        Text(
                          suggestion,
                          style: context.dsText.labelMedium.medium.tint(colors.onSurface),
                        ),
                      ],
                    ),
                  ),
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

    return DsScaleAnimations.tapScale(
      enabled: enabled,
      onTap: onTap,
      semanticLabel: context.l10n.stylistSend,
      excludeChildSemantics: true,
      child: AnimatedContainer(
        duration: DsDurations.fast,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled ? context.boutique.signatureGradient : null,
          color: enabled ? null : colors.disabled,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.35),
                    blurRadius: DsSpacing.md,
                    offset: const Offset(0, DsSpacing.xxs),
                  ),
                ]
              : null,
        ),
        child: AnimatedRotation(
          duration: DsDurations.normal,
          // Points the arrow "up and away" once there is something to send.
          turns: enabled ? 0 : -0.125,
          child: const Icon(Icons.send_rounded, color: DsColors.onMedia, size: 20),
        ),
      ),
    );
  }
}
