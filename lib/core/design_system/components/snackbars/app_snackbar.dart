import 'package:flutter/material.dart';

import '../../foundation/theme/extensions/color_extension.dart';
import '../../foundation/tokens/ds_radius.dart';

enum DsSnackbarType { info, success, warning, error }

abstract final class DsSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    DsSnackbarType type = DsSnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colors = context.dsColors;
    final (background, icon) = switch (type) {
      DsSnackbarType.success => (colors.success, Icons.check_circle_rounded),
      DsSnackbarType.warning => (colors.warning, Icons.warning_rounded),
      DsSnackbarType.error => (colors.error, Icons.error_rounded),
      DsSnackbarType.info => (colors.onSurface, Icons.info_rounded),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: colors.surface, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: DsRadius.borderMd),
        duration: duration,
      ),
    );
  }
}
