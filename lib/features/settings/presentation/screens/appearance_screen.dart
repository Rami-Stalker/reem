import 'package:flutter/material.dart';
import 'package:ohara/app/bootstrap.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// Light, dark or her phone's choice — three mirrors, each glass showing the
/// room in that light, and a reflection of the app as it now is below.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = AppBootstrap.themeController;
    final gutter = vanityGutter(context);
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) {
        return OharaScrollPage(
          slivers: [
            VanityAppBar(
              title: l10n.appearance,
              subtitle: l10n.appearanceDescription,
              icon: Icons.palette_outlined,
              showBack: true,
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, DsSpacing.xl, gutter, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: VanityChoice(
                          selected: theme.mode == DsAppThemeMode.light,
                          title: l10n.themeLight,
                          subtitle: l10n.themeLightSubtitle,
                          preview: const _Glass(
                            gradient: DsGradients.background,
                            icon: Icons.light_mode_rounded,
                            tint: DsColors.gold500,
                          ),
                          onTap: () => theme.setMode(DsAppThemeMode.light),
                        ),
                      ),
                      DsGaps.hSm,
                      Expanded(
                        child: VanityChoice(
                          selected: theme.mode == DsAppThemeMode.dark,
                          title: l10n.themeDark,
                          subtitle: l10n.themeDarkSubtitle,
                          preview: const _Glass(
                            gradient: DsGradients.backgroundDark,
                            icon: Icons.dark_mode_rounded,
                            tint: DsColors.gold200,
                          ),
                          onTap: () => theme.setMode(DsAppThemeMode.dark),
                        ),
                      ),
                      DsGaps.hSm,
                      Expanded(
                        child: VanityChoice(
                          selected: theme.mode == DsAppThemeMode.system,
                          title: l10n.themeSystem,
                          subtitle: l10n.themeSystemSubtitle,
                          preview: const _Glass(
                            gradient: DsGradients.lavenderBlush,
                            icon: Icons.phone_iphone_rounded,
                            tint: DsColors.primary600,
                          ),
                          onTap: () => theme.setMode(DsAppThemeMode.system),
                        ),
                      ),
                    ],
                  ),
                  DsGaps.vXxl,
                  _LivePreview(mode: theme.mode),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The glass of a theme's mirror: that theme's ground, and its mark.
class _Glass extends StatelessWidget {
  const _Glass({
    required this.gradient,
    required this.icon,
    required this.tint,
  });

  final Gradient gradient;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Center(
        child: Icon(icon, color: tint, size: DsSizes.iconMd),
      ),
    );
  }
}

/// The app as it now looks, in a tray: what her choice has done.
class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.mode});

  final DsAppThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.boutique;
    return VanityTray(
      title: l10n.preview,
      children: [
        VanityRow(
          icon: Icons.favorite_rounded,
          title: l10n.appTitle,
          subtitle: _modeLabel(l10n, mode),
          trailing: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.sm,
              vertical: DsSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: palette.goldSoft,
              borderRadius: DsRadius.borderPill,
              border: Border.all(color: palette.gold.withValues(alpha: 0.5)),
            ),
            child: Text(
              l10n.active,
              style: context.dsText.caption.semibold.tint(palette.ink),
            ),
          ),
        ),
      ],
    );
  }

  String _modeLabel(AppLocalizations l10n, DsAppThemeMode mode) =>
      switch (mode) {
        DsAppThemeMode.light => l10n.themeLightActive,
        DsAppThemeMode.dark => l10n.themeDarkActive,
        DsAppThemeMode.system => l10n.themeSystemActive,
      };
}
