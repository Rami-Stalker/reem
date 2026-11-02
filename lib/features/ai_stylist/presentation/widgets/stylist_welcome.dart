import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/ai_stylist/presentation/widgets/stylist_aura.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// The empty state, which is really the onboarding.
///
/// Nobody opens a chat box knowing what an AI stylist can do, so the screen
/// answers that before she asks: a greeting from Ohara herself, worked
/// examples in her own words, each tappable, and what the assistant is good
/// at. The prompts are the same sentences the feature was specified against,
/// which means the demo is also the regression test.
class StylistWelcome extends StatelessWidget {
  const StylistWelcome({
    super.key,
    required this.prompts,
    required this.onPromptSelected,
  });

  final List<String> prompts;
  final ValueChanged<String> onPromptSelected;

  static const _promptIcons = [
    Icons.celebration_outlined,
    Icons.card_giftcard_rounded,
    Icons.checkroom_rounded,
    Icons.history_rounded,
    Icons.wb_sunny_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.lg,
        DsSpacing.lg,
        DsSpacing.xxl,
      ),
      children: [
        const StylistAppear(child: _Hero()),
        DsGaps.vXl,
        if (prompts.isNotEmpty) ...[
          StylistAppear(
            index: 1,
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: colors.primary),
                DsGaps.hXxs,
                Text(
                  context.l10n.stylistTryAsking,
                  style: context.dsText.labelLarge.semibold.tint(colors.onSurface),
                ),
              ],
            ),
          ),
          DsGaps.vSm,
          for (var i = 0; i < prompts.length; i++) ...[
            StylistAppear(
              index: i + 2,
              child: _PromptCard(
                prompt: prompts[i],
                icon: _promptIcons[i % _promptIcons.length],
                onTap: () => onPromptSelected(prompts[i]),
              ),
            ),
            DsGaps.vXs,
          ],
        ],
        DsGaps.vLg,
        StylistAppear(index: prompts.length + 2, child: const _Capabilities()),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Column(
      children: [
        DsGaps.vMd,
        const OharaOrb(size: 92),
        DsGaps.vLg,
        StylistGradientText(
          context.l10n.stylistWelcomeGreeting,
          textAlign: TextAlign.center,
          style: context.dsText.pageTitle.bold,
        ),
        DsGaps.vXs,
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.sm,
            vertical: DsSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceElevated.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(DsRadius.pill),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: colors.success, shape: BoxShape.circle),
              ),
              DsGaps.hXs,
              Text(
                context.l10n.stylistOnlineStatus,
                style: context.dsText.caption.medium.tint(colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        DsGaps.vSm,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
          child: Text(
            context.l10n.stylistWelcomeBody,
            textAlign: TextAlign.center,
            style: context.dsText.body.tint(colors.onSurfaceVariant).copyWith(height: 1.75),
          ),
        ),
      ],
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.prompt, required this.icon, required this.onTap});

  final String prompt;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return DsScaleAnimations.tapScale(
      onTap: onTap,
      pressedScale: 0.98,
      child: StylistPanel(
        radius: DsRadius.xl,
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.sm,
          vertical: DsSpacing.sm,
        ),
        // Sends straight away rather than filling the composer: she picked a
        // complete sentence, and making her press send again adds nothing.
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(DsRadius.md),
              ),
              child: Icon(icon, size: 18, color: colors.primary),
            ),
            DsGaps.hSm,
            Expanded(
              child: Text(
                prompt,
                style: context.dsText.body.tint(colors.onSurface).copyWith(height: 1.5),
              ),
            ),
            DsGaps.hXs,
            Icon(
              Icons.north_west_rounded,
              size: 16,
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _Capabilities extends StatelessWidget {
  const _Capabilities();

  static List<(IconData, String, String)> _items(AppLocalizations l10n) => [
    (Icons.checkroom_rounded, l10n.stylistCapLookTitle, l10n.stylistCapLookBody),
    (Icons.palette_outlined, l10n.stylistCapAdviceTitle, l10n.stylistCapAdviceBody),
    (Icons.card_giftcard_rounded, l10n.stylistCapGiftsTitle, l10n.stylistCapGiftsBody),
    (Icons.verified_outlined, l10n.stylistCapInStockTitle, l10n.stylistCapInStockBody),
  ];

  @override
  Widget build(BuildContext context) {
    final items = _items(context.l10n);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - DsSpacing.xs) / 2;
        return Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xs,
          children: [
            for (final (icon, title, body) in items)
              SizedBox(
                width: tileWidth,
                child: _CapabilityTile(icon: icon, title: title, body: body),
              ),
          ],
        );
      },
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return StylistPanel(
      radius: DsRadius.xl,
      padding: const EdgeInsets.all(DsSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: context.boutique.signatureGradient,
              borderRadius: BorderRadius.circular(DsRadius.md),
            ),
            child: Icon(icon, size: 17, color: DsColors.onMedia),
          ),
          DsGaps.vXs,
          Text(title, style: context.dsText.labelLarge.semibold.tint(colors.onSurface)),
          DsGaps.vXxxs,
          Text(
            body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.caption.tint(colors.onSurfaceVariant).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
