import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../foundation/theme/extensions/color_extension.dart';
import '../../foundation/tokens/ds_spacing.dart';
import '../../foundation/tokens/ds_typography.dart';

/// The Reem text field — a premium, fully theme-driven input with an optional
/// label above the field, helper/error text, and a built-in password toggle.
///
/// Backwards compatible: `prefixIcon` / `suffixIcon` remain [Widget]s.
class DsInputField extends StatefulWidget {
  const DsInputField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.initialValue,
    this.inputFormatters,
    this.autofillHints,
    this.labelAbove = true,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final String? initialValue;
  final List<TextInputFormatter>? inputFormatters;

  /// Lets the platform fill the field — most importantly
  /// `AutofillHints.oneTimeCode`, which puts the code from the notification
  /// one tap away. On Reem that code *is* the credential, so the difference
  /// between one tap and retyping six digits from another app is the
  /// difference between a sign-in that works on a bad connection and one that
  /// times out halfway through.
  final List<String>? autofillHints;

  /// Render the label as a styled caption above the field (premium look).
  /// When false, falls back to the Material floating label.
  final bool labelAbove;

  @override
  State<DsInputField> createState() => _DsInputFieldState();
}

class _DsInputFieldState extends State<DsInputField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final showLabelAbove = widget.labelAbove && widget.label != null;

    Widget? suffix = widget.suffixIcon;
    if (widget.obscureText && suffix == null) {
      suffix = IconButton(
        icon: Icon(
          _obscured
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: c.onSurfaceVariant,
          size: 20,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
        splashRadius: 20,
      );
    }

    final field = TextFormField(
      controller: widget.controller,
      initialValue: widget.initialValue,
      focusNode: widget.focusNode,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      style: theme.textTheme.bodyLarge,
      cursorColor: c.primary,
      decoration: InputDecoration(
        labelText: showLabelAbove ? null : widget.label,
        hintText: widget.hint,
        helperText: widget.helperText,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: suffix,
      ),
    );

    if (!showLabelAbove) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: DsSpacing.xxs,
            bottom: DsSpacing.xs,
          ),
          child: Text(
            widget.label!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: c.onSurface,
              fontWeight: DsTypography.semiBold,
            ),
          ),
        ),
        field,
      ],
    );
  }
}
