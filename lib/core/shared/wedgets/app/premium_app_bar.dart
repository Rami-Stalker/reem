import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/design_system.dart';

class PremiumAppBar extends StatelessWidget {
  const PremiumAppBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions,
  });

  final String title;
  final bool showBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      elevation: 0,
      expandedHeight: 100,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: showBack
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: colors.onSurface, size: 20),
              onPressed: () => context.pop(),
            )
          : null,
      actions: actions,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: DsBlur.medium, sigmaY: DsBlur.medium),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.surface.withValues(alpha: 0.85),
                  colors.surface.withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
        ),
      ),
      centerTitle: true,
      title: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => context.primaryGradient.createShader(bounds),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: DsTypography.fontFamily,
            fontWeight: DsTypography.bold,
            fontSize: DsTypography.titleLarge,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
