import 'package:flutter/material.dart';

import 'package:ohara/app/bootstrap.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';

/// Her language, chosen at the vanity: three small mirrors, each showing the
/// script it would dress the app in, and the chosen one lit.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = AppBootstrap.localeController;
    final gutter = vanityGutter(context);

    return ListenableBuilder(
      listenable: locale,
      builder: (context, _) {
        return OharaScrollPage(
          slivers: [
            VanityAppBar(
              title: l10n.language,
              subtitle: l10n.selectLanguage,
              icon: Icons.translate_rounded,
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
                          selected: locale.isArabic,
                          title: l10n.ar,
                          // l10n-ignore: a language is named in its own script.
                          subtitle: 'العربية',
                          // l10n-ignore: the script itself, shown in the glass.
                          preview: const _Script('ع'),
                          onTap: locale.setArabic,
                        ),
                      ),
                      DsGaps.hSm,
                      Expanded(
                        child: VanityChoice(
                          selected: locale.isEnglish,
                          title: l10n.en,
                          // l10n-ignore: a language names itself, never translated
                          subtitle: 'English',
                          // l10n-ignore: the script itself, shown in the glass.
                          preview: const _Script('Aa'),
                          onTap: locale.setEnglish,
                        ),
                      ),
                      DsGaps.hSm,
                      Expanded(
                        child: VanityChoice(
                          selected: locale.followsSystem,
                          title: l10n.systemLanguage,
                          subtitle: l10n.followDeviceLanguage,
                          icon: Icons.phone_iphone_rounded,
                          onTap: locale.setSystem,
                        ),
                      ),
                    ],
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

/// A script's letter, large in the display serif, as the mirror's reflection.
class _Script extends StatelessWidget {
  const _Script(this.glyph);

  final String glyph;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Center(
      child: Text(
        glyph,
        style: context.dsText.pageTitle.displayFamily.bold.tint(
          palette.primary,
        ),
      ),
    );
  }
}
