import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/ai_stylist/domain/entities/style_brief.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_conversation.dart';
import 'package:reem/features/ai_stylist/domain/repositories/ai_stylist_repository.dart';
import 'package:reem/features/ai_stylist/presentation/providers/ai_stylist_providers.dart';

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
      appBar: ReemAppBar(title: context.l10n.stylistPreferencesTitle),
      body: bootstrapAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: 'ما قدرنا نجيب تفضيلاتك.',
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
          title: 'درجة الاحتشام',
          subtitle: 'بتحدّد شو المنصّة بتعرض عليكِ من قطع.',
          child: _ModestyPicker(
            selected: preferences.modesty,
            onSelected: (value) => actions.updatePreferences(
              PreferencesPatch(modesty: value),
            ),
          ),
        ),
        _Section(
          title: 'الألوان المفضّلة',
          subtitle: 'منرفع ترتيب القطع بهالألوان، وما منخفي غيرها.',
          child: _ColourPicker(
            available: bootstrap.colours,
            selected: preferences.favouriteColours.map((c) => c.key).toSet(),
            onChanged: (keys) => actions.updatePreferences(
              PreferencesPatch(favouriteColours: keys.toList()),
            ),
          ),
        ),
        _Section(
          title: 'مقاساتي',
          subtitle: 'لما نعرفهم، منعرض بس القطع المتوفرة فعليًا بمقاسك.',
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
            title: 'الميزانية',
            subtitle: 'الرقم اللي بترتاحي فيه عادةً.',
            child: _BudgetSummary(preferences: preferences),
          ),
        _Section(
          title: 'شو استنتجناه من تسوّقك',
          subtitle: 'هاد اللي بتقوله تصرّفاتك، مو اللي كتبتيه.',
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

  static const _options = [
    ('UNSPECIFIED', 'ما بحدّد'),
    ('FULL_COVERAGE', 'تغطية كاملة'),
    ('MODEST', 'محتشم'),
    ('BALANCED', 'متوازن'),
    ('EXPRESSIVE', 'بلا قيود'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DsSpacing.xs,
      runSpacing: DsSpacing.xs,
      children: [
        for (final (key, label) in _options)
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
          'الملابس',
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
          'الأحذية',
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
            'حدّدتِ حتى ${stated.format()}',
            style: context.dsText.body.tint(colors.onSurface),
          ),
        if (typical != null && preferences.typicalMin != null)
          Text(
            'وعادةً بتشتري بين ${preferences.typicalMin!.format()} و${typical.format()}',
            style: context.dsText.labelMedium.tint(colors.onSurfaceVariant).copyWith(height: 1.6),
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
              'لسا ما عنا إشارات كافية. تصفّحي وشوفي منتجات، ورح نتعلّم ذوقك.',
              style: context.dsText.body.tint(colors.onSurfaceVariant).copyWith(height: 1.6),
            )
          else ...[
            _Stat(label: 'منتجات شفتيها', value: taste.viewedCount),
            _Stat(label: 'منتجات حفظتيها', value: taste.savedCount),
            _Stat(label: 'منتجات اشتريتيها', value: taste.purchasedCount),
            _Stat(label: 'منتجات ما عجبتك', value: taste.dismissedCount),
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
                      ? 'حدّثنا قراءتنا لذوقك.'
                      : 'ما قدرنا نحدّث، جرّبي بعد شوي.',
                  type: ok ? DsSnackbarType.success : DsSnackbarType.error,
                );
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('حدّثي'),
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
