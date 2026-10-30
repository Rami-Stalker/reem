import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/media_asset.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/reputation/domain/entities/fit_entities.dart';
import 'package:ohara/features/reputation/domain/entities/reputation_entities.dart';
import 'package:ohara/features/reputation/domain/repositories/reputation_repository.dart';
import 'package:ohara/features/reputation/presentation/providers/reputation_provider.dart';
import 'package:ohara/features/reputation/presentation/widgets/fit_labels.dart';

/// What she wrote, handed to whoever asked for the review.
class ReviewDraft {
  const ReviewDraft({
    required this.rating,
    required this.title,
    required this.body,
    this.fit,
  });

  final int rating;
  final String title;
  final String body;

  /// The «تقييمات من بمقاسي» half. Null on a shop review, which has no fit.
  final ReviewFitInput? fit;
}

/// The sheet she writes a review in — stars, a headline, a few words.
///
/// Lifted out of the product page because the seller profile needed the same
/// sheet. `ReputationActions` has had `submitSellerReview` since the module
/// landed and nothing ever called it: a shopper could review a dress and had
/// no way to say anything about the boutique that sent it. Rather than a
/// second composer that drifts from this one, the caller passes what to do
/// with the answer.
///
/// [askFit] adds the product-only half: how it fit, her photographs of it on,
/// and whether to show her height and size beside it. A boutique has no fit,
/// so a shop review leaves it off.
Future<void> showReviewComposer({
  required BuildContext context,
  required Future<Result<ReviewEntity>> Function(ReviewDraft draft) onSubmit,
  VoidCallback? onSubmitted,
  bool askFit = false,
}) {
  // On the root navigator, like every sheet in the app: raised from the
  // product page's own navigator it sat behind the floating bottom bar.
  return DsBottomSheet.show<void>(
    context,
    builder: (_) => _ReviewComposerSheet(
      onSubmit: onSubmit,
      askFit: askFit,
      onSubmitted: () {
        onSubmitted?.call();
        DsSnackbar.show(
          context,
          message: context.l10n.reviewsSubmitted,
          type: DsSnackbarType.success,
        );
      },
    ),
  );
}

class _ReviewComposerSheet extends ConsumerStatefulWidget {
  const _ReviewComposerSheet({
    required this.onSubmit,
    required this.onSubmitted,
    required this.askFit,
  });

  final Future<Result<ReviewEntity>> Function(ReviewDraft draft) onSubmit;
  final VoidCallback onSubmitted;
  final bool askFit;

  @override
  ConsumerState<_ReviewComposerSheet> createState() =>
      _ReviewComposerSheetState();
}

