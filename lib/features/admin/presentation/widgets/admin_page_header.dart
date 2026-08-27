import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.xl, DsSpacing.xl, DsSpacing.xl, DsSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: DsTypography.headlineMedium,
                    fontWeight: DsTypography.bold,
                  color: palette.ink,
                ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: DsSpacing.xs),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: DsTypography.bodyMedium,
                      color: palette.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null)
            IntrinsicWidth(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: actions!,
              ),
            ),
        ],
      ),
    );
  }
}
