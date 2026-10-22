import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_motion.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';

/// The shape a composer takes.
enum DsComposerShape {
  /// A pill — a chat message, a comment.
  pill,

  /// A rounded panel that grows with the text — the stylist's brief, a note.
  panel,

  /// No chrome at all: a caption typed onto a card that already is the
  /// surface.
  bare,
}

/// The app's message box.
///
/// A composer is not a form field and should not be drawn as one: it has no
/// label, no error line and no fixed height, it grows as she types, and it
/// sits beside a send button rather than above a submit. But it is still text
/// input, and the five composers in this app — the chat, the comment sheet,
/// the stylist, the visual-search refinement, the post caption — had each
/// hand-rolled the same `InputDecoration` with slightly different padding,
/// slightly different radii and, in two cases, a hard-coded hint colour that
/// did not survive dark mode.
///
/// So they share this, and it shares [DsInputField]'s language: the same fill,
/// the same field radius, the same focus tint. Its growth is bounded the same
/// way everywhere — one line to [maxLines], never taller — because a composer
/// that can eat the screen is a composer that hides the conversation.
class DsComposerField extends StatelessWidget {
  const DsComposerField({
    super.key,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.shape = DsComposerShape.pill,
    this.minLines = 1,
    this.maxLines = 4,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction = TextInputAction.send,
    this.onChanged,
    this.onSubmitted,
    this.textStyle,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final DsComposerShape shape;
  final int minLines;
  final int maxLines;

  /// A ceiling the keyboard enforces, so a long message is stopped as she
  /// types rather than by a 400 after she taps send. Never drawn as a counter:
  /// a running tally over a chat box is a distraction in the one place she is
  /// least likely to be near the limit.
  final int? maxLength;

  final bool enabled;
  final bool autofocus;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// For the caption box, which is typed at reading size.
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final bare = shape == DsComposerShape.bare;
    final radius = switch (shape) {
      DsComposerShape.pill => DsRadius.borderPill,
      DsComposerShape.panel => DsRadius.borderField,
      DsComposerShape.bare => BorderRadius.zero,
    };

    return AnimatedSize(
      duration: DsMotion.fast,
      curve: DsMotion.silk,
      alignment: Alignment.bottomCenter,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        autofocus: autofocus,
        minLines: minLines,
        maxLines: maxLines,
        maxLength: maxLength,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        cursorColor: c.primary,
        cursorRadius: const Radius.circular(2),
        style: textStyle ?? context.dsText.body.tint(c.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: context.dsText.body.tint(c.onSurfaceVariant),
          counterText: '',
          filled: !bare,
          fillColor: c.surfaceVariant,
          isDense: true,
          contentPadding: bare
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(
                  horizontal: DsSpacing.md,
                  vertical: DsSpacing.sm,
                ),
          border: _border(radius, Colors.transparent, bare),
          enabledBorder: _border(radius, c.border.withValues(alpha: 0.5), bare),
          // The one visible state change: the brand edge, matching the form
          // field's focus ring without its glow, which under a keyboard would
          // be one soft shadow too many.
          focusedBorder: _border(radius, c.primary, bare, 1.4),
          disabledBorder: _border(radius, c.divider, bare),
        ),
      ),
    );
  }

  InputBorder _border(
    BorderRadius radius,
    Color colour,
    bool bare, [
    double width = 1,
  ]) {
    if (bare) return InputBorder.none;
    return OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colour, width: width),
    );
  }
}
