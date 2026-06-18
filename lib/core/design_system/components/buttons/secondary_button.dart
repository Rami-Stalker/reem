import 'package:flutter/material.dart';

import 'button_sizes.dart';
import 'button_styles.dart';
import 'ds_button.dart';

/// Outlined rose secondary action. Thin wrapper over [DsButton].
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = DsButtonSize.md,
    this.isLoading = false,
    this.isExpanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final DsButtonSize size;
  final bool isLoading;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return DsButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      size: size,
      isLoading: isLoading,
      isExpanded: isExpanded,
      variant: DsButtonVariant.secondary,
    );
  }
}