class _ReviewComposerSheetState extends ConsumerState<_ReviewComposerSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  /// Nothing until she chooses. It used to open on five stars, so a review
  /// sent without touching them went out as 5★ — a rating nobody gave, and
  /// the reason the stars under reviewers' names looked made up.
  var _rating = 0;
  var _submitting = false;

  ReviewFit? _fit;
  List<String> _photos = const [];
  var _uploading = false;

  /// Null until she touches the switch: her profile's standing choice decides.
  bool? _shareFit;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.sm,
        DsSpacing.lg,
        bottom + DsSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.reviewsWriteAction,
            style: context.dsText.sectionTitle.copyWith(
              fontWeight: DsTypography.bold,
            ),
          ),
          DsGaps.vMd,
          Row(
            children: List.generate(5, (index) {
              final selected = index < _rating;
              return IconButton(
                tooltip: l10n.reviewsStarsCount(index + 1),
                onPressed: _submitting
                    ? null
                    : () => setState(() => _rating = index + 1),
                icon: Icon(
                  selected ? Icons.star_rounded : Icons.star_border_rounded,
                  color: context.dsColors.warning,
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: DsSpacing.xs),
            child: Text(
              _rating == 0
                  ? l10n.reviewsRatePrompt
                  : l10n.reviewsRatingMeaning('$_rating'),
              style: _rating == 0
                  ? context.dsText.caption
                  : context.dsText.captionStrong.tint(
                      context.dsColors.warningInk,
                    ),
            ),
          ),
          DsGaps.vSm,
          DsInputField(
            controller: _title,
            enabled: !_submitting,
            label: l10n.reviewsFieldTitle,
            prefixIcon: const Icon(Icons.short_text_rounded),
          ),
          DsGaps.vSm,
          DsInputField(
            controller: _body,
            minLines: 3,
            maxLines: 5,
            enabled: !_submitting,
            label: l10n.reviewsFieldBody,
            prefixIcon: const Icon(Icons.rate_review_outlined),
          ),
          if (widget.askFit) ..._fitSection(context),
          DsGaps.vLg,
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              // A review is its rating first; the words are optional.
              onPressed: _submitting || _uploading || _rating == 0
                  ? null
                  : _submit,
              icon: const Icon(Icons.send_rounded),
              label: Text(l10n.reviewsSubmit),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _fitSection(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final profile = ref.watch(fitProfileProvider).asData?.value;

    return [
      DsGaps.vMd,
      Text(l10n.fitQuestion, style: context.dsText.labelStrong),
      DsGaps.vXs,
      Wrap(
        spacing: DsSpacing.xs,
        runSpacing: DsSpacing.xs,
        children: [
          for (final fit in ReviewFit.values)
            DsChip(
              label: FitLabels.fit(l10n, fit),
              icon: FitLabels.icon(fit),
              selected: _fit == fit,
              // Tapping the chosen one clears it: "I don't know" is a fine
              // answer, and a wrong one misleads every woman after her.
              onTap: _submitting
                  ? null
                  : () => setState(() => _fit = _fit == fit ? null : fit),
            ),
        ],
      ),
      DsGaps.vMd,
      DsMediaField(
        purpose: MediaPurpose.review,
        maxItems: 4,
        enabled: !_submitting,
        label: l10n.fitPhotosLabel,
        helperText: l10n.fitPhotosHelper,
        onChanged: (urls) => setState(() => _photos = urls),
        onUploadingChanged: (value) => setState(() => _uploading = value),
      ),
      DsGaps.vMd,
      // «مقاساتي», right here. It used to be a link to the profile screen,
      // pushed from inside this sheet — so the screen opened behind the sheet
      // she was looking at, and the link seemed to do nothing.
      _MySizes(enabled: !_submitting),
      if (profile != null && profile.isSet)
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _shareFit ?? profile.shareOnReviews,
          onChanged: _submitting
              ? null
              : (value) => setState(() => _shareFit = value),
          title: Text(l10n.fitShareOnReview, style: context.dsText.body),
          subtitle: Text(
            l10n.fitShareOnReviewHint,
            style: context.dsText.caption.tint(colors.onSurfaceVariant),
          ),
        ),
    ];
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final result = await widget.onSubmit(
      ReviewDraft(
        rating: _rating,
        title: _title.text,
        body: _body.text,
        fit: widget.askFit
            ? ReviewFitInput(fit: _fit, photoUrls: _photos, shareFit: _shareFit)
            : null,
      ),
    );
    if (!mounted) return;
    switch (result) {
      case Success():
        Navigator.of(context).pop();
        widget.onSubmitted();
      case Error(:final failure):
        setState(() => _submitting = false);
        DsSnackbar.show(
          context,
          message: failure.message,
          type: DsSnackbarType.error,
        );
    }
  }
}

/// Her height and usual size, read and edited inside the review sheet.
///
/// Saved to her profile, not only to this review: the same answer powers
/// «اللي بمقاسي» on every product page. Collapsed to one line once it is set,
/// with «عدّلي» to open it again.
class _MySizes extends ConsumerStatefulWidget {
  const _MySizes({required this.enabled});

  final bool enabled;

  @override
  ConsumerState<_MySizes> createState() => _MySizesState();
}

class _MySizesState extends ConsumerState<_MySizes> {
  static const _minHeight = 130;
  static const _maxHeight = 200;

  final _height = TextEditingController();
  String? _size;
  bool _editing = false;
  bool _saving = false;
  bool _seeded = false;
  String? _error;

  @override
  void dispose() {
    _height.dispose();
    super.dispose();
  }

  void _seed(FitProfile profile) {
    if (_seeded) return;
    _seeded = true;
    _height.text = profile.heightCm?.toString() ?? '';
    _size = profile.usualSize;
    _editing = !profile.isSet;
  }

  Future<void> _save(FitProfile profile) async {
    final l10n = context.l10n;
    final typed = _height.text.trim();
    final height = typed.isEmpty ? null : int.tryParse(typed);
    if (typed.isNotEmpty &&
        (height == null || height < _minHeight || height > _maxHeight)) {
      setState(() => _error = l10n.fitHeightInvalid(_minHeight, _maxHeight));
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final result = await ref
        .read(reputationActionsProvider)
        .saveFitProfile(
          heightCm: height,
          usualSize: _size,
          shareOnReviews: profile.shareOnReviews,
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result case Success(:final data)) {
        _editing = !data.isSet;
      } else if (result case Error(:final failure)) {
        _error = failure.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final async = ref.watch(fitProfileProvider);
    final profile = async.asData?.value;
    if (profile == null) return const SizedBox.shrink();
    _seed(profile);

    final summary = profile.isSet && !_editing
        ? l10n.fitMineSummary(
            profile.heightCm == null
                ? '—'
                : '${profile.heightCm} ${l10n.fitCentimetres}',
            profile.usualSize ?? '—',
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.straighten_rounded,
                size: DsSizes.iconSm,
                color: colors.primary,
              ),
              DsGaps.hXs,
              Expanded(
                child: Text(l10n.fitMineTitle, style: context.dsText.labelStrong),
              ),
              if (summary != null)
                TextButton(
                  onPressed: widget.enabled
                      ? () => setState(() => _editing = true)
                      : null,
                  child: Text(l10n.fitMineEdit),
                ),
            ],
          ),
          if (summary != null)
            Text(summary, style: context.dsText.body.semibold)
          else ...[
            DsGaps.vXxs,
            Text(
              l10n.fitMineHelp,
              style: context.dsText.caption.tint(colors.onSurfaceVariant),
            ),
            DsGaps.vSm,
            DsInputField(
              controller: _height,
              enabled: widget.enabled && !_saving,
              label: l10n.fitHeightLabel,
              hint: l10n.fitHeightHint,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              suffixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(end: DsSpacing.md),
                child: Center(
                  widthFactor: 1,
                  child: Text(l10n.fitCentimetres, style: context.dsText.caption),
                ),
              ),
              errorText: _error,
            ),
            DsGaps.vSm,
            Text(l10n.fitUsualSizeLabel, style: context.dsText.caption),
            DsGaps.vXs,
            Wrap(
              spacing: DsSpacing.xs,
              runSpacing: DsSpacing.xs,
              children: [
                for (final size in profile.sizes)
                  DsChip(
                    label: size,
                    selected: _size == size,
                    onTap: !widget.enabled || _saving
                        ? null
                        : () => setState(
                            () => _size = _size == size ? null : size,
                          ),
                  ),
              ],
            ),
            DsGaps.vSm,
            DsButton(
              label: l10n.fitProfileSave,
              icon: Icons.check_rounded,
              variant: DsButtonVariant.tonal,
              size: DsButtonSize.sm,
              isLoading: _saving,
              onPressed: widget.enabled && !_saving
                  ? () => _save(profile)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
