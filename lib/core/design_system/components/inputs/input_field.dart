import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/shadow_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_motion.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_sizes.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';
import 'package:reem/core/localization/l10n_extension.dart';

/// How a field is drawn.
enum DsFieldVariant {
  /// The default: a filled, softly bordered field with the label above it.
  filled,

  /// A pill with a leading magnifier, for search bars.
  search,

  /// No fill and a single underline — for a field sitting on top of a photo or
  /// inside a card that already carries the surface.
  bare,
}

/// The Reem text field.
///
/// One input for the whole app, so a form in the seller's atelier, the address
/// sheet and the sign-in screen are the same object rather than three
/// near-copies of `TextFormField`.
///
/// What it does that a bare Material field does not:
///
///  * **The focus reads as focus.** The border thickens, tints to the brand and
///    lifts a soft rose glow, all on the same curve as the buttons. The old
///    field changed a border colour by 0.5dp and nothing else, which on a
///    phone in daylight is invisible.
///  * **The label belongs to the field.** It sits above, and it tints with the
///    focus and turns red on an error — so at a glance you can see *which*
///    field a form is complaining about without reading the message.
///  * **Errors are announced, not just printed.** The message carries an icon
///    and is read out; the field is marked invalid for a screen reader rather
///    than merely drawn in red.
///  * **It can be cleared.** A one-tap clear appears while there is text, which
///    matters most in exactly the places typing is hardest — a search bar, a
///    phone number typed with one hand.
///  * **Counting is quiet.** Material's counter sits under the field in a
///    colour nothing else uses and reserves its line whether or not there is a
///    limit; this draws it only when a limit exists and only once she is
///    within reach of it.
///  * **Digits stay digits.** A phone number, a code and a price are pinned
///    left-to-right inside an otherwise Arabic form, so `09` does not jump to
///    the wrong end of the field.
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
    this.variant = DsFieldVariant.filled,
    this.clearable,
    this.onClear,
    this.onTap,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
  });

  /// A search bar: pill, magnifier, clear button, no label above.
  const DsInputField.search({
    super.key,
    this.controller,
    this.hint,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onTap,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.suffixIcon,
    this.inputFormatters,
  })  : label = null,
        helperText = null,
        errorText = null,
        prefixIcon = null,
        obscureText = false,
        keyboardType = TextInputType.text,
        textInputAction = TextInputAction.search,
        validator = null,
        maxLines = 1,
        minLines = null,
        maxLength = null,
        initialValue = null,
        autofillHints = null,
        labelAbove = false,
        variant = DsFieldVariant.search,
        clearable = true,
        textCapitalization = TextCapitalization.none,
        autocorrect = false;

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
  final TextCapitalization textCapitalization;
  final bool autocorrect;

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

  final DsFieldVariant variant;

  /// Show a clear button while there is text. Defaults to true for a search
  /// bar and false elsewhere, because a clear button on every field in a long
  /// form is noise — and on a password field it is a hazard.
  final bool? clearable;

  /// Called after the field is cleared, so a search can re-run.
  final VoidCallback? onClear;

  /// For a field that opens something — a date picker, a country sheet —
  /// rather than a keyboard. Pair with `readOnly: true`.
  final VoidCallback? onTap;

  @override
  State<DsInputField> createState() => _DsInputFieldState();
}

class _DsInputFieldState extends State<DsInputField> {
  late bool _obscured = widget.obscureText;

