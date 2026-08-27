import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';

enum DsSnackbarType { info, success, warning, error }

/// Reem-styled floating snackbars with a leading status icon and optional action.
abstract final class DsSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    DsSnackbarType type = DsSnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final c = context.dsColors;

    final (accent, icon) = switch (type) {
      DsSnackbarType.success => (c.success, Icons.check_circle_rounded),
      DsSnackbarType.warning => (c.warning, Icons.warning_amber_rounded),
      DsSnackbarType.error => (c.error, Icons.error_rounded),
      DsSnackbarType.info => (c.primary, Icons.info_rounded),
    };

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: accent, size: DsSpacing.lg),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: c.onInverseSurface,
                  fontFamily: DsTypography.fontFamily,
                  fontSize: DsTypography.bodyMedium,
                  fontWeight: DsTypography.medium,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: DsSpacing.xs),
              GestureDetector(
                onTap: onAction,
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    color: accent,
                    fontFamily: DsTypography.fontFamily,
                    fontSize: DsTypography.labelLarge,
                    fontWeight: DsTypography.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: c.inverseSurface,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.all(DsSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.md,
          vertical: DsSpacing.sm,
        ),
        shape: RoundedRectangleBorder(borderRadius: DsRadius.borderLg),
        duration: duration,
      ),
    );
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, type: DsSnackbarType.success);

  static void error(BuildContext context, String message) =>
      show(context, message: message, type: DsSnackbarType.error);
}
