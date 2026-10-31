import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/media_asset.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/repositories/closet_repository.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_compartments.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_visuals.dart';

/// Add a garment Ohara never sold her.
///
/// The screen that makes the whole feature something other than an order
/// history. Its job is to be short: a photograph, a name, and the one question
/// that cannot be guessed. Everything else — colour, fabric, season, occasion —
/// is derived on the server from what she typed and can be corrected later, so
/// nothing else is asked for here. The two optional extras sit in their own
/// card, marked optional, so the form reads as three steps rather than five.
class AddPersonalItemScreen extends ConsumerStatefulWidget {
  const AddPersonalItemScreen({super.key, this.initialSlot});

  /// The slot chosen before she arrived — set when she pressed the "+" on a
  /// wardrobe compartment, so the one required question is already answered.
  final String? initialSlot;

  @override
  ConsumerState<AddPersonalItemScreen> createState() =>
      _AddPersonalItemScreenState();
}

class _AddPersonalItemScreenState extends ConsumerState<AddPersonalItemScreen> {
  final _title = TextEditingController();
  final _brand = TextEditingController();

  late String? _slot = widget.initialSlot;
  String? _imageUrl;
  String? _size;
  bool _uploading = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _brand.dispose();
    super.dispose();
  }

  bool get _hasTitle => _title.text.trim().isNotEmpty;

  bool get _canSave => !_saving && !_uploading && _slot != null && _hasTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    final overviewAsync = ref.watch(closetOverviewProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: OharaAppBar(title: l10n.closetAddPiece),
      bottomNavigationBar: overviewAsync.hasValue
          ? _SaveBar(
              canSave: _canSave,
              saving: _saving,
              hint: _uploading
                  ? l10n.closetAddUploading
                  : _canSave
                  ? null
                  : l10n.closetAddNeeds,
              onSave: _save,
            )
          : null,
      body: overviewAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: l10n.closetPageLoadFailed,
          onRetry: () => ref.invalidate(closetOverviewProvider),
        ),
        data: (overview) => ListView(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.md,
            DsSpacing.lg,
            DsSpacing.xl,
          ),
          children: [
            _Section(
              step: 1,
              title: l10n.closetPiecePhoto,
              done: _imageUrl != null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Private, and said so plainly. She is about to photograph
                  // her bedroom; the app owes her the sentence before she does,
                  // not in a settings page afterwards.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: DsSizes.iconXs,
                        color: colors.success,
                      ),
                      DsGaps.hXs,
                      Expanded(
                        child: Text(
                          l10n.closetPhotoPrivate,
                          style: context.dsText.caption,
                        ),
                      ),
                    ],
                  ),
                  DsGaps.vSm,
                  DsMediaField(
                    purpose: MediaPurpose.closet,
                    maxItems: 1,
                    label: l10n.closetPiecePhoto,
                    onChanged: (urls) => setState(
                      () => _imageUrl = urls.isEmpty ? null : urls.first,
                    ),
                    onUploadingChanged: (value) =>
                        setState(() => _uploading = value),
                  ),
                ],
              ),
            ),
            DsGaps.vMd,
            _Section(
              step: 2,
              title: l10n.closetPieceWhat,
              done: _hasTitle,
              child: DsInputField(
                controller: _title,
                hint: l10n.closetPieceWhatHint,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),
            ),
            DsGaps.vMd,
            // The one required answer. A photograph has no category to fall
            // back on, and a piece filed in the wrong slot quietly distorts
            // every gap and every outfit from then on.
            _Section(
              step: 3,
              title: l10n.closetPieceSlot,
              done: _slot != null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_slot case final slot?) ...[
                    ClosetPill(
                      icon: ClosetCompartment.forSlot(slot).icon,
                      tone: DsTone.accent,
                      label: l10n.closetAddingTo(
                        ClosetCompartment.forSlot(slot).name(context, overview.vocabulary),
                      ),
                    ),
                    DsGaps.vSm,
                  ],
                  _SlotPicker(
                    slots: overview.vocabulary.slots,
                    selected: _slot,
                    onSelected: (slot) => setState(() => _slot = slot),
                  ),
                ],
              ),
            ),
            DsGaps.vMd,
            _Section(
              title: l10n.closetAddExtras,
              optional: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DsInputField(
                    controller: _brand,
                    label: l10n.closetPieceBrandOptional,
                    prefixIcon: const Icon(Icons.sell_outlined),
                  ),
                  DsGaps.vMd,
                  Text(
                    l10n.closetPieceSizeOptional,
                    style: context.dsText.labelStrong,
                  ),
                  DsGaps.vXs,
                  _SizePicker(
                    selected: _size,
                    onSelected: (size) => setState(() => _size = size),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final result = await ref.read(closetActionsProvider).addPersonal(
      PersonalItemDraft(
        title: _title.text.trim(),
        slot: _slot!,
        imageUrl: _imageUrl,
        brandName: _brand.text.trim(),
        descriptor: DescriptorPatch(size: _size),
      ),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      success: (_) {
        DsSnackbar.show(
          context,
          message: context.l10n.closetAdded,
          type: DsSnackbarType.success,
        );
        // Opened from a link there is nothing to pop back to; the closet is
        // where the new piece is.
        context.canPop() ? context.pop() : context.go(RoutePaths.closet);
      },
      error: (_) => DsSnackbar.show(
        context,
        message: context.l10n.closetAddFailed,
        type: DsSnackbarType.error,
      ),
    );
  }
}

