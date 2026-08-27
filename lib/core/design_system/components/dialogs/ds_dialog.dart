import 'package:flutter/material.dart';
import 'package:reem/core/design_system/components/buttons/button_styles.dart';
import 'package:reem/core/design_system/components/buttons/ds_button.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';

/// Tone for a [DsDialog] icon header.
enum DsDialogTone { primary, success, warning, danger, info }

/// Helpers for Reem-styled dialogs (confirm / alert / custom).
abstract final class DsDialog {
  /// A confirm dialog. Resolves to `true` when the primary action is tapped.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    IconData? icon,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _DsDialogBody(
        title: title,
        message: message,
        icon: icon,
        tone: destructive ? DsDialogTone.danger : DsDialogTone.primary,
        actions: [
          DsButton(
            label: cancelLabel,
            variant: DsButtonVariant.tonal,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          DsButton(
            label: confirmLabel,
            variant:
                destructive ? DsButtonVariant.danger : DsButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// A single-action informational dialog.
  static Future<void> alert(
    BuildContext context, {
    required String title,
    String? message,
    String buttonLabel = 'Got it',
    IconData? icon,
    DsDialogTone tone = DsDialogTone.primary,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => _DsDialogBody(
        title: title,
        message: message,
        icon: icon,
        tone: tone,
        actions: [
          DsButton(
            label: buttonLabel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Present arbitrary content inside a Reem-styled dialog frame.
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
        child: child,
      ),
    );
  }
}

class _DsDialogBody extends StatelessWidget {
  const _DsDialogBody({
    required this.title,
    required this.actions,
    this.message,
    this.icon,
    this.tone = DsDialogTone.primary,
  });

  final String title;
  final String? message;
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
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.lg),
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
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: DsTypography.bold),
            ),
            if (message != null) ...[
              const SizedBox(height: DsSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: c.onSurfaceVariant),
              ),
            ],
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
    );
  }
}
