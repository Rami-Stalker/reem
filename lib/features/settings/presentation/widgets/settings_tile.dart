import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:reem/core/design_system/design_system.dart';

class LuxurySettingsTile extends StatefulWidget {
  const LuxurySettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  State<LuxurySettingsTile> createState() => _LuxurySettingsTileState();
}

class _LuxurySettingsTileState extends State<LuxurySettingsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: DsMotion.fast,
        child: ClipRRect(
          borderRadius: DsRadius.borderXxxl,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: DsBlur.medium,
              sigmaY: DsBlur.medium,
            ),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.glass.withValues(alpha: DsOpacity.medium),
                borderRadius: DsRadius.borderXxxl,
                border: Border.all(color: colors.glassBorder),
                boxShadow: context.softShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: context.primaryGradient,
                    ),
                    child: Icon(widget.icon, color: colors.onPrimary),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: DsTypography.semiBold,
                          ),
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.glass.withValues(alpha: DsOpacity.soft),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.15);
  }
}