  /// Ours when the caller gave none — and then ours to dispose.
  FocusNode? _ownedFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownedFocus ??= FocusNode());

  TextEditingController? _ownedController;
  TextEditingController get _controller =>
      widget.controller ??
      (_ownedController ??= TextEditingController(text: widget.initialValue));

  bool _focused = false;

  /// The error the *form* produced, as opposed to the one the caller passed.
  /// Held so the label and the border can turn red together — `TextFormField`
  /// keeps its validation state to itself.
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant DsInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      _ownedFocus?.removeListener(_onFocusChanged);
      _focus.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocusChanged);
    _ownedFocus?.removeListener(_onFocusChanged);
    _ownedFocus?.dispose();
    _ownedController?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted || _focus.hasFocus == _focused) return;
    setState(() => _focused = _focus.hasFocus);
  }

  bool get _hasError =>
      (widget.errorText != null && widget.errorText!.isNotEmpty) ||
      (_validationError != null && _validationError!.isNotEmpty);

  String? get _errorMessage =>
      widget.errorText?.isNotEmpty == true ? widget.errorText : _validationError;

  bool get _showsClear {
    final wanted = widget.clearable ?? (widget.variant == DsFieldVariant.search);
    return wanted &&
        widget.enabled &&
        !widget.obscureText &&
        _controller.text.isNotEmpty;
  }

  /// Fields whose content is not prose.
  ///
  /// A phone number, a one-time code, an IBAN and a price are read
  /// left-to-right even inside an Arabic form; left to the ambient direction,
  /// `09` ends up rendered at the wrong end of the field and a woman checking
  /// her own number against her SIM cannot tell whether she mistyped it.
  bool get _isLtrContent => switch (widget.keyboardType) {
    TextInputType.phone ||
    TextInputType.number ||
    TextInputType.emailAddress ||
    TextInputType.url => true,
    _ => const [
      AutofillHints.oneTimeCode,
      AutofillHints.telephoneNumber,
      AutofillHints.creditCardNumber,
    ].any((hint) => widget.autofillHints?.contains(hint) ?? false),
  };

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final isSearch = widget.variant == DsFieldVariant.search;
    final showLabelAbove =
        widget.labelAbove && widget.label != null && !isSearch;

    final borderColour = !widget.enabled
        ? c.divider
        : _hasError
        ? c.error
        : _focused
        ? c.primary
        : c.border;

    Widget? suffix = widget.suffixIcon;
    if (widget.obscureText && suffix == null) {
      suffix = IconButton(
        // Flips with the state: a screen reader announces the action she is
        // about to take, and "show password" on an already-visible field
        // would send her the wrong way.
        tooltip: _obscured
            ? context.l10n.showPassword
            : context.l10n.hidePassword,
        icon: Icon(
          _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: c.onSurfaceVariant,
          size: DsSizes.iconSm,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      );
    } else if (_showsClear) {
      suffix = _ClearButton(onPressed: _clear, suffix: widget.suffixIcon);
    }

    final field = TextFormField(
      controller: _controller,
      focusNode: _focus,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      autocorrect: widget.autocorrect,
      // The framework's own direction for the *content*, so Arabic prose still
      // reads right-to-left while a phone number does not.
      textDirection: _isLtrContent ? TextDirection.ltr : null,
      validator: widget.validator == null
          ? null
          : (value) {
              final message = widget.validator!(value);
              // After the frame: `validate()` runs during a build, and the
              // label recolouring is a `setState` on this widget.
              if (message != _validationError) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _validationError = message);
                });
              }
              return message;
            },
      onChanged: (value) {
        widget.onChanged?.call(value);
        // Only when it changes whether the clear button is drawn.
        if (widget.clearable ?? isSearch) setState(() {});
      },
      onFieldSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      // Drawn by hand below, so it is quiet and appears only near the limit.
      buildCounter: _noCounter,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      style: theme.textTheme.bodyLarge?.copyWith(color: c.onSurface),
      cursorColor: c.primary,
      cursorRadius: const Radius.circular(2),
      decoration: InputDecoration(
        labelText: showLabelAbove ? null : widget.label,
        hintText: widget.hint,
        // Both are drawn below so they can share one line and one rhythm.
        helperText: null,
        errorText: null,
        // Material reserves a line for the error under every field; suppressing
        // it here is what keeps a form from jumping by 20dp per field the
        // first time it is validated.
        errorStyle: const TextStyle(height: 0, fontSize: 0),
        isDense: isSearch,
        filled: widget.variant != DsFieldVariant.bare,
        fillColor: widget.enabled ? c.surfaceVariant : c.surfaceVariant.withValues(alpha: 0.6),
        contentPadding: EdgeInsets.symmetric(
          horizontal: DsSpacing.md,
          vertical: isSearch ? DsSpacing.sm : DsSpacing.md,
        ),
        prefixIcon: isSearch
            ? Icon(Icons.search_rounded, color: c.onSurfaceVariant, size: DsSizes.iconSm)
            : widget.prefixIcon,
        prefixIconColor: _focused ? c.primary : c.onSurfaceVariant,
        suffixIcon: suffix,
        suffixIconColor: c.onSurfaceVariant,
        border: _border(borderColour, isSearch, 1),
        enabledBorder: _border(borderColour, isSearch, 1),
        focusedBorder: _border(borderColour, isSearch, 1.6),
        errorBorder: _border(c.error, isSearch, 1),
        focusedErrorBorder: _border(c.error, isSearch, 1.6),
        disabledBorder: _border(c.divider, isSearch, 1),
      ),
    );

    // The glow is on the wrapper rather than on the border, so it can grow
    // outwards without changing the field's own size and shifting the layout.
    final glowing = AnimatedContainer(
      duration: DsMotion.fast,
      curve: DsMotion.silk,
      decoration: BoxDecoration(
        borderRadius: isSearch ? DsRadius.borderPill : DsRadius.borderField,
        boxShadow: _focused && widget.enabled
            ? context.glowShadow(
                _hasError ? c.error : c.primary,
                blur: 16,
                alpha: 0.22,
              )
            : null,
      ),
      child: field,
    );

    final message = _errorMessage;
    final counter = _counterText();

    if (!showLabelAbove && message == null && counter == null) return glowing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabelAbove)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: DsSpacing.xxs,
              bottom: DsSpacing.xs,
            ),
            child: AnimatedDefaultTextStyle(
              duration: DsMotion.fast,
              style:
                  theme.textTheme.labelLarge?.copyWith(
                    color: _hasError
                        ? c.error
                        : _focused
                        ? c.primary
                        : c.onSurface,
                    fontWeight: DsTypography.semiBold,
                  ) ??
                  const TextStyle(),
              child: Text(widget.label!),
            ),
          ),
        glowing,
        if (message != null || widget.helperText != null || counter != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: DsSpacing.xxs,
              end: DsSpacing.xxs,
              top: DsSpacing.xxs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message != null)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 14,
                          color: c.error,
                        ),
                        const SizedBox(width: DsSpacing.xxs),
                        Expanded(
                          child: Text(
                            message,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: c.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (widget.helperText != null)
                  Expanded(
                    child: Text(
                      widget.helperText!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (counter != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: DsSpacing.xs),
                    child: Text(
                      counter,
                      // Furniture, so it never grows over the field it counts.
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// `120 / 240`, and only once she is within a quarter of the limit.
  ///
  /// A counter under every bounded field from the first keystroke reads as a
  /// warning about something that has not happened yet.
  String? _counterText() {
    final limit = widget.maxLength;
    if (limit == null || limit <= 0) return null;
    final length = _controller.text.characters.length;
    if (length < limit * 0.75) return null;
    return '$length / $limit';
  }

  OutlineInputBorder _border(Color colour, bool isSearch, double width) =>
      OutlineInputBorder(
        borderRadius: isSearch ? DsRadius.borderPill : DsRadius.borderField,
        borderSide: BorderSide(color: colour, width: width),
      );
}

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required int? maxLength,
  required bool isFocused,
}) => null;

/// The one-tap clear, drawn beside whatever suffix the caller already asked for.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onPressed, this.suffix});

  final VoidCallback onPressed;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: context.l10n.clear,
      onPressed: onPressed,
      icon: Icon(
        Icons.cancel_rounded,
        size: 18,
        color: context.dsColors.onSurfaceVariant,
      ),
    );
    if (suffix == null) return button;
    return Row(mainAxisSize: MainAxisSize.min, children: [button, suffix!]);
  }
}
