import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/ai_stylist/domain/entities/style_brief.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_conversation.dart';
import 'package:ohara/features/ai_stylist/domain/repositories/ai_stylist_repository.dart';
import 'package:ohara/features/ai_stylist/presentation/providers/ai_stylist_providers.dart';
import 'package:ohara/features/ai_stylist/presentation/widgets/stylist_aura.dart';

/// Her taste, editable.
///
/// The screen deliberately shows both halves of the profile side by side: what
/// she declared, and what her behaviour says. The second half is the one most
/// apps hide, and hiding it is what makes personalization feel like something
/// being done *to* her rather than for her.
class StylePreferencesScreen extends ConsumerWidget {
  const StylePreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final bootstrapAsync = ref.watch(stylistBootstrapProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: OharaAppBar(title: context.l10n.stylistPreferencesTitle),
      body: StylistBackdrop(
        child: bootstrapAsync.when(
          loading: () => const Center(child: OharaOrb(size: 64, thinking: true)),
          error: (_, _) => DsErrorState(
            message: context.l10n.stylistPreferencesFailed,
            onRetry: () => ref.invalidate(stylistBootstrapProvider),
          ),
          data: (bootstrap) => _PreferencesBody(bootstrap: bootstrap),
        ),
      ),
    );
  }
}

class _PreferencesBody extends ConsumerWidget {
  const _PreferencesBody({required this.bootstrap});

  final StylistBootstrap bootstrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = bootstrap.preferences;
    final actions = ref.read(stylistActionsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.md,
        DsSpacing.md,
        DsSpacing.md,
        DsSpacing.xxl,
      ),
      children: [
        const StylistAppear(child: _TasteHero()),
        DsGaps.vLg,
        _Section(
          icon: Icons.palette_outlined,
          title: context.l10n.stylistFavouriteColours,
          subtitle: context.l10n.stylistFavouriteColoursHelp,
          child: _ColourPicker(
            available: bootstrap.colours,
            selected: preferences.favouriteColours.map((c) => c.key).toSet(),
            onChanged: (keys) => actions.updatePreferences(
              PreferencesPatch(favouriteColours: keys.toList()),
            ),
          ),
        ),
        _Section(
          icon: Icons.straighten_rounded,
          title: context.l10n.stylistMySizes,
          subtitle: context.l10n.stylistMySizesHelp,
          child: _SizeRow(
            clothingSize: preferences.clothingSize,
            shoeSize: preferences.shoeSize,
            onClothing: (size) => actions.updatePreferences(
              PreferencesPatch(clothingSize: size),
            ),
            onShoes: (size) => actions.updatePreferences(
              PreferencesPatch(shoeSize: size),
            ),
          ),
        ),
        if (preferences.typicalMin != null || preferences.budgetMax != null)
          _Section(
            icon: Icons.account_balance_wallet_outlined,
            title: context.l10n.stylistBudget,
            subtitle: context.l10n.stylistBudgetHelp,
            child: _BudgetSummary(preferences: preferences),
          ),
        _Section(
          icon: Icons.insights_rounded,
          title: context.l10n.stylistInferred,
          subtitle: context.l10n.stylistInferredHelp,
          child: _DerivedPanel(
            derived: preferences.derived,
            onRefresh: actions.refreshPreferences,
          ),
        ),
      ],
    );
  }
}

