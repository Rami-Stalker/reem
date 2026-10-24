import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/ai_stylist/domain/entities/style_brief.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_conversation.dart';
import 'package:ohara/features/ai_stylist/domain/repositories/ai_stylist_repository.dart';
import 'package:ohara/features/ai_stylist/presentation/providers/ai_stylist_providers.dart';
import 'package:ohara/l10n/app_localizations.dart';

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
      body: bootstrapAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.stylistPreferencesFailed,
          onRetry: () => ref.invalidate(stylistBootstrapProvider),
        ),
        data: (bootstrap) => _PreferencesBody(bootstrap: bootstrap),
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
      padding: const EdgeInsets.all(DsSpacing.md),
      children: [
        _Section(
          title: context.l10n.stylistModesty,
          subtitle: context.l10n.stylistModestyHelp,
          child: _ModestyPicker(
            selected: preferences.modesty,
            onSelected: (value) => actions.updatePreferences(
              PreferencesPatch(modesty: value),
            ),
          ),
        ),
        _Section(
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
            title: context.l10n.stylistBudget,
            subtitle: context.l10n.stylistBudgetHelp,
            child: _BudgetSummary(preferences: preferences),
          ),
        _Section(
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

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.dsText.tileTitle.bold.tint(colors.onSurface),
          ),
          if (subtitle != null) ...[
            DsGaps.vXxxs,
            Text(
              subtitle!,
              style: context.dsText.caption.tint(colors.onSurfaceVariant).copyWith(height: 1.5),
            ),
          ],
          const SizedBox(height: DsSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _ModestyPicker extends StatelessWidget {
  const _ModestyPicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  static List<(String, String)> _options(AppLocalizations l10n) => [
    ('UNSPECIFIED', l10n.stylistModestyUnspecified),
    ('FULL_COVERAGE', l10n.stylistModestyFull),
    ('MODEST', l10n.stylistModestyModest),
    ('BALANCED', l10n.stylistModestyBalanced),
    ('EXPRESSIVE', l10n.stylistModestyExpressive),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DsSpacing.xs,
      runSpacing: DsSpacing.xs,
      children: [
        for (final (key, label) in _options(context.l10n))
          DsChip(
            label: label,
            selected: selected == key,
            onTap: () => onSelected(key),
          ),
      ],
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
          DsChip(
            label: colour.label,
            selected: _selected.contains(colour.key),
            onTap: () => _toggle(colour.key),
          ),
      ],
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
        const SizedBox(height: DsSpacing.xs),
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
        const SizedBox(height: DsSpacing.md),
        Text(
          context.l10n.stylistShoes,
          style: context.dsText.labelMedium.tint(colors.onSurfaceVariant),
        ),
        const SizedBox(height: DsSpacing.xs),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (taste == null || !taste.hasSignal)
            Text(
              context.l10n.stylistNoSignalYet,
              style: context.dsText.body
                  .tint(colors.onSurfaceVariant)
                  .copyWith(height: 1.6),
            )
          else ...[
            _Stat(label: context.l10n.stylistViewed, value: taste.viewedCount),
            _Stat(label: context.l10n.stylistSaved, value: taste.savedCount),
            _Stat(
              label: context.l10n.stylistPurchased,
              value: taste.purchasedCount,
            ),
            _Stat(
              label: context.l10n.stylistDismissed,
              value: taste.dismissedCount,
            ),
          ],
          const SizedBox(height: DsSpacing.sm),
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
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.dsText.body.tint(colors.onSurfaceVariant),
            ),
          ),
          Text(
            '$value',
            style: context.dsText.body.bold.tint(colors.onSurface),
          ),
        ],
      ),
    );
  }
}
