import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:reem/core/design_system/components/buttons/button_styles.dart';
import 'package:reem/core/design_system/components/buttons/ds_button.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_constraints.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/platform/app_platform.dart';

/// Tone for a [DsDialog] icon header.
enum DsDialogTone { primary, success, warning, danger, info }

/// Helpers for Reem-styled dialogs (confirm / alert / prompt / custom).
///
/// **Adaptive by construction.** A modal is the most platform-specific piece
/// of furniture in a phone app: iOS expects a narrow centred alert with
/// hairline-separated text buttons and a destructive action painted red, and
/// nothing else reads as native there; Android expects a Material dialog with
/// filled buttons. Rather than dust `Platform.isIOS` through eleven screens,
/// the branch lives here once — every call site asks for *a confirmation* and
/// gets whichever one belongs on the phone in her hand.
abstract final class DsDialog {
  /// A confirm dialog. Resolves to `true` when the primary action is tapped.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,

    /// Null takes the localised default. A `const` default could not be
    /// localised, which is what left every confirm dialog in English.
    String? confirmLabel,
    String? cancelLabel,
    IconData? icon,
    bool destructive = false,
  }) async {
    final confirmText = confirmLabel ?? context.l10n.dialogConfirm;
    final cancelText = cancelLabel ?? context.l10n.cancel;

    final bool? result;
    if (AppPlatform.isApple) {
      result = await showCupertinoDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(title),
          content: message == null ? null : _CupertinoBody(message: message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelText),
            ),
            CupertinoDialogAction(
              isDestructiveAction: destructive,
              isDefaultAction: !destructive,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmText),
            ),
          ],
        ),
      );
    } else {
      result = await showDialog<bool>(
        context: context,
        builder: (ctx) => _DsDialogBody(
          title: title,
          message: message,
          icon: icon,
          tone: destructive ? DsDialogTone.danger : DsDialogTone.primary,
          actions: [
            DsButton(
              label: cancelText,
              variant: DsButtonVariant.tonal,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            DsButton(
              label: confirmText,
              variant: destructive
                  ? DsButtonVariant.danger
                  : DsButtonVariant.primary,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      );
    }
    return result ?? false;
  }

  /// A single-action informational dialog.
  static Future<void> alert(
    BuildContext context, {
    required String title,
    String? message,
    String? buttonLabel,
    IconData? icon,
    DsDialogTone tone = DsDialogTone.primary,
  }) {
    final label = buttonLabel ?? context.l10n.dialogGotIt;

    if (AppPlatform.isApple) {
      return showCupertinoDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(title),
          content: message == null ? null : _CupertinoBody(message: message),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(label),
            ),
          ],
        ),
      );
    }

    return showDialog<void>(
      context: context,
      builder: (ctx) => _DsDialogBody(
        title: title,
        message: message,
        icon: icon,
        tone: tone,
        actions: [
          DsButton(label: label, onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
  }

  /// Ask for one short line of text — a device name, a room title, the reason
  /// behind an administrative decision.
  ///
  /// Returns the trimmed text, or `null` if she backed out. An empty answer
  /// disables the confirm button rather than earning a second dialog telling
  /// her off.
  static Future<String?> prompt(
    BuildContext context, {
    required String title,
    String? message,
    String? initialValue,
    String? hintText,
    String? confirmLabel,
    String? cancelLabel,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    bool required = true,
  }) {
    final confirmText = confirmLabel ?? context.l10n.dialogConfirm;
    final cancelText = cancelLabel ?? context.l10n.cancel;

    Widget build(BuildContext _) => _PromptDialog(
      title: title,
      message: message,
      initialValue: initialValue,
      hintText: hintText,
      confirmLabel: confirmText,
      cancelLabel: cancelText,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      required: required,
      cupertino: AppPlatform.isApple,
    );

    if (AppPlatform.isApple) {
      return showCupertinoDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: build,
      );
    }
    return showDialog<String>(context: context, builder: build);
  }

  /// Present arbitrary content inside a Reem-styled dialog frame.
  ///
  /// Material on both platforms on purpose: this one holds bespoke content —
  /// a form, a chart, a picker — which Cupertino's alert frame cannot carry.
  /// The named helpers above are the ones a platform expects to look native;
  /// a custom panel is the app's own furniture.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.lg,
          vertical: DsSpacing.xxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: DsConstraints.maxDialogWidth,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Cupertino puts its own padding round the body; this only adds breathing
/// room between the title and a long message.
class _CupertinoBody extends StatelessWidget {
  const _CupertinoBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: DsSpacing.xs),
    child: Text(message, textAlign: TextAlign.center),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.cupertino,
    required this.required,
    this.message,
    this.initialValue,
    this.hintText,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
  });

  final String title;
  final String? message;
  final String? initialValue;
  final String? hintText;
  final String confirmLabel;
  final String cancelLabel;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool required;
  final bool cupertino;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => !widget.required || _controller.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) {
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cupertino) {
      return CupertinoAlertDialog(
        title: Text(widget.title),
        content: Padding(
          padding: const EdgeInsets.only(top: DsSpacing.sm),
          child: Column(
            children: [
              if (widget.message != null) ...[
                Text(widget.message!, textAlign: TextAlign.center),
                const SizedBox(height: DsSpacing.sm),
              ],
              CupertinoTextField(
                controller: _controller,
                autofocus: true,
                placeholder: widget.hintText,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                keyboardType: widget.keyboardType,
                textInputAction: widget.maxLines > 1
                    ? TextInputAction.newline
                    : TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.cancelLabel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: _canSubmit ? _submit : null,
            child: Text(widget.confirmLabel),
          ),
        ],
      );
    }

    return _DsDialogBody(
      title: widget.title,
      message: widget.message,
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        keyboardType: widget.keyboardType,
        textInputAction: widget.maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.done,
        decoration: InputDecoration(hintText: widget.hintText),
        onSubmitted: (_) => _submit(),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        DsButton(
          label: widget.cancelLabel,
          variant: DsButtonVariant.tonal,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DsButton(
          label: widget.confirmLabel,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

class _DsDialogBody extends StatelessWidget {
  const _DsDialogBody({
    required this.title,
    required this.actions,
    this.message,
    this.content,
    this.icon,
    this.tone = DsDialogTone.primary,
  });

  final String title;
  final String? message;
  final Widget? content;
  final IconData? icon;
  final DsDialogTone tone;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);

    final (iconBg, iconFg) = switch (tone) {
      DsDialogTone.primary => (c.primaryContainer, c.onPrimaryContainer),
      DsDialogTone.success => (c.successContainer, c.success),
      DsDialogTone.warning => (c.warningContainer, c.warning),
      DsDialogTone.danger => (c.errorContainer, c.error),
      DsDialogTone.info => (c.infoContainer, c.info),
    };

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.xl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: DsConstraints.maxDialogWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Head and body scroll; the actions stay put. Without this a
              // long message at 200% text overflowed the dialog and pushed
              // the buttons off the bottom of the screen — which is to say it
              // removed the only way out of the dialog.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(DsRadius.lg),
                          ),
                          child: Icon(icon, color: iconFg, size: 28),
                        ),
                        const SizedBox(height: DsSpacing.md),
                      ],
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: DsTypography.bold,
                        ),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: DsSpacing.xs),
                        Text(
                          message!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (content != null) ...[
                        const SizedBox(height: DsSpacing.md),
                        content!,
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DsSpacing.lg),
              if (actions.length == 2)
                Row(
                  children: [
                    Expanded(child: actions[0]),
                    const SizedBox(width: DsSpacing.sm),
                    Expanded(child: actions[1]),
                  ],
                )
              else
                ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
