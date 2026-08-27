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
    final atelier = context.atelier;
    final console = context.console;
    final path = GoRouterState.of(context).uri.path;
    final isSeller = path.startsWith('/seller');
    final isAdmin = path.startsWith('/admin');
    final foreground = isSeller
        ? atelier.ink
        : isAdmin
        ? console.ink
        : colors.onSurface;
    // Both role gradients here shade *text*, so neither can be the deep
    // header gradient meant to sit behind white — that painted a near-black
    // title on a near-black bar in dark mode and the page name vanished.
    final titleGradient = isSeller
        ? LinearGradient(colors: [atelier.primary, atelier.gold])
        : isAdmin
        ? LinearGradient(colors: [console.primary, console.info])
        : CustomerExperience.signatureGradient;
    final ground = isSeller
        ? atelier.background
        : isAdmin
        ? console.background
        : CustomerExperience.pearl;
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
                  color: foreground, size: 20),
              onPressed: () => context.pop(),
            )
          : null,
      actions: actions,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: DsBlur.medium, sigmaY: DsBlur.medium),
          child: Container(
            decoration: BoxDecoration(
              // The frosted ground behind the bar. Seller and admin resolve
              // from their palettes; only the buyer's pearl is a fixed brand
              // colour, and that one is intentional.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ground.withValues(alpha: 0.88),
                  ground.withValues(alpha: 0.38),
                ],
              ),
            ),
          ),
        ),
      ),
      centerTitle: true,
      title: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => titleGradient.createShader(bounds),
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
