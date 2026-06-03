import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

class EditableProfileField extends StatelessWidget {
  const EditableProfileField({
    super.key,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  final String hint;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: ClipRRect(
        borderRadius: DsRadius.borderXxl,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: DsBlur.light, sigmaY: DsBlur.light),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            decoration: BoxDecoration(
              gradient: context.ds.glassGradient,
              borderRadius: DsRadius.borderXxl,
              border: Border.all(color: colors.glassBorder),
            ),
            child: TextField(
              maxLines: maxLines,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                border: InputBorder.none,
                icon: Icon(icon, color: colors.primary),
                hintText: hint,
                hintStyle: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
