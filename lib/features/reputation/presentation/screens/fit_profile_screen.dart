import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/reputation/domain/entities/fit_entities.dart';
import 'package:ohara/features/reputation/presentation/providers/reputation_provider.dart';

/// «مقاساتي» — her height and usual size.
///
/// Two questions and a switch. No weight, no body shape, no measurements:
/// those are what make a size form feel like an examination, and these two
/// are enough to find reviews by women like her. The privacy sentence sits at
/// the top, before she types anything, because what she is about to give is
/// personal and she should know where it goes first.
class FitProfileScreen extends ConsumerWidget {
  const FitProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fitProfileProvider);
    return OharaScrollPage(
      slivers: [
        VanityAppBar(
          title: context.l10n.fitProfileTitle,
          icon: Icons.straighten_rounded,
          showBack: true,
        ),
        ...async.when(
          loading: () => const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: DsLoadingIndicator()),
            ),
          ],
          error: (_, _) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: DsErrorState(
                message: context.l10n.fitProfileLoadError,
                onRetry: () => ref.invalidate(fitProfileProvider),
              ),
            ),
          ],
          data: (profile) => [
            SliverToBoxAdapter(child: _FitProfileForm(initial: profile)),
          ],
        ),
      ],
    );
  }
}

class _FitProfileForm extends ConsumerStatefulWidget {
  const _FitProfileForm({required this.initial});

  final FitProfile initial;

  @override
  ConsumerState<_FitProfileForm> createState() => _FitProfileFormState();
}

class _FitProfileFormState extends ConsumerState<_FitProfileForm> {
  late int? _heightValue = widget.initial.heightCm;
  late String? _size = widget.initial.usualSize;
  late bool _share = widget.initial.shareOnReviews;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.boutique;
    final gutter = vanityGutter(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, DsSpacing.xl, gutter, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A sealed note, before she gives anything: where it goes.
          Container(
            padding: DsSpacing.paddingMd,
            decoration: BoxDecoration(
              color: palette.goldSoft.withValues(alpha: 0.55),
              borderRadius: DsRadius.borderXxl,
              border: Border.all(color: palette.gold.withValues(alpha: 0.45)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VanityPearl(
                  icon: Icons.lock_outline_rounded,
                  color: palette.gold,
                ),
                DsGaps.hMd,
                Expanded(
                  child: Text(
                    l10n.fitProfilePrivacy,
                    style: context.dsText.caption
                        .tint(palette.ink)
                        .copyWith(height: 1.55),
                  ),
                ),
              ],
            ),
          ),
          DsGaps.vXxl,
          VanityTray(
            title: l10n.fitHeightLabel,
            padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
            children: [
              VanityTape(
                value: _heightValue,
                min: _minHeight,
                max: _maxHeight,
                unit: l10n.fitCentimetres,
                hint: l10n.fitHeightHint,
                clearLabel: l10n.clear,
                onChanged: (value) => setState(() => _heightValue = value),
              ),
            ],
          ),
          DsGaps.vXl,
          VanityTray(
            title: l10n.fitUsualSizeLabel,
            padding: const EdgeInsets.all(DsSpacing.md),
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: DsSpacing.xs,
                runSpacing: DsSpacing.sm,
                children: [
                  for (final size in widget.initial.sizes)
                    _SizePearl(
                      label: size,
                      selected: _size == size,
                      // Tapping the chosen size clears it.
                      onTap: () =>
                          setState(() => _size = _size == size ? null : size),
                    ),
                ],
              ),
            ],
          ),
          DsGaps.vXl,
          VanityTray(
            children: [
              VanityRow(
                icon: Icons.rate_review_outlined,
                title: l10n.fitShareDefault,
                subtitle: l10n.fitShareDefaultHint,
                onTap: () => setState(() => _share = !_share),
                trailing: PearlSwitch(
                  value: _share,
                  onChanged: (value) => setState(() => _share = value),
                  semanticLabel: l10n.fitShareDefault,
                ),
              ),
            ],
          ),
          DsGaps.vXxl,
          DsButton(
            label: l10n.fitProfileSave,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  static const _minHeight = 130;
  static const _maxHeight = 200;

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await ref
        .read(reputationActionsProvider)
        .saveFitProfile(
          heightCm: _heightValue,
          usualSize: _size,
          shareOnReviews: _share,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success():
        DsSnackbar.success(context, context.l10n.fitProfileSaved);
        if (context.canPop()) context.pop();
      case Error(:final failure):
        DsSnackbar.error(context, failure.message);
    }
  }
}

/// One size, as a pearl on her string: the one she wears is gold and lit.
class _SizePearl extends StatelessWidget {
  const _SizePearl({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    const size = 48.0;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: DsScaleAnimations.tapScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: DsReducedMotion.duration(DsMotion.normal),
          curve: DsMotion.gentle,
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.45),
              colors: selected
                  ? const [DsColors.gold100, DsColors.gold300, DsColors.gold500]
                  : [
                      Color.lerp(palette.surface, DsColors.onMedia, 0.6)!,
                      Color.lerp(palette.surface, palette.primary, 0.1)!,
                      Color.lerp(palette.surface, palette.primary, 0.22)!,
                    ],
              stops: const [0, 0.6, 1],
            ),
            border: Border.all(
              color: selected
                  ? DsColors.gold500
                  : palette.primary.withValues(alpha: 0.2),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (selected ? palette.gold : palette.primary).withValues(
                  alpha: selected ? 0.45 : 0.12,
                ),
                blurRadius: selected ? 14 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: context.dsText.bodyStrong.displayFamily.bold.tint(
              selected ? DsColors.gold700 : palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}
