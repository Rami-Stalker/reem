import 'package:flutter/material.dart';
import 'package:reem/app/bootstrap.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/l10n/app_localizations.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = AppBootstrap.themeController;
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) {
        return ReemScrollPage(
          slivers: [
            PremiumAppBar(title: l10n.appearance, showBack: true),
            SliverPadding(
              padding: const EdgeInsets.all(DsSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    l10n.appearanceDescription,
                    style: context.dsText.body.copyWith(
                          color: context.dsColors.onSurfaceVariant,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: DsSpacing.xxl),
                  _ThemeOptionCard(
                    selected: theme.mode == DsAppThemeMode.light,
                    title: l10n.themeLight,
                    subtitle: l10n.themeLightSubtitle,
                    icon: Icons.light_mode_rounded,
                    previewGradient: DsGradients.background,
                    onTap: () => theme.setMode(DsAppThemeMode.light),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  _ThemeOptionCard(
                    selected: theme.mode == DsAppThemeMode.dark,
                    title: l10n.themeDark,
                    subtitle: l10n.themeDarkSubtitle,
                    icon: Icons.dark_mode_rounded,
                    previewGradient: DsGradients.backgroundDark,
                    onTap: () => theme.setMode(DsAppThemeMode.dark),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  _ThemeOptionCard(
                    selected: theme.mode == DsAppThemeMode.system,
                    title: l10n.themeSystem,
                    subtitle: l10n.themeSystemSubtitle,
                    icon: Icons.phone_iphone_rounded,
                    previewGradient: DsGradients.lavenderBlush,
                    onTap: () => theme.setMode(DsAppThemeMode.system),
                  ),
                  const SizedBox(height: DsSpacing.xxxl),
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

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.previewGradient,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient previewGradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DsMotion.normal,
        padding: const EdgeInsets.all(DsSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: DsRadius.borderXxl,
          gradient: selected ? context.primaryGradient : null,
          color: selected ? null : colors.card,
          border: Border.all(
            color: selected ? colors.primary : colors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? context.luxuryShadow : context.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: DsRadius.borderLg,
                gradient: previewGradient,
              ),
              child: Icon(
                icon,
                color: selected ? colors.onPrimary : colors.primary,
              ),
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.dsText.cardTitle.bold.tint(selected ? colors.onPrimary : colors.onSurface),
                  ),
                  DsGaps.vXxs,
                  Text(
                    subtitle,
                    style: context.dsText.bodySmall.tint(selected
                          ? colors.onPrimary.withValues(alpha: 0.88)
                          : colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.mode});

  final DsAppThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.preview,
          style: context.dsText.cardTitle.copyWith(
                fontWeight: DsTypography.bold,
              ),
        ),
        const SizedBox(height: DsSpacing.md),
        Container(
          padding: const EdgeInsets.all(DsSpacing.lg),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: DsRadius.borderXxl,
            border: Border.all(color: colors.border),
            boxShadow: context.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: context.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.favorite_rounded, color: colors.onPrimary),
              ),
              const SizedBox(width: DsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.appTitle,
                      style: context.dsText.body.bold.tint(colors.onSurface),
                    ),
                    Text(
                      _modeLabel(l10n, mode),
                      style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: DsSpacing.xs),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: DsRadius.borderFull,
                ),
                child: Text(
                  l10n.active,
                  style: context.dsText.caption.semibold.tint(colors.primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _modeLabel(AppLocalizations l10n, DsAppThemeMode mode) => switch (mode) {
        DsAppThemeMode.light => l10n.themeLightActive,
        DsAppThemeMode.dark => l10n.themeDarkActive,
        DsAppThemeMode.system => l10n.themeSystemActive,
      };
}
