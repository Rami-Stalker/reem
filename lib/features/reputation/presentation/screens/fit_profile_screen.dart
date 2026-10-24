import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/reputation/domain/entities/fit_entities.dart';
import 'package:reem/features/reputation/presentation/providers/reputation_provider.dart';

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
    return Scaffold(
      backgroundColor: context.dsColors.background,
      appBar: ReemAppBar(title: context.l10n.fitProfileTitle),
      body: async.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.fitProfileLoadError,
          onRetry: () => ref.invalidate(fitProfileProvider),
        ),
        data: (profile) => _FitProfileForm(initial: profile),
      ),
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
  late final _height = TextEditingController(
    text: widget.initial.heightCm?.toString() ?? '',
  );
  late String? _size = widget.initial.usualSize;
  late bool _share = widget.initial.shareOnReviews;
  bool _saving = false;

  static const _minHeight = 130;
  static const _maxHeight = 200;

  @override
  void dispose() {
    _height.dispose();
    super.dispose();
  }

  int? get _heightValue => int.tryParse(_height.text.trim());

  /// Empty is fine — it clears the height. Anything typed must be a height.
  String? get _heightError {
    if (_height.text.trim().isEmpty) return null;
    final value = _heightValue;
    if (value == null || value < _minHeight || value > _maxHeight) {
      return context.l10n.fitHeightInvalid(_minHeight, _maxHeight);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    return ListView(
      padding: const EdgeInsets.all(DsSpacing.md),
      children: [
        SurfaceCard(
          color: colors.infoContainer,
          showBorder: false,
          padding: const EdgeInsets.all(DsSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: DsSizes.iconMd,
                color: colors.info,
              ),
              DsGaps.hSm,
              Expanded(
                child: Text(
                  l10n.fitProfilePrivacy,
                  style: context.dsText.caption.tint(colors.onSurface),
                ),
              ),
            ],
          ),
        ),
        DsGaps.vLg,
        DsInputField(
          controller: _height,
          label: l10n.fitHeightLabel,
          hint: l10n.fitHeightHint,
          errorText: _heightError,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          suffixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
            child: Center(
              widthFactor: 1,
              child: Text(l10n.fitCentimetres, style: context.dsText.caption),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        DsGaps.vLg,
        Text(l10n.fitUsualSizeLabel, style: context.dsText.labelStrong),
        DsGaps.vXs,
        Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xs,
          children: [
            for (final size in widget.initial.sizes)
              DsChip(
                label: size,
                selected: _size == size,
                // Tapping the chosen size clears it.
                onTap: () =>
                    setState(() => _size = _size == size ? null : size),
              ),
          ],
        ),
        DsGaps.vLg,
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _share,
          onChanged: (value) => setState(() => _share = value),
          title: Text(l10n.fitShareDefault, style: context.dsText.bodyStrong),
          subtitle: Text(
            l10n.fitShareDefaultHint,
            style: context.dsText.caption.tint(colors.onSurfaceVariant),
          ),
        ),
        DsGaps.vXl,
        DsButton(
          label: l10n.fitProfileSave,
          isLoading: _saving,
          onPressed: _saving || _heightError != null ? null : _save,
        ),
        DsGaps.bottomSafe,
      ],
    );
  }

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
