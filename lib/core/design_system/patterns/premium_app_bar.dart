import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/open_route.dart';

/// Which of Reem's three registers a piece of chrome belongs to.
///
/// The app bar used to sniff the current route (`path.startsWith('/seller')`)
/// to decide how to paint itself, which meant a seller widget shown inside a
/// buyer route silently changed identity. The role is now an argument with a
/// route-derived default, so callers can be explicit where it matters.
enum ReemSurfaceRole { customer, seller, admin }

/// Resolves the role from the current route, matching the historical behaviour.
///
/// Falls back to the buyer when there is no router overhead — widget tests and
/// the visual previews render these screens outside a `GoRoute`, and a header
/// that throws there is a header nobody can review.
ReemSurfaceRole reemRoleOf(BuildContext context) {
  final path = GoRouter.maybeOf(context)?.state.uri.path;
  if (path == null) return ReemSurfaceRole.customer;
  if (path.startsWith('/seller')) return ReemSurfaceRole.seller;
  if (path.startsWith('/admin')) return ReemSurfaceRole.admin;
  return ReemSurfaceRole.customer;
}

/// The colours a piece of role chrome needs, resolved from the active theme.
@immutable
class ReemChrome {
  const ReemChrome({
    required this.role,
    required this.foreground,
    required this.muted,
    required this.ground,
    required this.titleGradient,
  });

  factory ReemChrome.of(BuildContext context, [ReemSurfaceRole? role]) {
    final resolved = role ?? reemRoleOf(context);
    switch (resolved) {
      case ReemSurfaceRole.seller:
        final p = context.atelier;
        return ReemChrome(
          role: resolved,
          foreground: p.ink,
          muted: p.muted,
          ground: p.background,
          titleGradient: LinearGradient(colors: [p.primary, p.gold]),
        );
      case ReemSurfaceRole.admin:
        final p = context.console;
        return ReemChrome(
          role: resolved,
          foreground: p.ink,
          muted: p.muted,
          ground: p.background,
          titleGradient: LinearGradient(colors: [p.primary, p.info]),
        );
      case ReemSurfaceRole.customer:
        final p = context.boutique;
        return ReemChrome(
          role: resolved,
          foreground: p.ink,
          muted: p.muted,
          // The frosted bar sits over the silk backdrop; `surface` in dark and
          // the pearl-tinted surface in light both read as the page continuing
          // upward rather than a band laid across it.
          ground: p.surface,
          titleGradient: p.signatureGradient,
        );
    }
  }

  final ReemSurfaceRole role;

  /// Icons and plain text in the bar.
  final Color foreground;

  /// Subtitles and inactive chrome.
  final Color muted;

  /// The ground the frosted bar fades out of.
  final Color ground;

  /// Shader for the title. Every role gets a gradient title so the top of a
  /// page always reads as Reem.
  final LinearGradient titleGradient;
}

/// The app's one page header.
///
/// Every scrolling screen starts with this, so the top 100px of the app is the
/// same object everywhere: a pinned, frosted bar that fades out of the page
/// ground, a centred gradient title, and optional actions. Screens differ
/// below the bar, not at it.
///
/// [subtitle], [bottom] and [flexibleContent] exist so the screens that used to
/// hand-roll their own `SliverAppBar` — the courier day, the wallet, the seller
/// order list — can express what they needed without leaving the pattern.
class PremiumAppBar extends StatelessWidget {
  const PremiumAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.actions,
    this.bottom,
    this.flexibleContent,
    this.expandedHeight,
    this.role,
    this.onBack,
    this.centerTitle = true,
  });

  final String title;

  /// A quiet second line under the title. Suppressed when [flexibleContent] is
  /// given, since that takes over the expanded area.
  final String? subtitle;

  final bool showBack;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  /// Content painted in the expanded area behind the title — a hero balance,
  /// a cover photo, a summary strip. Sits under the frosted scrim.
  final Widget? flexibleContent;

  final double? expandedHeight;

  /// Defaults to the role of the current route.
  final ReemSurfaceRole? role;

  /// Defaults to `context.pop()`.
  final VoidCallback? onBack;

  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    final chrome = ReemChrome.of(context, role);
    final text = context.dsText;
    final height = expandedHeight ??
        (flexibleContent != null
            ? DsSizes.appBarExpanded * 2
            : DsSizes.appBarExpanded);

    return SliverAppBar(
      pinned: true,
      stretch: true,
      elevation: 0,
      expandedHeight: height,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: chrome.foreground),
      actionsIconTheme: IconThemeData(color: chrome.foreground),
      leading: showBack
          ? IconButton(
              icon: Icon(
                DsIcons.back,
                color: chrome.foreground,
                size: DsSizes.iconSm,
              ),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack ?? () => popOrHome(context),
            )
          : null,
      actions: actions,
      bottom: bottom,
      flexibleSpace: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ?flexibleContent,
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: DsBlur.medium,
                sigmaY: DsBlur.medium,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      chrome.ground.withValues(alpha: 0.88),
                      chrome.ground.withValues(
                        alpha: flexibleContent != null ? 0.10 : 0.38,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      centerTitle: centerTitle,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: chrome.titleGradient.createShader,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // The shader supplies the colour; the role only supplies size,
              // weight and family.
              style: text.sectionTitle.uiFamily.bold.tint(DsColors.onMedia),
            ),
          ),
          if (subtitle != null && flexibleContent == null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.caption.tint(chrome.muted),
            ),
        ],
      ),
    );
  }
}

/// The box-layout twin of [PremiumAppBar], for the handful of screens that use
/// `Scaffold(appBar:)` rather than a sliver list — image viewers, modals and
/// anything hosting a `TabBar`.
///
/// It exists so those screens stop reaching for a bare Material [AppBar], which
/// is where the stray default-blue titles and un-frosted grounds came from.
class ReemAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ReemAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions,
    this.bottom,
    this.role,
    this.onBack,
    this.transparent = false,
  });

  final String title;
  final bool showBack;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final ReemSurfaceRole? role;
  final VoidCallback? onBack;

  /// True for bars floating over media, where the ground must not be painted.
  final bool transparent;

  @override
  Size get preferredSize => Size.fromHeight(
        DsSizes.appBarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final chrome = ReemChrome.of(context, role);
    final foreground = transparent ? DsColors.onMedia : chrome.foreground;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor:
          transparent ? Colors.transparent : chrome.ground.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      iconTheme: IconThemeData(color: foreground),
      actionsIconTheme: IconThemeData(color: foreground),
      leading: showBack
          ? IconButton(
              icon: Icon(DsIcons.back, color: foreground, size: DsSizes.iconSm),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack ?? () => popOrHome(context),
            )
          : null,
      actions: actions,
      bottom: bottom,
      title: transparent
          ? Text(
              title,
              style: context.dsText.sectionTitle.uiFamily.bold.tint(foreground),
            )
          : ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: chrome.titleGradient.createShader,
              child: Text(
                title,
                style:
                    context.dsText.sectionTitle.uiFamily.bold.tint(DsColors.onMedia),
              ),
            ),
    );
  }
}
