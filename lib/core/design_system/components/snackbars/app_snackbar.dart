import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:ohara/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:ohara/core/localization/readable_message.dart';
import 'package:ohara/l10n/app_localizations.dart';

enum DsSnackbarType { info, success, warning, error }

/// Ohara-styled floating snackbars with a leading status icon and optional action.
abstract final class DsSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    DsSnackbarType type = DsSnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) => on(
    ScaffoldMessenger.of(context),
    message: type == DsSnackbarType.error
        ? readableMessage(AppLocalizations.of(context), message)
        : message,
    type: type,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// The same snackbar, through a messenger captured before an `await`.
  ///
  /// A screen that awaits a request and then reports the outcome cannot use
  /// its own context afterwards — she may have left the screen. The messenger
  /// outlives it, and so does the messenger's own context, which is where
  /// the colours and type are read from here.
  static void on(
    ScaffoldMessengerState messenger, {
    required String message,
    DsSnackbarType type = DsSnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final context = messenger.context;
    final c = context.dsColors;
    // The messenger usually sits above the app's Localizations, so this is
    // null there and `show` has already resolved the message.
    if (type == DsSnackbarType.error) {
      message = readableMessage(AppLocalizations.of(context), message);
    }

    final (accent, icon) = switch (type) {
      DsSnackbarType.success => (c.success, Icons.check_circle_rounded),
      DsSnackbarType.warning => (c.warning, Icons.warning_amber_rounded),
      DsSnackbarType.error => (c.error, Icons.error_rounded),
      DsSnackbarType.info => (c.primary, Icons.info_rounded),
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: accent, size: DsSpacing.lg),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: context.dsText.body.medium.tint(c.onInverseSurface),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: DsSpacing.xs),
              GestureDetector(
                onTap: onAction,
                child: Text(
                  actionLabel,
                  style: context.dsText.labelLarge.bold.tint(accent),
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
