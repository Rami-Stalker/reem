import 'package:flutter/material.dart';

import 'package:reem/app/bootstrap.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = AppBootstrap.localeController;

    return ListenableBuilder(
      listenable: locale,
      builder: (context, _) {
        return ReemScrollPage(
          slivers: [
            PremiumAppBar(title: l10n.language, showBack: true),
            SliverPadding(
              padding: const EdgeInsets.all(DsSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    l10n.selectLanguage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.dsColors.onSurfaceVariant,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: DsSpacing.xxl),
                  _LanguageOption(
                    title: l10n.systemLanguage,
                    subtitle: l10n.followDeviceLanguage,
                    icon: Icons.language_rounded,
                    selected: locale.followsSystem,
                    onTap: locale.setSystem,
                  ),
                  const SizedBox(height: DsSpacing.md),
                  _LanguageOption(
                    title: l10n.en,
                    subtitle: 'English',
                    icon: Icons.translate_rounded,
                    selected: locale.isEnglish,
                    onTap: locale.setEnglish,
                  ),
                  const SizedBox(height: DsSpacing.md),
                  _LanguageOption(
                    title: l10n.ar,
                    subtitle: 'العربية',
                    icon: Icons.menu_book_rounded,
                    selected: locale.isArabic,
                    onTap: locale.setArabic,
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected
                    ? colors.onPrimary.withValues(alpha: 0.2)
                    : colors.primary.withValues(alpha: 0.12),
                borderRadius: DsRadius.borderLg,
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
                    style: TextStyle(
                      fontFamily: DsTypography.fontFamily,
                      fontWeight: DsTypography.bold,
                      fontSize: DsTypography.titleMedium,
                      color: selected ? colors.onPrimary : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: DsTypography.bodySmall,
                      color: selected
                          ? colors.onPrimary.withValues(alpha: 0.88)
                          : colors.onSurfaceVariant,
                    ),
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