class _TasteHero extends StatelessWidget {
  const _TasteHero();

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return StylistPanel(
      highlighted: true,
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Row(
        children: [
          const OharaOrb(size: 56),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StylistGradientText(
                  context.l10n.stylistTasteHeroTitle,
                  style: context.dsText.sectionTitle.bold,
                ),
                DsGaps.vXxs,
                Text(
                  context.l10n.stylistTasteHeroBody,
                  style: context.dsText.caption
                      .tint(colors.onSurfaceVariant)
                      .copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: StylistAppear(
        index: 1,
        child: StylistPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(DsRadius.md),
                    ),
                    child: Icon(icon, size: 17, color: colors.primary),
                  ),
                  DsGaps.hSm,
                  Expanded(
                    child: Text(
                      title,
                      style: context.dsText.tileTitle.bold.tint(colors.onSurface),
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                DsGaps.vXs,
                Text(
                  subtitle!,
                  style: context.dsText.caption
                      .tint(colors.onSurfaceVariant)
                      .copyWith(height: 1.5),
                ),
              ],
              DsGaps.vMd,
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ColourPicker extends StatefulWidget {
  const _ColourPicker({
    required this.available,
    required this.selected,
    required this.onChanged,
  });

  final List<StyleTerm> available;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_ColourPicker> createState() => _ColourPickerState();
}

class _ColourPickerState extends State<_ColourPicker> {
  late final Set<String> _selected = {...widget.selected};

  void _toggle(String key) {
    setState(() {
      if (!_selected.remove(key)) _selected.add(key);
    });
    widget.onChanged(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DsSpacing.xs,
      runSpacing: DsSpacing.xs,
      children: [
        for (final colour in widget.available)
          _ColourChip(
            colour: colour,
            selected: _selected.contains(colour.key),
            onTap: () => _toggle(colour.key),
          ),
      ],
    );
  }
}

class _ColourChip extends StatelessWidget {
  const _ColourChip({
    required this.colour,
    required this.selected,
    required this.onTap,
  });

  final StyleTerm colour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final swatch = DsFabricSwatches.forKey(colour.key);

    return DsScaleAnimations.tapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DsDurations.fast,
        padding: const EdgeInsetsDirectional.fromSTEB(
          DsSpacing.xxs,
          DsSpacing.xxs,
          DsSpacing.sm,
          DsSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer
              : colors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(DsRadius.pill),
          border: Border.all(
            color: selected ? colors.primary : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: swatch ?? colors.surfaceVariant,
                border: Border.all(color: colors.border),
              ),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: swatch != null && swatch.computeLuminance() > 0.5
                          ? DsColors.black
                          : DsColors.onMedia,
                    )
                  : null,
            ),
            DsGaps.hXs,
            Text(
              colour.label,
              style: context.dsText.labelMedium.medium.tint(
                selected ? colors.onPrimaryContainer : colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeRow extends StatelessWidget {
  const _SizeRow({
    required this.clothingSize,
    required this.shoeSize,
    required this.onClothing,
    required this.onShoes,
  });

  final String? clothingSize;
  final String? shoeSize;
  final ValueChanged<String> onClothing;
  final ValueChanged<String> onShoes;

  static const _clothing = ['S', 'M', 'L', 'XL'];
  static const _shoes = ['36', '37', '38', '39', '40', '41'];

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.stylistClothing,
          style: context.dsText.labelMedium.tint(colors.onSurfaceVariant),
        ),
        DsGaps.vXs,
        Wrap(
          spacing: DsSpacing.xs,
          children: [
            for (final size in _clothing)
              DsChip(
                label: size,
                selected: clothingSize == size,
                onTap: () => onClothing(size),
              ),
          ],
        ),
        DsGaps.vMd,
        Text(
          context.l10n.stylistShoes,
          style: context.dsText.labelMedium.tint(colors.onSurfaceVariant),
        ),
        DsGaps.vXs,
        Wrap(
          spacing: DsSpacing.xs,
          children: [
            for (final size in _shoes)
              DsChip(
                label: size,
                selected: shoeSize == size,
                onTap: () => onShoes(size),
              ),
          ],
        ),
      ],
    );
  }
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({required this.preferences});

  final StylePreferences preferences;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final stated = preferences.budgetMax;
    final typical = preferences.typicalMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stated != null)
          Text(
            context.l10n.stylistBudgetStated(stated.format()),
            style: context.dsText.body.tint(colors.onSurface),
          ),
        if (typical != null && preferences.typicalMin != null)
          Text(
            context.l10n.stylistBudgetTypical(
              preferences.typicalMin!.format(),
              typical.format(),
            ),
            style: context.dsText.labelMedium
                .tint(colors.onSurfaceVariant)
                .copyWith(height: 1.6),
          ),
      ],
    );
  }
}

class _DerivedPanel extends StatelessWidget {
  const _DerivedPanel({required this.derived, required this.onRefresh});

  final DerivedTaste? derived;
  final Future<bool> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final taste = derived;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (taste == null || !taste.hasSignal)
          Text(
            context.l10n.stylistNoSignalYet,
            style: context.dsText.body
                .tint(colors.onSurfaceVariant)
                .copyWith(height: 1.6),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - DsSpacing.xs) / 2;
              final stats = [
                (Icons.visibility_outlined, context.l10n.stylistViewed, taste.viewedCount),
                (Icons.favorite_border_rounded, context.l10n.stylistSaved, taste.savedCount),
                (Icons.shopping_bag_outlined, context.l10n.stylistPurchased, taste.purchasedCount),
                (Icons.do_not_disturb_on_outlined, context.l10n.stylistDismissed, taste.dismissedCount),
              ];
              return Wrap(
                spacing: DsSpacing.xs,
                runSpacing: DsSpacing.xs,
                children: [
                  for (final (icon, label, value) in stats)
                    SizedBox(
                      width: width,
                      child: _Stat(icon: icon, label: label, value: value),
                    ),
                ],
              );
            },
          ),
        DsGaps.vSm,
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () async {
              final ok = await onRefresh();
              if (!context.mounted) return;
              DsSnackbar.show(
                context,
                message: ok
                    ? context.l10n.stylistTasteRefreshed
                    : context.l10n.stylistTasteRefreshFailed,
                type: ok ? DsSnackbarType.success : DsSnackbarType.error,
              );
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(context.l10n.stylistRefresh),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.sm),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(DsRadius.lg),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.primary),
          DsGaps.hXs,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Counts up from zero the first time, so the numbers feel
                // like something measured rather than typed in.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value.toDouble()),
                  duration: DsReducedMotion.duration(DsDurations.slow),
                  curve: DsCurves.emphasized,
                  builder: (context, animated, _) => Text(
                    '${animated.round()}',
                    style: context.dsText.metricSmall.bold.tint(colors.onSurface),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.caption.tint(colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
