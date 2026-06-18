import 'package:flutter/material.dart';

import 'button_sizes.dart';
import 'button_styles.dart';
import 'ds_button.dart';

/// Transparent tertiary action. Thin wrapper over [DsButton].
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = DsButtonSize.md,
    this.isExpanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final DsButtonSize size;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return DsButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      size: size,
      isExpanded: isExpanded,
      variant: DsButtonVariant.ghost,
    );
  }
}