/// One numbered step of the form, ticked once it is answered.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.step,
    this.done = false,
    this.optional = false,
  });

  final String title;
  final Widget child;
  final int? step;
  final bool done;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final text = context.dsText;

    return CustomerPanel(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: DsMotion.fast,
                width: DsSizes.avatarXs,
                height: DsSizes.avatarXs,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: done ? palette.signatureGradient : null,
                  color: done ? null : palette.primarySoft,
                ),
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: DsSizes.iconXs,
                        color: DsColors.onMedia,
                      )
                    : step == null
                    ? Icon(
                        Icons.more_horiz_rounded,
                        size: DsSizes.iconXs,
                        color: palette.primary,
                      )
                    : Text(
                        '$step',
                        style: text.captionStrong.tint(palette.primary),
                      ),
              ),
              DsGaps.hSm,
              Expanded(child: Text(title, style: text.cardTitle)),
              if (optional)
                ClosetPill(label: context.l10n.closetOptional),
            ],
          ),
          DsGaps.vMd,
          child,
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.canSave,
    required this.saving,
    required this.hint,
    required this.onSave,
  });

  final bool canSave;
  final bool saving;
  final String? hint;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.sm,
            DsSpacing.lg,
            DsSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hint != null) ...[
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: context.dsText.caption,
                ),
                DsGaps.vXs,
              ],
              DsButton(
                label: context.l10n.closetAddToMyCloset,
                icon: Icons.checkroom_rounded,
                isLoading: saving,
                onPressed: canSave ? onSave : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotPicker extends StatelessWidget {
  const _SlotPicker({
    required this.slots,
    required this.selected,
    required this.onSelected,
  });

  final List<ClosetTerm> slots;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DsSpacing.xs,
      runSpacing: DsSpacing.xs,
      children: [
        for (final slot in slots)
          // `GIFT` is a purchase intent, not a body position — nothing in a
          // wardrobe is filed under it.
          if (slot.key != 'GIFT')
            DsChip(
              label: slot.label,
              icon: ClosetSlotStyle.icon(slot.key),
              selected: selected == slot.key,
              onTap: () => onSelected(slot.key),
            ),
      ],
    );
  }
}

class _SizePicker extends StatelessWidget {
  const _SizePicker({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  // l10n-ignore: garment sizes are the labels printed on the tag.
  static const _sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '36', '37', '38', '39', '40', '41'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DsSpacing.xs,
      runSpacing: DsSpacing.xs,
      children: [
        for (final size in _sizes)
          DsChip(
            label: size,
            selected: selected == size,
            // Tapping the selected chip clears it — a size guessed wrong is
            // worse than no size, because it filters every future suggestion.
            onTap: () => onSelected(selected == size ? null : size),
          ),
      ],
    );
  }
}
