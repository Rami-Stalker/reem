import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// The empty state, which is really the onboarding.
///
/// Nobody opens a chat box knowing what an AI stylist can do, so the screen
/// answers that before she asks: three worked examples in her own words, each
/// tappable. They are the same sentences the feature was specified against,
/// which means the demo is also the regression test.
class StylistWelcome extends StatelessWidget {
  const StylistWelcome({
    super.key,
    required this.prompts,
    required this.onPromptSelected,
  });

  final List<String> prompts;
  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return ListView(
      padding: const EdgeInsets.all(DsSpacing.lg),
      children: [
        const SizedBox(height: DsSpacing.xl),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: context.ds.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: colors.onPrimary,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: DsSpacing.md),
        Text(
          context.l10n.stylistWelcomeTitle,
          textAlign: TextAlign.center,
          style: context.dsText.screenTitle.bold.tint(colors.onSurface),
        ),
        const SizedBox(height: DsSpacing.xs),
        Text(
          context.l10n.stylistWelcomeBody,
          textAlign: TextAlign.center,
          style: context.dsText.body.tint(colors.onSurfaceVariant).copyWith(height: 1.7),
        ),
        const SizedBox(height: DsSpacing.xl),
        if (prompts.isNotEmpty) ...[
          Text(
            context.l10n.stylistTryAsking,
            style: context.dsText.labelMedium.semibold.tint(
              colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
          for (final prompt in prompts) ...[
            _PromptCard(prompt: prompt, onTap: () => onPromptSelected(prompt)),
            const SizedBox(height: DsSpacing.xs),
          ],
        ],
        const SizedBox(height: DsSpacing.lg),
        const _Capabilities(),
      ],
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.prompt, required this.onTap});

  final String prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Material(
      color: colors.surfaceElevated,
      borderRadius: BorderRadius.circular(DsRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(DsRadius.lg),
        // Sends straight away rather than filling the composer: she picked a
        // complete sentence, and making her press send again adds nothing.
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(DsSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DsRadius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 16,
                color: colors.primary,
              ),
              const SizedBox(width: DsSpacing.xs),
              Expanded(
                child: Text(
                  prompt,
                  style: context.dsText.body.tint(colors.onSurface).copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Capabilities extends StatelessWidget {
  const _Capabilities();

  static List<(IconData, String, String)> _items(AppLocalizations l10n) => [
    (
      Icons.checkroom_rounded,
      l10n.stylistCapLookTitle,
      l10n.stylistCapLookBody,
    ),
    (
      Icons.card_giftcard_rounded,
      l10n.stylistCapGiftsTitle,
      l10n.stylistCapGiftsBody,
    ),
    (
      Icons.verified_outlined,
      l10n.stylistCapInStockTitle,
      l10n.stylistCapInStockBody,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Column(
      children: [
        for (final (icon, title, subtitle) in _items(context.l10n))
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(DsSpacing.xs),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(DsRadius.md),
                  ),
                  child: Icon(icon, size: 16, color: colors.primary),
                ),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.dsText.labelLarge.tint(colors.onSurface),
                      ),
                      Text(
                        subtitle,
                        style: context.dsText.caption.tint(colors.onSurfaceVariant).copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
